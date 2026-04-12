import { prisma } from '../../server';
import { CreateStudentInput, UpdateStudentInput } from './student.validator';
import { Prisma } from '@prisma/client';
import { ApiError } from '../../middleware/error.middleware';
import { buildPhoneVariants, normalizeIndianPhone } from '../../utils/phone';

export class StudentRepository {
  async listStudents(instituteId: string, filters: { name?: string, phone?: string, batchId?: string, isActive?: boolean }, pagination: { skip: number, take: number }) {
    const whereClause: Prisma.StudentWhereInput = { institute_id: instituteId };
    
    if (filters.name) whereClause.name = { contains: filters.name, mode: 'insensitive' };
    if (filters.phone) whereClause.phone = { contains: filters.phone };
    if (filters.isActive !== undefined) whereClause.is_active = filters.isActive;
    if (filters.batchId) {
      whereClause.student_batches = {
        some: {
          batch_id: filters.batchId,
          is_active: true
        }
      };
    }

    const [students, total] = await Promise.all([
      prisma.student.findMany({
        where: whereClause,
        include: {
          _count: { select: { student_batches: true } },
          parent_students: {
            where: { is_primary: true },
            take: 1,
            include: {
              parent: {
                select: {
                  id: true,
                  name: true,
                  phone: true,
                  user: {
                    select: {
                      id: true,
                      status: true,
                      is_active: true,
                    },
                  },
                },
              },
            },
          },
          student_batches: {
            where: { is_active: true },
            include: {
              batch: {
                select: {
                  id: true,
                  name: true,
                },
              },
            },
          },
        },
        skip: pagination.skip,
        take: pagination.take,
        orderBy: { created_at: 'desc' }
      }),
      prisma.student.count({ where: whereClause })
    ]);

    return { students, total };
  }

  async findStudentById(studentId: string, instituteId: string) {
    return prisma.student.findFirst({
      where: { id: studentId, institute_id: instituteId },
      include: {
        parent_students: {
           include: {
            parent: {
              include: {
                user: {
                  select: {
                    id: true,
                    status: true,
                    is_active: true,
                  },
                },
              },
            },
          }
        },
        student_batches: {
           where: { is_active: true },
           include: { batch: { select: { id: true, name: true, subject: true } } }
        }
      }
    } as any);
  }

  async findStudentByPhone(phone: string, instituteId: string) {
    return prisma.student.findFirst({
      where: { phone, institute_id: instituteId }
    });
  }

  async findStudentsByPhoneVariants(phones: string[], instituteId: string) {
    return prisma.student.findMany({
      where: {
        institute_id: instituteId,
        phone: { in: phones },
      },
      orderBy: { created_at: 'desc' },
    });
  }

  private resolveParentName(studentName: string, parentName?: string | null): string {
    const trimmedParentName = String(parentName || '').trim();
    if (trimmedParentName.length > 0) return trimmedParentName;

    const trimmedStudentName = String(studentName || '').trim();
    if (!trimmedStudentName) return 'Parent';

    return `${trimmedStudentName} Parent`;
  }

  async findOrCreateParentByPhone(
    tx: any,
    instituteId: string,
    parentPhone: string,
    options?: { parentName?: string; studentName?: string },
  ) {
    const normalizedPhone = normalizeIndianPhone(parentPhone);
    if (!normalizedPhone) {
      throw new ApiError('Invalid parent phone. Expected +91XXXXXXXXXX or 10-digit number.', 400, 'INVALID_PARENT_PHONE');
    }

    const phoneVariants = buildPhoneVariants(normalizedPhone);

    const [parentByPhone, parentUserByPhone, nonParentUserByPhone] = await Promise.all([
      tx.parent.findFirst({
        where: {
          institute_id: instituteId,
          phone: { in: phoneVariants },
        },
        include: { user: true },
      }),
      tx.user.findFirst({
        where: {
          institute_id: instituteId,
          role: 'parent',
          phone: { in: phoneVariants },
        },
      }),
      tx.user.findFirst({
        where: {
          institute_id: instituteId,
          role: { not: 'parent' },
          phone: { in: phoneVariants },
        },
        select: { id: true, role: true },
      }),
    ]);

    if (nonParentUserByPhone) {
      throw new ApiError(
        `Phone is already used by a ${nonParentUserByPhone.role} account. Please use a different parent phone.`,
        409,
        'PHONE_ROLE_CONFLICT',
      );
    }

    let parentUser = parentByPhone?.user || parentUserByPhone;

    if (!parentUser) {
      parentUser = await tx.user.create({
        data: {
          institute_id: instituteId,
          phone: normalizedPhone,
          role: 'parent',
          status: 'INACTIVE',
          is_active: true,
        },
      });
    } else {
      const userPatch: Record<string, unknown> = {};
      if (parentUser.phone !== normalizedPhone) userPatch.phone = normalizedPhone;
      if (Object.keys(userPatch).length > 0) {
        parentUser = await tx.user.update({
          where: { id: parentUser.id },
          data: userPatch,
        });
      }
    }

    const resolvedParentName = this.resolveParentName(options?.studentName || '', options?.parentName);

    if (parentByPhone) {
      const parentPatch: Record<string, unknown> = {};
      if (parentByPhone.phone !== normalizedPhone) parentPatch.phone = normalizedPhone;
      if (parentByPhone.user_id !== parentUser.id) parentPatch.user_id = parentUser.id;
      if (String(options?.parentName || '').trim().length > 0 && parentByPhone.name !== resolvedParentName) {
        parentPatch.name = resolvedParentName;
      }

      if (Object.keys(parentPatch).length === 0) return parentByPhone;

      return tx.parent.update({
        where: { id: parentByPhone.id },
        data: parentPatch,
      });
    }

    return tx.parent.create({
      data: {
        institute_id: instituteId,
        user_id: parentUser.id,
        name: resolvedParentName,
        phone: normalizedPhone,
      },
    });
  }

  async linkParentToStudent(
    tx: any,
    instituteId: string,
    parentId: string,
    studentId: string,
    relation?: string,
  ) {
    const normalizedRelation =
      typeof relation === 'string' && relation.trim().length > 0 ? relation.trim() : 'guardian';

    // Enforce a single active parent mapping per student for now.
    await tx.parentStudent.deleteMany({
      where: {
        student_id: studentId,
        parent: { institute_id: instituteId },
        NOT: { parent_id: parentId },
      },
    });

    return tx.parentStudent.upsert({
      where: {
        parent_id_student_id: {
          parent_id: parentId,
          student_id: studentId,
        },
      },
      update: {
        relation: normalizedRelation,
        is_primary: true,
      },
      create: {
        parent_id: parentId,
        student_id: studentId,
        relation: normalizedRelation,
        is_primary: true,
      },
    });
  }

  async getParentStudents(tx: any, instituteId: string, parentId: string) {
    const links = await tx.parentStudent.findMany({
      where: {
        parent_id: parentId,
        parent: { institute_id: instituteId },
      },
      include: {
        student: true,
      },
    });

    return links.map((entry: any) => entry.student);
  }

  async createStudentWithUserAndParent(instituteId: string, data: CreateStudentInput, _passwordHash?: string) {
     return prisma.$transaction(async (tx: any) => {
         // 1. Create Student record
         const student = await tx.student.create({
             data: {
                 institute_id: instituteId,
                 name: data.name,
                 phone: data.phone,
                 dob: data.dob ? new Date(data.dob) : null,
                 gender: data.gender,
                 address: data.address,
                 blood_group: data.blood_group,
                 prev_institute: data.prev_institute
             }
         });

         // 2. Link/Create Parent by normalized phone
         const hasParentPhone = typeof data.parent_phone === 'string' && data.parent_phone.trim().length > 0;
         if (hasParentPhone) {
           const parent = await this.findOrCreateParentByPhone(tx, instituteId, data.parent_phone!, {
             parentName: data.parent_name,
             studentName: data.name,
           });
           await this.linkParentToStudent(tx, instituteId, parent.id, student.id, data.parent_relation);
         }

         // 3. Assign student to batches if provided
         if (data.batch_ids && data.batch_ids.length > 0) {
            await tx.studentBatch.createMany({
                data: data.batch_ids.map(batchId => ({
                    student_id: student.id,
                    batch_id: batchId,
                    institute_id: instituteId
                }))
            });
         }

         return student;
     });
  }

  async updateStudent(studentId: string, instituteId: string, data: UpdateStudentInput) {
    const {
      parent_name,
      parent_phone,
      parent_relation,
      batch_ids,
      dob,
      ...rest
    } = data as any;

    const allowedStudentFields = [
      'name',
      'phone',
      'gender',
      'address',
      'blood_group',
      'prev_institute',
      'photo_url',
      'student_code',
      'is_active',
      'enrollment_date',
    ];

    const studentBaseData = Object.fromEntries(
      Object.entries(rest).filter(([key, value]) => allowedStudentFields.includes(key) && value !== undefined),
    );

    return prisma.$transaction(async (tx: any) => {
      const existingStudent = await tx.student.findFirst({
        where: { id: studentId, institute_id: instituteId },
        select: { id: true },
      });

      if (!existingStudent) {
        throw new Error('Student not found');
      }

      const student = await tx.student.update({
        where: { id: studentId },
        data: {
          ...studentBaseData,
          ...(studentBaseData.enrollment_date ? { enrollment_date: new Date(studentBaseData.enrollment_date as string) } : {}),
          ...(dob ? { dob: new Date(dob) } : {}),
        },
      });

      const hasParentName = typeof parent_name === 'string' && parent_name.trim().length > 0;
      const parentPhoneProvided = Object.prototype.hasOwnProperty.call(data as Record<string, unknown>, 'parent_phone');
      const hasParentPhone = typeof parent_phone === 'string' && parent_phone.trim().length > 0;

      if (parentPhoneProvided) {
        if (hasParentPhone) {
          const parent = await this.findOrCreateParentByPhone(tx, instituteId, parent_phone!, {
            parentName: hasParentName ? parent_name : undefined,
            studentName: student.name,
          });
          await this.linkParentToStudent(tx, instituteId, parent.id, studentId, parent_relation);
        } else {
          await tx.parentStudent.deleteMany({
            where: { student_id: studentId },
          });
        }
      } else if (hasParentName) {
        const existingLink = await tx.parentStudent.findFirst({
          where: { student_id: studentId },
          include: { parent: true },
        });

        if (existingLink?.parent_id) {
          await tx.parent.update({
            where: { id: existingLink.parent_id },
            data: {
              name: parent_name.trim(),
            },
          });

          if (typeof parent_relation === 'string' && parent_relation.trim().length > 0) {
            await tx.parentStudent.update({
              where: { parent_id_student_id: { parent_id: existingLink.parent_id, student_id: studentId } },
              data: { relation: parent_relation.trim() },
            });
          }
        }
      }

      if (Array.isArray(batch_ids)) {
        const normalizedBatchIds = Array.from(
          new Set(
            batch_ids
              .map((id: any) => id?.toString().trim())
              .filter((id: string | undefined) => typeof id === 'string' && id.length > 0),
          ),
        );

        await tx.studentBatch.updateMany({
          where: {
            student_id: studentId,
            institute_id: instituteId,
            ...(normalizedBatchIds.length > 0 ? { batch_id: { notIn: normalizedBatchIds } } : {}),
            is_active: true,
          },
          data: { is_active: false, left_date: new Date() },
        });

        for (const batchId of normalizedBatchIds) {
          await tx.studentBatch.upsert({
            where: { student_id_batch_id: { student_id: studentId, batch_id: batchId } },
            update: { is_active: true, left_date: null },
            create: {
              student_id: studentId,
              batch_id: batchId,
              institute_id: instituteId,
            },
          });
        }
      }

      return student;
    });
  }

  async toggleStatus(studentId: string, isActive: boolean) {
    return prisma.$transaction(async (tx: any) => {
      const student = await tx.student.update({
        where: { id: studentId },
        data: { is_active: isActive }
      });

      if (!isActive) {
        // Automatically remove the student from active batches if deactivated
        await tx.studentBatch.updateMany({
          where: { student_id: studentId, is_active: true },
          data: { is_active: false, left_date: new Date() }
        });
      }

      return student;
    });
  }
}

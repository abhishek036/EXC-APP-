import { prisma } from '../../server';
import { CreateStudentInput, UpdateStudentInput } from './student.validator';
import { Prisma } from '@prisma/client';

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
           include: { parent: true }
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

  async createStudentWithUserAndParent(instituteId: string, data: CreateStudentInput, passwordHash?: string) {
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

         // 2. Create Parent if required
         if (data.parent_name && data.parent_phone) {
             const parent = await tx.parent.create({
                 data: {
                     institute_id: instituteId,
                     name: data.parent_name,
                     phone: data.parent_phone,
                 }
             });

             await tx.parentStudent.create({
                 data: {
                     parent_id: parent.id,
                     student_id: student.id,
                     relation: data.parent_relation || 'guardian'
                 }
             });
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
      const hasParentPhone = typeof parent_phone === 'string' && parent_phone.trim().length > 0;

      if (hasParentName && hasParentPhone) {
        const existingLink = await tx.parentStudent.findFirst({
          where: { student_id: studentId },
          include: { parent: true },
        });

        if (existingLink?.parent_id) {
          await tx.parent.update({
            where: { id: existingLink.parent_id },
            data: {
              name: parent_name.trim(),
              phone: parent_phone.trim(),
            },
          });

          await tx.parentStudent.update({
            where: { parent_id_student_id: { parent_id: existingLink.parent_id, student_id: studentId } },
            data: {
              relation: (typeof parent_relation === 'string' && parent_relation.trim().length > 0)
                  ? parent_relation.trim()
                  : existingLink.relation,
            },
          });
        } else {
          const parent = await tx.parent.create({
            data: {
              institute_id: instituteId,
              name: parent_name.trim(),
              phone: parent_phone.trim(),
            },
          });

          await tx.parentStudent.create({
            data: {
              parent_id: parent.id,
              student_id: studentId,
              relation: (typeof parent_relation === 'string' && parent_relation.trim().length > 0)
                  ? parent_relation.trim()
                  : 'guardian',
            },
          });
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

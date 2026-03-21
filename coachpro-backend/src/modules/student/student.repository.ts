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
        include: { _count: { select: { student_batches: true } } },
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
    // Only update fields that exist on student model
    const { parent_name, parent_phone, parent_relation, dob, ...studentBaseData } = data as any;
    
    return prisma.student.update({
      where: { id: studentId },
      data: {
          ...studentBaseData,
          ...(dob && { dob: new Date(dob) })
      } as any
    });
  }

  async toggleStatus(studentId: string, isActive: boolean) {
    return prisma.student.update({
      where: { id: studentId },
      data: { is_active: isActive }
    });
  }
}

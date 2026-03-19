import { prisma } from '../../server';
import { CreateTeacherInput, UpdateTeacherInput } from './teacher.validator';
import { Prisma } from '@prisma/client';

export class TeacherRepository {
  async listTeachers(instituteId: string, filters: { name?: string, phone?: string }, pagination: { skip: number, take: number }) {
    const whereClause: Prisma.TeacherWhereInput = { institute_id: instituteId };
    
    if (filters.name) whereClause.name = { contains: filters.name, mode: 'insensitive' };
    if (filters.phone) whereClause.user = { phone: { contains: filters.phone } };

    const [teachers, total] = await Promise.all([
      prisma.teacher.findMany({
        where: whereClause,
        include: { _count: { select: { batches: true } } },
        skip: pagination.skip,
        take: pagination.take,
        orderBy: { created_at: 'desc' }
      }),
      prisma.teacher.count({ where: whereClause })
    ]);

    return { teachers, total };
  }

  async findTeacherById(teacherId: string, instituteId: string) {
    return prisma.teacher.findFirst({
      where: { id: teacherId, institute_id: instituteId },
      include: {
        batches: {
           where: { is_active: true },
           select: { id: true, name: true, subject: true, _count: { select: { student_batches: true } } }
        }
      }
    });
  }

  async createTeacherWithUser(instituteId: string, data: CreateTeacherInput, passwordHash?: string) {
     if (!data.phone) throw new Error('Phone is required for Teacher creation');

     return prisma.teacher.create({
         data: {
             institute_id: instituteId,
             phone: data.phone,
             name: data.name,
             email: data.email,
             qualification: data.qualification,
             subjects: data.subjects || [],
         }
     });
  }

  async updateTeacher(teacherId: string, instituteId: string, data: UpdateTeacherInput) {
    return prisma.teacher.update({
      where: { id: teacherId },
      data: data as any
    });
  }

  async toggleStatus(teacherId: string, isActive: boolean) {
    return prisma.teacher.update({
      where: { id: teacherId },
      data: { is_active: isActive }
    });
  }
}

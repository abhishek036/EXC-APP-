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

  async createTeacherWithUser(instituteId: string, data: CreateTeacherInput, _passwordHash?: string) {
     if (!data.phone) throw new Error('Phone is required for Teacher creation');

     const normalizedSubjects = Array.from(new Set([
       ...(data.subjects ?? []),
       ...(data.subject ? [data.subject] : []),
     ].map((item) => item.trim()).filter((item) => item.length > 0)));

     return prisma.teacher.create({
         data: {
             institute_id: instituteId,
             phone: data.phone,
             name: data.name,
             email: data.email,
             qualification: data.qualification,
             subjects: normalizedSubjects,
         }
     });
  }

  async updateTeacher(teacherId: string, instituteId: string, data: UpdateTeacherInput) {
    const patch = (data ?? {}) as NonNullable<UpdateTeacherInput>;

    const updateData: Record<string, unknown> = {
      name: patch.name,
      phone: patch.phone,
      email: patch.email,
      qualification: patch.qualification,
      is_active: (patch as any).is_active,
    };

    const normalizedSubjects = Array.from(new Set([
      ...((patch.subjects ?? []) as string[]),
      ...(patch.subject ? [patch.subject] : []),
    ].map((item) => item.trim()).filter((item) => item.length > 0)));

    if (normalizedSubjects.length > 0) {
      updateData['subjects'] = normalizedSubjects;
    }

    Object.keys(updateData).forEach((key) => {
      if (updateData[key] === undefined) delete updateData[key];
    });

    return prisma.teacher.update({
      where: { id: teacherId },
      data: updateData as any
    });
  }

  async toggleStatus(teacherId: string, isActive: boolean) {
    return prisma.teacher.update({
      where: { id: teacherId },
      data: { is_active: isActive }
    });
  }

  async removeTeacher(teacherId: string) {
    return prisma.teacher.update({
      where: { id: teacherId },
      data: { is_active: false }
    });
  }
}

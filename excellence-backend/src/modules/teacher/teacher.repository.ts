import { prisma } from '../../config/prisma';
import { CreateTeacherInput, UpdateTeacherInput } from './teacher.validator';
import { Prisma } from '@prisma/client';

export class TeacherRepository {
  private pruneTeacherFromBatchMeta(settings: unknown, teacherIdentifiers: string[]): Record<string, unknown> {
    const currentSettings =
      settings && typeof settings === 'object' && !Array.isArray(settings)
        ? { ...(settings as Record<string, unknown>) }
        : {};

    const rawBatchMeta = currentSettings['batch_meta'];
    if (!rawBatchMeta || typeof rawBatchMeta !== 'object' || Array.isArray(rawBatchMeta)) {
      return currentSettings;
    }

    const nextBatchMeta: Record<string, unknown> = {};
    for (const [batchId, value] of Object.entries(rawBatchMeta as Record<string, unknown>)) {
      if (!value || typeof value !== 'object' || Array.isArray(value)) {
        nextBatchMeta[batchId] = value;
        continue;
      }

      const meta = { ...(value as Record<string, unknown>) };
      if (Array.isArray(meta['teacher_ids'])) {
        meta['teacher_ids'] = (meta['teacher_ids'] as unknown[]).filter((id) => {
          const normalizedId = String(id ?? '').trim();
          return normalizedId.length > 0 && !teacherIdentifiers.includes(normalizedId);
        });
      }
      nextBatchMeta[batchId] = meta;
    }

    return {
      ...currentSettings,
      batch_meta: nextBatchMeta,
    };
  }

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

  async removeTeacher(teacherId: string, instituteId: string) {
    return prisma.$transaction(async (tx) => {
      const teacher = await tx.teacher.findFirst({
        where: { id: teacherId, institute_id: instituteId },
        select: { id: true, user_id: true },
      });

      if (!teacher) return null;

      const teacherIdentifiers = [teacher.id, teacher.user_id].filter((id): id is string => Boolean(id));

      await Promise.all([
        tx.batch.updateMany({
          where: { institute_id: instituteId, teacher_id: teacherId },
          data: { teacher_id: null },
        }),
        tx.lecture.updateMany({
          where: { institute_id: instituteId, teacher_id: teacherId },
          data: { teacher_id: null },
        }),
        tx.attendanceSession.updateMany({
          where: { institute_id: instituteId, teacher_id: teacherId },
          data: { teacher_id: null },
        }),
        tx.quiz.updateMany({
          where: { institute_id: instituteId, teacher_id: teacherId },
          data: { teacher_id: null },
        }),
        tx.note.updateMany({
          where: { institute_id: instituteId, teacher_id: teacherId },
          data: { teacher_id: null },
        }),
        tx.assignment.updateMany({
          where: { institute_id: instituteId, teacher_id: teacherId },
          data: { teacher_id: null },
        }),
        tx.doubt.updateMany({
          where: { institute_id: instituteId, assigned_to_id: teacherId },
          data: { assigned_to_id: null },
        }),
      ]);

      const institute = await tx.institute.findUnique({
        where: { id: instituteId },
        select: { settings: true },
      });

      const nextSettings = this.pruneTeacherFromBatchMeta(institute?.settings, teacherIdentifiers);
      await tx.institute.update({
        where: { id: instituteId },
        data: { settings: nextSettings as Prisma.InputJsonValue },
      });

      if (teacher.user_id) {
        await Promise.all([
          tx.refreshToken.deleteMany({ where: { user_id: teacher.user_id } }),
          tx.userDeviceToken.updateMany({
            where: { institute_id: instituteId, user_id: teacher.user_id },
            data: { is_active: false },
          }),
          tx.user.updateMany({
            where: { id: teacher.user_id, institute_id: instituteId },
            data: {
              is_active: false,
              status: 'INACTIVE',
              last_login_at: new Date(),
            },
          }),
        ]);
      }

      return tx.teacher.delete({
        where: { id: teacherId },
      });
    });
  }
}

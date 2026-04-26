import { prisma } from '../config/prisma';
import { ApiError } from '../middleware/error.middleware';
import { batchHasTeacher } from './batch-teacher-assignment';

export type TeacherScope = {
  teacherId: string;
  batchIds: string[];
};

export const resolveTeacherScope = async (
  instituteId: string,
  userId: string,
): Promise<TeacherScope> => {
  const teacher = await prisma.teacher.findFirst({
    where: {
      user_id: userId,
      institute_id: instituteId,
      is_active: true,
    },
    select: { id: true, user_id: true },
  });

  if (!teacher) {
    throw new ApiError('Teacher profile not found for this account', 404, 'NOT_FOUND');
  }

  const [directBatches, institute] = await Promise.all([
    prisma.batch.findMany({
      where: {
        institute_id: instituteId,
        teacher_id: teacher.id,
      },
      select: { id: true, teacher_id: true },
    }),
    prisma.institute.findUnique({
      where: { id: instituteId },
      select: { settings: true },
    }),
  ]);

  const batchIds = new Set<string>(directBatches.map((batch) => batch.id));

  const settings = (institute?.settings ?? {}) as Record<string, unknown>;
  const batchMeta = settings.batch_meta;
  if (batchMeta && typeof batchMeta === 'object' && !Array.isArray(batchMeta)) {
    for (const batch of directBatches) {
      const meta = (batchMeta as Record<string, unknown>)[batch.id] as Record<string, unknown> | undefined;
      if (batchHasTeacher(meta, batch.teacher_id, [teacher.id, teacher.user_id])) {
        batchIds.add(batch.id);
      }
    }

    for (const [batchId, metaValue] of Object.entries(batchMeta as Record<string, unknown>)) {
      if (batchIds.has(batchId)) continue;

      const meta = (metaValue ?? {}) as Record<string, unknown>;
      if (batchHasTeacher(meta, null, [teacher.id, teacher.user_id])) {
        batchIds.add(batchId);
      }
    }
  } else {
    for (const batch of directBatches) {
      batchIds.add(batch.id);
    }
  }

  return {
    teacherId: teacher.id,
    batchIds: Array.from(batchIds),
  };
};

import { prisma } from '../server';
import { ApiError } from '../middleware/error.middleware';

export type TeacherScope = {
  teacherId: string;
  batchIds: string[];
};

const normalizeTeacherIds = (value: unknown): string[] => {
  if (!Array.isArray(value)) return [];

  return value
    .map((item) => String(item || '').trim())
    .filter((item) => item.length > 0);
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
    select: { id: true },
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
      select: { id: true },
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
    for (const [batchId, metaValue] of Object.entries(batchMeta as Record<string, unknown>)) {
      const meta = (metaValue ?? {}) as Record<string, unknown>;
      const assignedTeacherIds = normalizeTeacherIds(meta.teacher_ids);
      if (assignedTeacherIds.includes(teacher.id)) {
        batchIds.add(batchId);
      }
    }
  }

  return {
    teacherId: teacher.id,
    batchIds: Array.from(batchIds),
  };
};

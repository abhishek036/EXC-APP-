import { prisma } from '../../server';
import { ApiError } from '../../middleware/error.middleware';

export class TimetableService {
  private readonly logger = console;

  private isMissingLectureDurationColumn(error: unknown): boolean {
    const code = (error as any)?.code;
    const column = (error as any)?.meta?.column;
    return code === 'P2022' && typeof column === 'string' && column.includes('lectures.duration_minutes');
  }

  private async assertBatchOwnedByTeacher(batchId: string, instituteId: string, teacherId: string) {
    const batch = await prisma.batch.findFirst({
      where: { id: batchId, institute_id: instituteId, teacher_id: teacherId, is_active: true },
      select: { id: true, name: true, subject: true },
    });
    if (!batch) {
      throw new ApiError('Batch not found or not assigned to teacher', 404, 'NOT_FOUND');
    }
    return batch;
  }

  private async checkTeacherLectureConflict(instituteId: string, teacherId: string, scheduledAt: Date, durationMinutes: number, excludeLectureId?: string) {
    const lectureStart = scheduledAt;
    const lectureEnd = new Date(lectureStart.getTime() + durationMinutes * 60000);

    let candidates: Array<{ id: string; scheduled_at: Date | null; duration_minutes?: number | null }> = [];
    try {
      candidates = await prisma.lecture.findMany({
        where: {
          institute_id: instituteId,
          teacher_id: teacherId,
          is_active: true,
          ...(excludeLectureId ? { id: { not: excludeLectureId } } : {}),
          scheduled_at: {
            gte: new Date(lectureStart.getTime() - 240 * 60000),
            lte: lectureEnd,
          },
        },
        select: { id: true, scheduled_at: true, duration_minutes: true },
      });
    } catch (error) {
      if (!this.isMissingLectureDurationColumn(error)) throw error;
      const fallback = await prisma.lecture.findMany({
        where: {
          institute_id: instituteId,
          teacher_id: teacherId,
          is_active: true,
          ...(excludeLectureId ? { id: { not: excludeLectureId } } : {}),
          scheduled_at: {
            gte: new Date(lectureStart.getTime() - 240 * 60000),
            lte: lectureEnd,
          },
        },
        select: { id: true, scheduled_at: true },
      });
      candidates = fallback;
    }

    for (const c of candidates) {
      if (!c.scheduled_at) continue;
      const cStart = new Date(c.scheduled_at);
      const cEnd = new Date(cStart.getTime() + (c.duration_minutes || 60) * 60000);
      if (lectureStart < cEnd && lectureEnd > cStart) {
        throw new ApiError('Teacher is already busy during this time slot', 400, 'CONFLICT');
      }
    }
  }

  /**
   * Schedules a new lecture.
   * Checks for conflicts (Same teacher or same room at the same time).
   */
  async scheduleLecture(instituteId: string, data: { batchId: string, teacherId: string, subject: string, scheduledAt: string, duration: number, room?: string, link?: string }) {
    const lectureStart = new Date(data.scheduledAt);
    const lectureEnd = new Date(lectureStart.getTime() + data.duration * 60000);

    // 1. Check teacher conflict with overlapping slots
    let candidates: Array<{ scheduled_at: Date | null; duration_minutes?: number | null }> = [];
    try {
      candidates = await prisma.lecture.findMany({
        where: {
          institute_id: instituteId,
          scheduled_at: {
            gte: new Date(lectureStart.getTime() - 240 * 60000),
            lte: lectureEnd,
          },
          teacher_id: data.teacherId,
        },
        select: {
          scheduled_at: true,
          duration_minutes: true,
        },
      });
    } catch (error) {
      if (!this.isMissingLectureDurationColumn(error)) throw error;
      candidates = await prisma.lecture.findMany({
        where: {
          institute_id: instituteId,
          scheduled_at: {
            gte: new Date(lectureStart.getTime() - 240 * 60000),
            lte: lectureEnd,
          },
          teacher_id: data.teacherId,
        },
        select: {
          scheduled_at: true,
        },
      });
    }

    for (const c of candidates) {
        if (!c.scheduled_at) continue;
        const cStart = new Date(c.scheduled_at);
        const cEnd = new Date(cStart.getTime() + (c.duration_minutes || 60) * 60000);
        
        if (lectureStart < cEnd && lectureEnd > cStart) {
            throw new ApiError('Teacher is already busy during this time slot', 400, 'CONFLICT');
        }
    }

    // 2. Schedule
    try {
      return await prisma.lecture.create({
        data: {
          institute_id: instituteId,
          batch_id: data.batchId,
          teacher_id: data.teacherId,
          title: `${data.subject} - ${data.batchId}`,
          scheduled_at: lectureStart,
          duration_minutes: data.duration,
        },
        select: {
          id: true,
          title: true,
          scheduled_at: true,
          duration_minutes: true,
          batch_id: true,
          teacher_id: true,
        },
      });
    } catch (error) {
      if (!this.isMissingLectureDurationColumn(error)) throw error;
      this.logger.warn('[TimetableService] lectures.duration_minutes column missing; using scheduleLecture fallback create path');
      const createdLecture = await prisma.lecture.create({
        data: {
          institute_id: instituteId,
          batch_id: data.batchId,
          teacher_id: data.teacherId,
          title: `${data.subject} - ${data.batchId}`,
          scheduled_at: lectureStart,
        },
        select: {
          id: true,
          title: true,
          scheduled_at: true,
          batch_id: true,
          teacher_id: true,
        },
      });
      return {
        ...createdLecture,
        duration_minutes: data.duration ?? null,
      };
    }
  }

  async getTeacherScheduleByUser(userId: string, instituteId: string, date?: string) {
    const teacher = await prisma.teacher.findFirst({
      where: { user_id: userId, institute_id: instituteId },
      select: { id: true },
    });
    if (!teacher) throw new ApiError('Teacher not found', 404, 'NOT_FOUND');

    let start: Date | undefined;
    let end: Date | undefined;
    if (date) {
      const parsed = new Date(date);
      if (!isNaN(parsed.getTime())) {
        start = new Date(parsed);
        start.setHours(0, 0, 0, 0);
        end = new Date(parsed);
        end.setHours(23, 59, 59, 999);
      }
    }

    try {
      return await prisma.lecture.findMany({
        where: {
          institute_id: instituteId,
          teacher_id: teacher.id,
          is_active: true,
          ...(start && end ? { scheduled_at: { gte: start, lte: end } } : {}),
        },
        select: {
          id: true,
          title: true,
          scheduled_at: true,
          duration_minutes: true,
          batch_id: true,
          batch: { select: { name: true, subject: true } },
        },
        orderBy: { scheduled_at: 'asc' },
      });
    } catch (error) {
      if (!this.isMissingLectureDurationColumn(error)) throw error;
      return prisma.lecture.findMany({
        where: {
          institute_id: instituteId,
          teacher_id: teacher.id,
          is_active: true,
          ...(start && end ? { scheduled_at: { gte: start, lte: end } } : {}),
        },
        select: {
          id: true,
          title: true,
          scheduled_at: true,
          batch_id: true,
          batch: { select: { name: true, subject: true } },
        },
        orderBy: { scheduled_at: 'asc' },
      });
    }
  }

  async createTeacherScheduleByUser(
    userId: string,
    instituteId: string,
    data: { batch_id: string; title: string; scheduled_at: string; duration_minutes?: number },
  ) {
    const teacher = await prisma.teacher.findFirst({
      where: { user_id: userId, institute_id: instituteId },
      select: { id: true },
    });
    if (!teacher) throw new ApiError('Teacher not found', 404, 'NOT_FOUND');

    const scheduledAt = new Date(data.scheduled_at);
    if (isNaN(scheduledAt.getTime())) throw new ApiError('Invalid scheduled_at', 400, 'VALIDATION_ERROR');

    const duration = data.duration_minutes && data.duration_minutes > 0 ? data.duration_minutes : 60;
    await this.assertBatchOwnedByTeacher(data.batch_id, instituteId, teacher.id);
    await this.checkTeacherLectureConflict(instituteId, teacher.id, scheduledAt, duration);

    try {
      return await prisma.lecture.create({
        data: {
          institute_id: instituteId,
          batch_id: data.batch_id,
          teacher_id: teacher.id,
          title: data.title,
          scheduled_at: scheduledAt,
          duration_minutes: duration,
          is_active: true,
        },
        select: {
          id: true,
          title: true,
          scheduled_at: true,
          duration_minutes: true,
          batch_id: true,
        },
      });
    } catch (error) {
      if (!this.isMissingLectureDurationColumn(error)) throw error;
      return prisma.lecture.create({
        data: {
          institute_id: instituteId,
          batch_id: data.batch_id,
          teacher_id: teacher.id,
          title: data.title,
          scheduled_at: scheduledAt,
          is_active: true,
        },
        select: {
          id: true,
          title: true,
          scheduled_at: true,
          batch_id: true,
        },
      });
    }
  }

  async updateTeacherScheduleByUser(
    userId: string,
    instituteId: string,
    lectureId: string,
    data: { title?: string; scheduled_at?: string; duration_minutes?: number; batch_id?: string },
  ) {
    const teacher = await prisma.teacher.findFirst({
      where: { user_id: userId, institute_id: instituteId },
      select: { id: true },
    });
    if (!teacher) throw new ApiError('Teacher not found', 404, 'NOT_FOUND');

    let current: { id: string; batch_id: string; scheduled_at: Date | null; duration_minutes?: number | null } | null = null;
    try {
      current = await prisma.lecture.findFirst({
        where: { id: lectureId, institute_id: instituteId, teacher_id: teacher.id, is_active: true },
        select: { id: true, batch_id: true, scheduled_at: true, duration_minutes: true },
      });
    } catch (error) {
      if (!this.isMissingLectureDurationColumn(error)) throw error;
      current = await prisma.lecture.findFirst({
        where: { id: lectureId, institute_id: instituteId, teacher_id: teacher.id, is_active: true },
        select: { id: true, batch_id: true, scheduled_at: true },
      });
    }
    if (!current) throw new ApiError('Schedule item not found', 404, 'NOT_FOUND');

    const nextBatchId = data.batch_id ?? current.batch_id;
    await this.assertBatchOwnedByTeacher(nextBatchId, instituteId, teacher.id);

    const nextScheduledAt = data.scheduled_at ? new Date(data.scheduled_at) : (current.scheduled_at ?? new Date());
    if (isNaN(nextScheduledAt.getTime())) throw new ApiError('Invalid scheduled_at', 400, 'VALIDATION_ERROR');

    const nextDuration = data.duration_minutes && data.duration_minutes > 0
      ? data.duration_minutes
      : (current.duration_minutes ?? 60);

    await this.checkTeacherLectureConflict(instituteId, teacher.id, nextScheduledAt, nextDuration, lectureId);

    try {
      return await prisma.lecture.update({
        where: { id: lectureId },
        data: {
          batch_id: nextBatchId,
          title: data.title,
          scheduled_at: nextScheduledAt,
          duration_minutes: nextDuration,
        },
        select: {
          id: true,
          title: true,
          scheduled_at: true,
          duration_minutes: true,
          batch_id: true,
        },
      });
    } catch (error) {
      if (!this.isMissingLectureDurationColumn(error)) throw error;
      return prisma.lecture.update({
        where: { id: lectureId },
        data: {
          batch_id: nextBatchId,
          title: data.title,
          scheduled_at: nextScheduledAt,
        },
        select: {
          id: true,
          title: true,
          scheduled_at: true,
          batch_id: true,
        },
      });
    }
  }

  async deleteTeacherScheduleByUser(userId: string, instituteId: string, lectureId: string) {
    const teacher = await prisma.teacher.findFirst({
      where: { user_id: userId, institute_id: instituteId },
      select: { id: true },
    });
    if (!teacher) throw new ApiError('Teacher not found', 404, 'NOT_FOUND');

    const lecture = await prisma.lecture.findFirst({
      where: { id: lectureId, institute_id: instituteId, teacher_id: teacher.id, is_active: true },
      select: { id: true },
    });
    if (!lecture) throw new ApiError('Schedule item not found', 404, 'NOT_FOUND');

    await prisma.lecture.update({
      where: { id: lectureId },
      data: { is_active: false },
      select: { id: true },
    });
  }

  async getTeacherScheduleItemByUser(userId: string, instituteId: string, lectureId: string) {
    const teacher = await prisma.teacher.findFirst({
      where: { user_id: userId, institute_id: instituteId },
      select: { id: true },
    });
    if (!teacher) throw new ApiError('Teacher not found', 404, 'NOT_FOUND');

    const lecture = await prisma.lecture.findFirst({
      where: { id: lectureId, institute_id: instituteId, teacher_id: teacher.id, is_active: true },
      select: { id: true, batch_id: true },
    });
    if (!lecture) throw new ApiError('Schedule item not found', 404, 'NOT_FOUND');
    return lecture;
  }

  async getBatchTimetable(batchId: string, instituteId: string) {
    try {
      return await prisma.lecture.findMany({
        where: { batch_id: batchId, institute_id: instituteId },
        select: {
          id: true,
          title: true,
          scheduled_at: true,
          duration_minutes: true,
          batch_id: true,
          teacher_id: true,
          teacher: { select: { name: true } },
        },
        orderBy: { scheduled_at: 'asc' }
      });
    } catch (error) {
      if (!this.isMissingLectureDurationColumn(error)) throw error;
      return prisma.lecture.findMany({
        where: { batch_id: batchId, institute_id: instituteId },
        select: {
          id: true,
          title: true,
          scheduled_at: true,
          batch_id: true,
          teacher_id: true,
          teacher: { select: { name: true } },
        },
        orderBy: { scheduled_at: 'asc' }
      });
    }
  }

  async getTeacherTimetable(teacherId: string, instituteId: string) {
    try {
      return await prisma.lecture.findMany({
        where: { teacher_id: teacherId, institute_id: instituteId },
        select: {
          id: true,
          title: true,
          scheduled_at: true,
          duration_minutes: true,
          batch_id: true,
          teacher_id: true,
          batch: { select: { name: true } },
        },
        orderBy: { scheduled_at: 'asc' }
      });
    } catch (error) {
      if (!this.isMissingLectureDurationColumn(error)) throw error;
      return prisma.lecture.findMany({
        where: { teacher_id: teacherId, institute_id: instituteId },
        select: {
          id: true,
          title: true,
          scheduled_at: true,
          batch_id: true,
          teacher_id: true,
          batch: { select: { name: true } },
        },
        orderBy: { scheduled_at: 'asc' }
      });
    }
  }
}

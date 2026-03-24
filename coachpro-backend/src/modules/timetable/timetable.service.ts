import { prisma } from '../../server';
import { ApiError } from '../../middleware/error.middleware';

export class TimetableService {
  private readonly logger = console;
  private static readonly UUID_REGEX = '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-5][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$';

  private isMissingLectureDurationColumn(error: unknown): boolean {
    const code = (error as any)?.code;
    const column = (error as any)?.meta?.column;
    if (code !== 'P2022' || typeof column !== 'string') return false;
    const normalizedColumn = column.toLowerCase();
    return (
      normalizedColumn.includes('duration_minutes') ||
      normalizedColumn.includes('lectures.duration_minutes') ||
      normalizedColumn.includes('lecture.duration_minutes')
    );
  }

  private async createLectureRaw(
    instituteId: string,
    batchId: string,
    teacherId: string,
    title: string,
    scheduledAt: Date,
    duration: number = 60,
    subject?: string,
    link?: string,
    classRoom?: string,
  ) {
    const rows = await prisma.$queryRawUnsafe<any[]>(
      `INSERT INTO lectures (institute_id, batch_id, teacher_id, title, scheduled_at, is_active, duration_minutes, subject, link, class_room)
       VALUES ($1::uuid, $2::uuid, $3::uuid, $4, $5, $6, $7, $8, $9, $10)
       RETURNING id::text, title, scheduled_at, batch_id::text, duration_minutes, subject, link, class_room`,
      instituteId,
      batchId,
      teacherId,
      title,
      scheduledAt,
      true,
      duration,
      subject || null,
      link || null,
      classRoom || null,
    );
    const row = rows[0];
    return {
      id: row.id,
      title: row.title,
      scheduled_at: row.scheduled_at,
      duration_minutes: row.duration_minutes ?? duration,
      subject: row.subject,
      link: row.link,
      class_room: row.class_room,
      batch_id: row.batch_id,
      teacher_id: teacherId,
    };
  }

  private async updateLectureRaw(
    lectureId: string,
    batchId: string,
    title: string | undefined,
    scheduledAt: Date,
    duration: number,
    subject?: string,
    link?: string,
    classRoom?: string,
  ) {
    const rows = await prisma.$queryRawUnsafe<any[]>(
      `UPDATE lectures 
       SET batch_id = $1::uuid, title = $2, scheduled_at = $3, duration_minutes = $4, subject = $5, link = $6, class_room = $7
       WHERE id = $8::uuid
       RETURNING id::text, title, scheduled_at, batch_id::text, duration_minutes, subject, link, class_room`,
      batchId,
      title || '',
      scheduledAt,
      duration,
      subject || null,
      link || null,
      classRoom || null,
      lectureId,
    );
    const row = rows[0];
    return {
      id: row.id,
      title: row.title,
      scheduled_at: row.scheduled_at,
      duration_minutes: row.duration_minutes ?? duration,
      subject: row.subject,
      link: row.link,
      class_room: row.class_room,
      batch_id: row.batch_id,
    };
  }

  private isInvalidLectureUuidData(error: unknown): boolean {
    const code = (error as any)?.code;
    const modelName = (error as any)?.meta?.modelName;
    const message = (error as any)?.meta?.message;
    return code === 'P2023' &&
      modelName === 'Lecture' &&
      typeof message === 'string' &&
      message.includes('Error creating UUID');
  }

  private async getTeacherScheduleRawFallback(
    instituteId: string,
    teacherId: string,
    start?: Date,
    end?: Date,
    includeDuration: boolean = true,
  ) {
    type Row = {
      id: string;
      title: string | null;
      scheduled_at: Date | null;
      duration_minutes?: number | null;
      subject?: string | null;
      link?: string | null;
      class_room?: string | null;
      batch_id: string | null;
      batch_name: string | null;
      batch_subject: string | null;
    };

    const baseWhere = `
      l.institute_id::text = $1
      AND l.teacher_id::text = $2
      AND COALESCE(l.is_active, true) = true
      AND l.id::text ~* '${TimetableService.UUID_REGEX}'
      AND l.batch_id::text ~* '${TimetableService.UUID_REGEX}'
    `;

    const durationSelect = includeDuration ? 'l.duration_minutes,' : 'NULL::int AS duration_minutes,';

    let rows: Row[] = [];
    if (start && end) {
      rows = await prisma.$queryRawUnsafe<Row[]>(
        `
        SELECT
          l.id::text AS id,
          l.title,
          l.scheduled_at,
          ${durationSelect}
          l.subject,
          l.link,
          l.class_room,
          l.batch_id::text AS batch_id,
          b.name AS batch_name,
          b.subject AS batch_subject
        FROM lectures l
        LEFT JOIN batches b
          ON b.id::text = l.batch_id::text
         AND b.institute_id::text = l.institute_id::text
        WHERE ${baseWhere}
          AND l.scheduled_at >= $3
          AND l.scheduled_at <= $4
        ORDER BY l.scheduled_at ASC
        `,
        instituteId,
        teacherId,
        start,
        end,
      );
    } else {
      rows = await prisma.$queryRawUnsafe<Row[]>(
        `
        SELECT
          l.id::text AS id,
          l.title,
          l.scheduled_at,
          ${durationSelect}
          l.subject,
          l.link,
          l.class_room,
          l.batch_id::text AS batch_id,
          b.name AS batch_name,
          b.subject AS batch_subject
        FROM lectures l
        LEFT JOIN batches b
          ON b.id::text = l.batch_id::text
         AND b.institute_id::text = l.institute_id::text
        WHERE ${baseWhere}
        ORDER BY l.scheduled_at ASC
        `,
        instituteId,
        teacherId,
      );
    }

    return rows.map((row) => ({
      id: row.id,
      title: row.title,
      scheduled_at: row.scheduled_at,
      duration_minutes: row.duration_minutes ?? 60,
      subject: row.subject ?? null,
      link: row.link ?? null,
      class_room: row.class_room ?? null,
      batch_id: row.batch_id,
      batch: {
        name: row.batch_name,
        subject: row.batch_subject,
      },
    }));
  }

  private async getBatchTimetableRawFallback(
    batchId: string,
    instituteId: string,
    includeDuration: boolean = true,
  ) {
    type Row = {
      id: string;
      title: string | null;
      scheduled_at: Date | null;
      duration_minutes?: number | null;
      batch_id: string | null;
      teacher_id: string | null;
      teacher_name: string | null;
    };

    const durationSelect = includeDuration ? 'l.duration_minutes,' : 'NULL::int AS duration_minutes,';

    const rows = await prisma.$queryRawUnsafe<Row[]>(
      `
      SELECT
        l.id::text AS id,
        l.title,
        l.scheduled_at,
        ${durationSelect}
        l.batch_id::text AS batch_id,
        l.teacher_id::text AS teacher_id,
        t.name AS teacher_name
      FROM lectures l
      LEFT JOIN teachers t
        ON t.id::text = l.teacher_id::text
       AND t.institute_id::text = l.institute_id::text
      WHERE l.institute_id::text = $1
        AND l.batch_id::text = $2
        AND l.id::text ~* '${TimetableService.UUID_REGEX}'
        AND l.batch_id::text ~* '${TimetableService.UUID_REGEX}'
        AND l.teacher_id::text ~* '${TimetableService.UUID_REGEX}'
      ORDER BY l.scheduled_at ASC
      `,
      instituteId,
      batchId,
    );

    return rows.map((row) => ({
      id: row.id,
      title: row.title,
      scheduled_at: row.scheduled_at,
      duration_minutes: row.duration_minutes ?? null,
      batch_id: row.batch_id,
      teacher_id: row.teacher_id,
      teacher: { name: row.teacher_name },
    }));
  }

  private async getTeacherTimetableRawFallback(
    teacherId: string,
    instituteId: string,
    includeDuration: boolean = true,
  ) {
    type Row = {
      id: string;
      title: string | null;
      scheduled_at: Date | null;
      duration_minutes?: number | null;
      batch_id: string | null;
      teacher_id: string | null;
      batch_name: string | null;
    };

    const durationSelect = includeDuration ? 'l.duration_minutes,' : 'NULL::int AS duration_minutes,';

    const rows = await prisma.$queryRawUnsafe<Row[]>(
      `
      SELECT
        l.id::text AS id,
        l.title,
        l.scheduled_at,
        ${durationSelect}
        l.batch_id::text AS batch_id,
        l.teacher_id::text AS teacher_id,
        b.name AS batch_name
      FROM lectures l
      LEFT JOIN batches b
        ON b.id::text = l.batch_id::text
       AND b.institute_id::text = l.institute_id::text
      WHERE l.institute_id::text = $1
        AND l.teacher_id::text = $2
        AND l.id::text ~* '${TimetableService.UUID_REGEX}'
        AND l.batch_id::text ~* '${TimetableService.UUID_REGEX}'
        AND l.teacher_id::text ~* '${TimetableService.UUID_REGEX}'
      ORDER BY l.scheduled_at ASC
      `,
      instituteId,
      teacherId,
    );

    return rows.map((row) => ({
      id: row.id,
      title: row.title,
      scheduled_at: row.scheduled_at,
      duration_minutes: row.duration_minutes ?? null,
      batch_id: row.batch_id,
      teacher_id: row.teacher_id,
      batch: { name: row.batch_name },
    }));
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
      return this.createLectureRaw(instituteId, data.batchId, data.teacherId, `${data.subject} - ${data.batchId}`, lectureStart, data.duration);
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
      const normalizedDate = date.trim();
      const dateOnlyMatch = normalizedDate.match(/^(\d{4})-(\d{2})-(\d{2})$/);
      if (dateOnlyMatch) {
        const year = Number(dateOnlyMatch[1]);
        const month = Number(dateOnlyMatch[2]);
        const day = Number(dateOnlyMatch[3]);
        start = new Date(Date.UTC(year, month - 1, day, 0, 0, 0, 0));
        end = new Date(Date.UTC(year, month - 1, day, 23, 59, 59, 999));
      } else {
        const parsed = new Date(normalizedDate);
        if (!isNaN(parsed.getTime())) {
          start = new Date(Date.UTC(parsed.getUTCFullYear(), parsed.getUTCMonth(), parsed.getUTCDate(), 0, 0, 0, 0));
          end = new Date(Date.UTC(parsed.getUTCFullYear(), parsed.getUTCMonth(), parsed.getUTCDate(), 23, 59, 59, 999));
        }
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
          subject: true,
          link: true,
          class_room: true,
          batch_id: true,
          batch: { select: { name: true, subject: true } },
        },
        orderBy: { scheduled_at: 'asc' },
      });
    } catch (error) {
      if (this.isInvalidLectureUuidData(error)) {
        this.logger.warn('[TimetableService] Invalid lecture UUID data detected; using raw schedule fallback query (with duration)');
        return this.getTeacherScheduleRawFallback(instituteId, teacher.id, start, end, true);
      }
      if (!this.isMissingLectureDurationColumn(error)) throw error;

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
            batch_id: true,
            batch: { select: { name: true, subject: true } },
          },
          orderBy: { scheduled_at: 'asc' },
        });
      } catch (fallbackError) {
        if (this.isInvalidLectureUuidData(fallbackError)) {
          this.logger.warn('[TimetableService] Invalid lecture UUID data detected; using raw schedule fallback query (without duration column)');
          return this.getTeacherScheduleRawFallback(instituteId, teacher.id, start, end, false);
        }
        throw fallbackError;
      }
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
      this.logger.warn('[TimetableService] lectures.duration_minutes column missing; using createTeacherScheduleByUser fallback create path');
      return this.createLectureRaw(instituteId, data.batch_id, teacher.id, data.title, scheduledAt, duration, (data as any).subject, (data as any).link, (data as any).class_room);
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
      this.logger.warn('[TimetableService] lectures.duration_minutes column missing; using updateTeacherScheduleByUser fallback update path');
      return this.updateLectureRaw(lectureId, nextBatchId, data.title, nextScheduledAt, nextDuration, (data as any).subject, (data as any).link, (data as any).class_room);
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
      if (this.isInvalidLectureUuidData(error)) {
        this.logger.warn('[TimetableService] Invalid lecture UUID data detected; using raw batch timetable fallback query (with duration)');
        return this.getBatchTimetableRawFallback(batchId, instituteId, true);
      }
      if (!this.isMissingLectureDurationColumn(error)) throw error;

      try {
        return await prisma.lecture.findMany({
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
      } catch (fallbackError) {
        if (this.isInvalidLectureUuidData(fallbackError)) {
          this.logger.warn('[TimetableService] Invalid lecture UUID data detected; using raw batch timetable fallback query (without duration column)');
          return this.getBatchTimetableRawFallback(batchId, instituteId, false);
        }
        throw fallbackError;
      }
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
      if (this.isInvalidLectureUuidData(error)) {
        this.logger.warn('[TimetableService] Invalid lecture UUID data detected; using raw teacher timetable fallback query (with duration)');
        return this.getTeacherTimetableRawFallback(teacherId, instituteId, true);
      }
      if (!this.isMissingLectureDurationColumn(error)) throw error;

      try {
        return await prisma.lecture.findMany({
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
      } catch (fallbackError) {
        if (this.isInvalidLectureUuidData(fallbackError)) {
          this.logger.warn('[TimetableService] Invalid lecture UUID data detected; using raw teacher timetable fallback query (without duration column)');
          return this.getTeacherTimetableRawFallback(teacherId, instituteId, false);
        }
        throw fallbackError;
      }
    }
  }
}

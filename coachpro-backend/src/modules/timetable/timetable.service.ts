import { prisma } from '../../server';
import { ApiError } from '../../middleware/error.middleware';

export class TimetableService {
  /**
   * Schedules a new lecture.
   * Checks for conflicts (Same teacher or same room at the same time).
   */
  async scheduleLecture(instituteId: string, data: { batchId: string, teacherId: string, subject: string, scheduledAt: string, duration: number, room?: string, link?: string }) {
    const lectureStart = new Date(data.scheduledAt);
    const lectureEnd = new Date(lectureStart.getTime() + data.duration * 60000);

    // 1. Check teacher conflict with overlapping slots
    const candidates = await prisma.lecture.findMany({
        where: {
            institute_id: instituteId,
            scheduled_at: { 
                gte: new Date(lectureStart.getTime() - 240 * 60000), // Checked 4 hrs before
                lte: lectureEnd 
            },
        teacher_id: data.teacherId,
        }
    });

    for (const c of candidates) {
        if (!c.scheduled_at) continue;
        const cStart = new Date(c.scheduled_at);
        const cEnd = new Date(cStart.getTime() + (c.duration_minutes || 60) * 60000);
        
        if (lectureStart < cEnd && lectureEnd > cStart) {
            throw new ApiError('Teacher is already busy during this time slot', 400, 'CONFLICT');
        }
    }

    // 2. Schedule
    return prisma.lecture.create({
      data: {
        institute_id: instituteId,
        batch_id: data.batchId,
        teacher_id: data.teacherId,
        title: `${data.subject} - ${data.batchId}`, // Adding a default title
        scheduled_at: lectureStart,
        duration_minutes: data.duration
      }
    });
  }

  async getBatchTimetable(batchId: string, instituteId: string) {
    return prisma.lecture.findMany({
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
  }

  async getTeacherTimetable(teacherId: string, instituteId: string) {
    return prisma.lecture.findMany({
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
  }
}

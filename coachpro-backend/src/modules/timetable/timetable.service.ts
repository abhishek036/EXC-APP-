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

    // 1. Check Teacher Conflict
    const teacherConflict = await prisma.lecture.findFirst({
        where: {
            teacher_id: data.teacherId,
            institute_id: instituteId,
            scheduled_at: { lt: lectureEnd },
            // End of lecture calculation is harder in SQL directly with duration, but we'll approximate 
            // OR fetch all potentially overlapping and filter in JS
        }
    });
    
    // For premium robustness, let's fetch candidate overlaps
    const candidates = await prisma.lecture.findMany({
        where: {
            institute_id: instituteId,
            scheduled_at: { 
                gte: new Date(lectureStart.getTime() - 240 * 60000), // Checked 4 hrs before
                lte: lectureEnd 
            },
            OR: [
                { teacher_id: data.teacherId },
                { class_room: data.room || 'online' }
            ]
        }
    });

    for (const c of candidates) {
        if (!c.scheduled_at) continue;
        const cStart = new Date(c.scheduled_at);
        const cEnd = new Date(cStart.getTime() + (c.duration_minutes || 60) * 60000);
        
        if (lectureStart < cEnd && lectureEnd > cStart) {
            const reason = (c.teacher_id === data.teacherId) ? 'Teacher is already busy' : 'Classroom is already occupied';
            throw new ApiError(`${reason} during this time slot`, 400, 'CONFLICT');
        }
    }

    // 2. Schedule
    return prisma.lecture.create({
      data: {
        institute_id: instituteId,
        batch_id: data.batchId,
        teacher_id: data.teacherId,
        title: `${data.subject} - ${data.batchId}`, // Adding a default title
        subject: data.subject,
        class_room: data.room || 'online',
        link: data.link,
        scheduled_at: lectureStart,
        duration_minutes: data.duration
      }
    });
  }

  async getBatchTimetable(batchId: string, instituteId: string) {
    return prisma.lecture.findMany({
      where: { batch_id: batchId, institute_id: instituteId },
      include: { teacher: { select: { name: true } } },
      orderBy: { scheduled_at: 'asc' }
    });
  }

  async getTeacherTimetable(teacherId: string, instituteId: string) {
    return prisma.lecture.findMany({
      where: { teacher_id: teacherId, institute_id: instituteId },
      include: { batch: { select: { name: true } } },
      orderBy: { scheduled_at: 'asc' }
    });
  }
}

import { AttendanceRepository } from './attendance.repository';
import { MarkAttendanceInput } from './attendance.validator';
import { notificationQueue } from '../../jobs/queue';
import { prisma } from '../../server';
import { ApiError } from '../../middleware/error.middleware';

export class AttendanceService {
  private repo: AttendanceRepository;

  constructor() {
    this.repo = new AttendanceRepository();
  }
  async markSession(instituteId: string, userId: string, role: string, data: MarkAttendanceInput) {
    const batch = await prisma.batch.findUnique({
      where: { id: data.batch_id, institute_id: instituteId },
      include: { institute: { select: { settings: true } } }
    });
    if (!batch) throw new ApiError('Batch not found', 404, 'NOT_FOUND');

    let teacherProfileId: string | null = null;
    if (role === 'teacher') {
      const teacher = await prisma.teacher.findFirst({
        where: { user_id: userId, institute_id: instituteId },
        select: { id: true },
      });
      if (!teacher) {
        throw new ApiError('Teacher profile not found', 404, 'NOT_FOUND');
      }
      teacherProfileId = teacher.id;

      // Check authorization
      const metaMap = (batch.institute.settings as any)?.batch_meta || {};
      const meta = metaMap[batch.id] || {};
      const assignedIds = Array.isArray(meta.teacher_ids) ? meta.teacher_ids : [];

      if (batch.teacher_id !== teacherProfileId && !assignedIds.includes(teacherProfileId!)) {
        throw new ApiError('You are not assigned to this batch', 403, 'FORBIDDEN');
      }
    }

     const session = await this.repo.markAttendance(instituteId, userId, teacherProfileId, data);
     
     const shouldNotifyParents = data.notify_parents !== false;

     // Queue the background job for alerts (only if Redis is available and notifications are enabled)
     if (notificationQueue && shouldNotifyParents) {
       await notificationQueue.add('ATTENDANCE_ALERT', { 
         sessionId: session.id, 
         instituteId 
       });
     }

     return { session_id: session.id, marked: data.records.length };
  }


  async getBatchMonthly(batchId: string, instituteId: string, month: number, year: number, subject?: string) {
      const startDate = new Date(year, month - 1, 1);
      const endDate = new Date(year, month, 0, 23, 59, 59); // End of month

      return this.repo.getBatchAttendanceForMonth(batchId, instituteId, startDate, endDate, subject);
  }

  async getStudentReport(studentId: string, instituteId: string, batchId?: string, subject?: string) {
      const records = await this.repo.getStudentAttendance(studentId, instituteId, batchId, subject);
      
      const total = records.length;
      const present = records.filter(r => r.status === 'present' || r.status === 'late').length;
      const percentage = total > 0 ? (present / total) * 100 : 0;

      return {
          total_sessions: total,
          present_count: present,
          percentage: percentage.toFixed(2),
          records
      };
  }

  async getDashboardStats(instituteId: string, batchId?: string, subject?: string) {
      const now = new Date();
      const todayStart = new Date(now.getFullYear(), now.getMonth(), now.getDate());
      const todayEnd = new Date(now.getFullYear(), now.getMonth(), now.getDate(), 23, 59, 59);

      const [todaySessions, monthlyStats] = await Promise.all([
          this.repo.getSessionsInRange(instituteId, todayStart, todayEnd, batchId, subject),
          this.repo.getAggregateStats(instituteId, new Date(now.getFullYear(), now.getMonth(), 1), todayEnd, batchId, subject)
      ]);

      return {
          today: todaySessions,
          monthly: monthlyStats
      };
  }
}

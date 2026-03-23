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
     }

     const session = await this.repo.markAttendance(instituteId, userId, teacherProfileId, data);
     
     // Queue the background job for alerts (only if Redis is available)
     if (notificationQueue) {
       await notificationQueue.add('ATTENDANCE_ALERT', { 
         sessionId: session.id, 
         instituteId 
       });
     }

     return { session_id: session.id, marked: data.records.length };
  }


  async getBatchMonthly(batchId: string, instituteId: string, month: number, year: number) {
      const startDate = new Date(year, month - 1, 1);
      const endDate = new Date(year, month, 0, 23, 59, 59); // End of month

      return this.repo.getBatchAttendanceForMonth(batchId, instituteId, startDate, endDate);
  }

  async getStudentReport(studentId: string, instituteId: string, batchId?: string) {
      const records = await this.repo.getStudentAttendance(studentId, instituteId, batchId);
      
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

  async getDashboardStats(instituteId: string, batchId?: string) {
      const now = new Date();
      const todayStart = new Date(now.getFullYear(), now.getMonth(), now.getDate());
      const todayEnd = new Date(now.getFullYear(), now.getMonth(), now.getDate(), 23, 59, 59);

      const [todaySessions, monthlyStats] = await Promise.all([
          this.repo.getSessionsInRange(instituteId, todayStart, todayEnd, batchId),
          this.repo.getAggregateStats(instituteId, new Date(now.getFullYear(), now.getMonth(), 1), todayEnd, batchId)
      ]);

      return {
          today: todaySessions,
          monthly: monthlyStats
      };
  }
}

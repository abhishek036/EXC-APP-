import { AttendanceRepository } from './attendance.repository';
import { MarkAttendanceInput } from './attendance.validator';
import { notificationQueue } from '../../jobs/queue';
import { prisma } from '../../server';
import { ApiError } from '../../middleware/error.middleware';
import { batchHasTeacher } from '../../utils/batch-teacher-assignment';
import { ATTENDANCE_PRESENT_STATUSES, normalizeStatus, summarizeAttendanceFromStatuses } from '../../utils/metrics';

export class AttendanceService {
  private repo: AttendanceRepository;

  constructor() {
    this.repo = new AttendanceRepository();
  }

  private buildWeeklyPercentages(
    rows: Array<{ status: string | null; session: { session_date: Date } | null }>,
    weekStart: Date,
  ): number[] {
    const totals = Array<number>(6).fill(0);
    const presentTotals = Array<number>(6).fill(0);
    const weekStartDate = new Date(weekStart.getFullYear(), weekStart.getMonth(), weekStart.getDate());

    for (const row of rows) {
      const sessionDateRaw = row.session?.session_date;
      if (!sessionDateRaw) continue;

      const sessionDate = new Date(sessionDateRaw);
      const sessionDay = new Date(sessionDate.getFullYear(), sessionDate.getMonth(), sessionDate.getDate());
      const dayOffset = Math.floor((sessionDay.getTime() - weekStartDate.getTime()) / (24 * 60 * 60 * 1000));

      if (dayOffset < 0 || dayOffset > 5) continue;

      totals[dayOffset] += 1;
      if (ATTENDANCE_PRESENT_STATUSES.has(normalizeStatus(row.status))) {
        presentTotals[dayOffset] += 1;
      }
    }

    return totals.map((total, idx) =>
      total > 0 ? Number(((presentTotals[idx] / total) * 100).toFixed(2)) : 0,
    );
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
        select: { id: true, user_id: true },
      });
      if (!teacher) {
        throw new ApiError('Teacher profile not found', 404, 'NOT_FOUND');
      }
      teacherProfileId = teacher.id;

      // Check authorization
      const metaMap = (batch.institute.settings as any)?.batch_meta || {};
      const meta = metaMap[batch.id] || {};
      const assigned = batchHasTeacher(meta, batch.teacher_id, [teacher.id, teacher.user_id]);

      if (!assigned) {
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
      const summary = summarizeAttendanceFromStatuses(records.map((record) => record.status));

      return {
        total_sessions: summary.total,
        present_count: summary.present,
        absent_count: summary.absent,
        late_count: summary.late,
        leave_count: summary.leave,
        percentage: summary.percentage,
        attendance_percentage: summary.percentage,
          records
      };
  }

  async getDashboardStats(instituteId: string, batchId?: string, subject?: string) {
      const now = new Date();
      const todayStart = new Date(now.getFullYear(), now.getMonth(), now.getDate());
      const todayEnd = new Date(now.getFullYear(), now.getMonth(), now.getDate(), 23, 59, 59);
      const weekStart = new Date(todayStart);
      weekStart.setDate(todayStart.getDate() - (todayStart.getDay() === 0 ? 6 : todayStart.getDay() - 1));

      const [todaySessions, monthlyStats, weeklyStats] = await Promise.all([
          this.repo.getSessionsInRange(instituteId, todayStart, todayEnd, batchId, subject),
        this.repo.getAggregateStats(instituteId, new Date(now.getFullYear(), now.getMonth(), 1), todayEnd, batchId, subject),
        this.repo.getAggregateStats(instituteId, weekStart, todayEnd, batchId, subject),
      ]);

      return {
          today: todaySessions,
        monthly: monthlyStats,
        weekly: this.buildWeeklyPercentages(weeklyStats, weekStart),
      };
  }
}

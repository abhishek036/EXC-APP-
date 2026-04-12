import { ParentRepository } from './parent.repository';
import { prisma } from '../../server';
import { ApiError } from '../../middleware/error.middleware';

export class ParentService {
  private parentRepo: ParentRepository;

  constructor() {
    this.parentRepo = new ParentRepository();
  }

  private async resolveParentContext(userId: string, instituteId: string) {
    const user = await prisma.user.findFirst({
      where: { id: userId, institute_id: instituteId },
      select: { phone: true },
    });

    const parent = await this.parentRepo.findParentByUserIdOrPhone(userId, instituteId, user?.phone);
    if (!parent) {
      return { parent: null, students: [] as any[] };
    }

    const students = await this.parentRepo.getParentStudents(instituteId, parent.id);
    return { parent, students };
  }

  private noLinkPayload(parent: any = null) {
    return {
      linked: false,
      message: 'No student linked to this account',
      action: 'Contact coaching',
      parent: parent ? { id: parent.id, name: parent.name, phone: parent.phone } : null,
      children: [],
      todaySchedule: [],
      upcomingExams: [],
      pendingFees: [],
      announcements: [],
    };
  }

  async getDashboardData(userId: string, instituteId: string) {
    const { parent, students } = await this.resolveParentContext(userId, instituteId);
    if (!parent || students.length === 0) {
      return this.noLinkPayload(parent);
    }

    const studentIds = students.map((s: any) => s.id);

    // Run aggregations for ALL children
    const [
      batches,
      attendanceStats,
      upcomingExams,
      pendingFees,
      announcements
    ] = await Promise.all([
      prisma.studentBatch.findMany({
        where: { student_id: { in: studentIds }, is_active: true },
        include: { batch: { include: { teacher: { select: { name: true } } } } }
      }),
      prisma.attendanceRecord.groupBy({
        by: ['student_id', 'status'],
        where: { student_id: { in: studentIds }, institute_id: instituteId },
        _count: { status: true }
      }),
      prisma.exam.findMany({
        where: { institute_id: instituteId, exam_date: { gte: new Date() } },
        orderBy: { exam_date: 'asc' },
        take: 5
      }),
      prisma.feeRecord.findMany({
        where: { student_id: { in: studentIds }, institute_id: instituteId, status: 'pending' },
        include: { student: { select: { name: true } } },
        orderBy: { due_date: 'asc' }
      }),
      prisma.announcement.findMany({
        where: { institute_id: instituteId },
        orderBy: { created_at: 'desc' },
        take: 3
      })
    ]);

    return {
      linked: true,
      parent: { id: parent.id, name: parent.name, phone: parent.phone },
      children: students.map((s: any) => ({
         id: s.id,
         name: s.name,
         attendance: this.calculateAttendance(attendanceStats, s.id),
         pendingFee: pendingFees.filter(f => f.student_id === s.id).reduce((sum, f) => sum + Number(f.final_amount), 0)
      })),
      todaySchedule: batches.map(sb => ({
         ...sb.batch,
         teacher_name: (sb.batch as any).teacher?.name,
         student_name: students.find((s: any) => s.id === sb.student_id)?.name
      })),
      upcomingExams: upcomingExams,
      pendingFees: pendingFees,
      announcements
    };
  }

  private calculateAttendance(stats: any[], studentId: string) {
    const studentStats = stats.filter(s => s.student_id === studentId);
    const total = studentStats.reduce((sum, s) => sum + s._count.status, 0);
    const present = studentStats.find(s => s.status === 'present')?._count.status || 0;
    return total > 0 ? Math.round((present / total) * 100) : 0;
  }

  async getParentStudents(userId: string, instituteId: string) {
    const { students } = await this.resolveParentContext(userId, instituteId);
    return students;
  }

  async getMyChildren(userId: string, instituteId: string) {
    return this.getParentStudents(userId, instituteId);
  }

  async getPaymentHistory(userId: string, instituteId: string) {
    const students = await this.getParentStudents(userId, instituteId);
    const studentIds = students.map((s: any) => s.id);
    if (!studentIds.length) return [];

    return prisma.feeRecord.findMany({
      where: { student_id: { in: studentIds }, institute_id: instituteId },
      include: { 
         student: { select: { name: true } },
         batch: { select: { name: true } }
      },
      orderBy: { created_at: 'desc' }
    });
  }

  async getChildReport(userId: string, childId: string, instituteId: string) {
    const { parent } = await this.resolveParentContext(userId, instituteId);
    if (!parent) {
      throw new ApiError('Parent profile not found', 404, 'NOT_FOUND');
    }

    const relation = await prisma.parentStudent.findFirst({
      where: {
        parent_id: parent.id,
        student_id: childId,
      },
      select: { id: true },
    });

    if (!relation) {
       throw new ApiError('Unauthorized or child not found', 403, 'FORBIDDEN');
    }

    const [attendance, results] = await Promise.all([
       prisma.attendanceRecord.groupBy({
          by: ['status'],
          where: { student_id: childId, institute_id: instituteId },
          _count: { status: true }
       }),
       prisma.examResult.findMany({
          where: { student_id: childId, institute_id: instituteId },
          include: { exam: true },
          orderBy: { exam: { exam_date: 'desc' } },
          take: 5
       })
    ]);

    return { attendance, results };
  }
}

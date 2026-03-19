import { ParentRepository } from './parent.repository';
import { prisma } from '../../server';

export class ParentService {
  private parentRepo: ParentRepository;

  constructor() {
    this.parentRepo = new ParentRepository();
  }

  async getDashboardData(userId: string, instituteId: string) {
    const parent = await this.parentRepo.findParentByUserId(userId, instituteId);
    if (!parent) return null;

    const students = (parent as any).parent_students.map((ps: any) => ps.student);
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

  async getMyChildren(userId: string, instituteId: string) {
    return this.parentRepo.getChildren(userId, instituteId);
  }

  async getPaymentHistory(userId: string, instituteId: string) {
    const students = await this.parentRepo.getChildren(userId, instituteId);
    const studentIds = students.map((s: any) => s.id);
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
    // Verify child belongs to parent
    const parent = await prisma.parent.findFirst({
       where: { user_id: userId, institute_id: instituteId },
       include: { parent_students: { where: { student_id: childId } } }
    });
    if (!parent || parent.parent_students.length === 0) {
       throw new Error('Unauthorized or child not found');
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

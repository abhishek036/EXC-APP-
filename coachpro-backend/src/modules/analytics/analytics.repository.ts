import { Prisma } from '@prisma/client';
import { prisma } from '../../server';

export class AnalyticsRepository {
  static async getDashboardStats(instituteId: string) {
    const studentCount = await prisma.student.count({ where: { institute_id: instituteId, is_active: true } });
    const teacherCount = await prisma.teacher.count({ where: { institute_id: instituteId, is_active: true } });
    const batchCount = await prisma.batch.count({ where: { institute_id: instituteId, is_active: true } });
    
    // Revenue logic (current month)
    const currentMonth = new Date().getMonth() + 1;
    const currentYear = new Date().getFullYear();
    
    const revenueResult = await prisma.feePayment.aggregate({
      where: {
        institute_id: instituteId,
        paid_at: {
          gte: new Date(currentYear, currentMonth - 1, 1),
          lt: new Date(currentYear, currentMonth, 1),
        }
      },
      _sum: {
        amount_paid: true
      }
    });
    
    return {
      total_students: studentCount,
      total_teachers: teacherCount,
      total_batches: batchCount,
      monthly_revenue: revenueResult._sum.amount_paid || 0,
    };
  }

  static async getStudentPerformance(studentId: string, instituteId: string) {
    const exams = await prisma.examResult.findMany({
      where: { student_id: studentId, institute_id: instituteId },
      include: { exam: { select: { title: true, total_marks: true, exam_date: true } } },
      orderBy: { exam: { exam_date: 'desc' } },
      take: 10
    });

    const attendance = await prisma.attendanceRecord.findMany({
      where: { student_id: studentId, institute_id: instituteId },
      include: { session: { select: { session_date: true } } },
      orderBy: { session: { session_date: 'desc' } },
    });

    return {
      exams,
      attendance,
    };
  }
}

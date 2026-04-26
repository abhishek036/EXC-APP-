import { prisma } from '../../config/prisma';

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

  static async getAdminReports(instituteId: string) {
    const studentCount = await prisma.student.count({ where: { institute_id: instituteId } });
    const activeStudentCount = await prisma.student.count({ where: { institute_id: instituteId, is_active: true } });
    const teacherCount = await prisma.teacher.count({ where: { institute_id: instituteId, is_active: true } });
    const batchCount = await prisma.batch.count({ where: { institute_id: instituteId, is_active: true } });

    // Fee logic
    const fees = await prisma.feeRecord.findMany({
      where: { institute_id: instituteId },
      include: { payments: true }
    });

    let collectedRevenue = 0;
    let pendingRevenue = 0;
    for (const f of fees) {
      const paid = f.payments.reduce((sum, p) => sum + Number(p.amount_paid), 0);
      collectedRevenue += paid;
      const rem = Math.max(0, Number(f.final_amount) - paid);
      pendingRevenue += rem;
    }

    return {
      overview: {
        totalStudents: studentCount,
        activeStudents: activeStudentCount,
        totalTeachers: teacherCount,
        activeBatches: batchCount
      },
      revenue: {
        collected: collectedRevenue,
        pending: pendingRevenue
      },
      // Note: Charting data will be simple arrays for UI consumption
      revenueTrend: [120, 180, 240, 200, 250, 310], // Mocked array for trend
      enrollmentTrend: [10, 15, 25, 40, 50, 60]
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

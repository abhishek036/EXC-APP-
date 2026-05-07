import { prisma } from '../../config/prisma';
import { Cache, TTL } from '../../utils/cache';

export class AnalyticsRepository {
  static async getDashboardStats(instituteId: string) {
    return Cache.getOrSet(
      Cache.key(instituteId, 'dashboard'),
      TTL.DASHBOARD_STATS,
      async () => {
        // Use $transaction to batch all count queries into 1 round trip to Neon
        const [studentCount, teacherCount, batchCount, revenueResult] = await prisma.$transaction([
          prisma.student.count({ where: { institute_id: instituteId, is_active: true } }),
          prisma.teacher.count({ where: { institute_id: instituteId, is_active: true } }),
          prisma.batch.count({ where: { institute_id: instituteId, is_active: true } }),
          prisma.feePayment.aggregate({
            where: {
              institute_id: instituteId,
              paid_at: {
                gte: new Date(new Date().getFullYear(), new Date().getMonth(), 1),
                lt: new Date(new Date().getFullYear(), new Date().getMonth() + 1, 1),
              },
            },
            _sum: { amount_paid: true },
          }),
        ]);

        return {
          total_students: studentCount,
          total_teachers: teacherCount,
          total_batches: batchCount,
          monthly_revenue: revenueResult._sum.amount_paid || 0,
        };
      },
    );
  }

  static async getAdminReports(instituteId: string) {
    return Cache.getOrSet(
      Cache.key(instituteId, 'admin_reports'),
      TTL.FEE_SUMMARY,
      async () => {
        // Batch all count queries in a single transaction (1 round trip)
        const [studentCount, activeStudentCount, teacherCount, batchCount] = await prisma.$transaction([
          prisma.student.count({ where: { institute_id: instituteId } }),
          prisma.student.count({ where: { institute_id: instituteId, is_active: true } }),
          prisma.teacher.count({ where: { institute_id: instituteId, is_active: true } }),
          prisma.batch.count({ where: { institute_id: instituteId, is_active: true } }),
        ]);

        // ✅ Use aggregate instead of loading ALL fee records into RAM
        const [collectedAgg, totalAgg] = await prisma.$transaction([
          prisma.feePayment.aggregate({
            where: { institute_id: instituteId },
            _sum: { amount_paid: true },
          }),
          prisma.feeRecord.aggregate({
            where: { institute_id: instituteId },
            _sum: { final_amount: true },
          }),
        ]);

        const collectedRevenue = Number(collectedAgg._sum.amount_paid ?? 0);
        const totalRevenue = Number(totalAgg._sum.final_amount ?? 0);
        const pendingRevenue = Math.max(0, totalRevenue - collectedRevenue);

        return {
          overview: {
            totalStudents: studentCount,
            activeStudents: activeStudentCount,
            totalTeachers: teacherCount,
            activeBatches: batchCount,
          },
          revenue: {
            collected: collectedRevenue,
            pending: pendingRevenue,
          },
          revenueTrend: [120, 180, 240, 200, 250, 310],
          enrollmentTrend: [10, 15, 25, 40, 50, 60],
        };
      },
    );
  }

  static async getStudentPerformance(studentId: string, instituteId: string) {
    return Cache.getOrSet(
      Cache.key(instituteId, 'student_perf', studentId),
      TTL.STUDENT_PERFORMANCE,
      async () => {
        const [exams, attendance] = await prisma.$transaction([
          prisma.examResult.findMany({
            where: { student_id: studentId, institute_id: instituteId },
            include: { exam: { select: { title: true, total_marks: true, exam_date: true } } },
            orderBy: { exam: { exam_date: 'desc' } },
            take: 10,
          }),
          prisma.attendanceRecord.findMany({
            where: { student_id: studentId, institute_id: instituteId },
            include: { session: { select: { session_date: true } } },
            orderBy: { session: { session_date: 'desc' } },
            take: 90, // last ~3 months of daily attendance, not unlimited
          }),
        ]);

        return { exams, attendance };
      },
    );
  }
}

import { prisma } from '../../config/prisma';
import { ApiError } from '../../middleware/error.middleware';

export class PayrollService {
  /**
   * Generates a monthly payroll record for a staff member.
   * Calculates teacher bonus based on number of lectures delivered.
   */
  async generateMonthlyPayroll(instituteId: string, staffId: string, month: number, year: number) {
    const staff = await prisma.staff.findUnique({
      where: { id: staffId, institute_id: instituteId }
    });
    if (!staff) throw new ApiError('Staff not found', 404, 'NOT_FOUND');

    // Calculate time range
    const startDate = new Date(year, month - 1, 1);
    const endDate = new Date(year, month, 0, 23, 59, 59);

    let totalAmount = Number(staff.salary || 0);
    
    // If they are a teacher, we might want to add performance bonuses
    // Let's check for a teacher record with the same phone or link if available
    const teacher = await prisma.teacher.findFirst({
      where: { institute_id: instituteId, phone: staff.phone }
    });

    if (teacher) {
        // Example: 500 INR bonus per lecture delivered
        const lectureCount = await prisma.lecture.count({
            where: {
                teacher_id: teacher.id,
                institute_id: instituteId,
                created_at: { gte: startDate, lte: endDate }
            }
        });
        
        const bonusPerLecture = 500; // This should ideally be a setting
        totalAmount += (lectureCount * bonusPerLecture);
    }

    const monthName = new Intl.DateTimeFormat('en-US', { month: 'long' }).format(startDate);

    // Create or update record
    const record = await prisma.payrollRecord.upsert({
      where: { 
         // Custom unique logic would be better, but schema @unique is missing in models
         // for now we'll just create a new one or find existing by manual check
         id: 'temporary_id_logic' // Placeholder
      },
      update: {
          amount: totalAmount,
          month: `${monthName} ${year}`
      },
      create: {
          institute_id: instituteId,
          staff_id: staffId,
          amount: totalAmount,
          type: 'Monthly Salary',
          month: `${monthName} ${year}`
      }
    } as any);

    return record;
  }

  async listPayroll(instituteId: string, query: { month?: string, staffId?: string }) {
    return prisma.payrollRecord.findMany({
      where: {
        institute_id: instituteId,
        ...(query.month && { month: { contains: query.month } }),
        ...(query.staffId && { staff_id: query.staffId })
      },
      include: { staff: { select: { name: true, role: true } } },
      orderBy: { date: 'desc' }
    });
  }

  async getDashboardStats(instituteId: string) {
    const now = new Date();
    const currentMonth = new Intl.DateTimeFormat('en-US', { month: 'long' }).format(now);
    const year = now.getFullYear();
    const monthStr = `${currentMonth} ${year}`;

    const totalExpense = await prisma.payrollRecord.aggregate({
        where: { institute_id: instituteId, month: monthStr },
        _sum: { amount: true }
    });

    return {
        current_month: monthStr,
        total_payroll: totalExpense._sum.amount || 0,
        pending_staff_count: 0 // Logic to find staff without records this month
    };
  }
}

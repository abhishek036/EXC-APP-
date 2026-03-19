import { prisma } from '../../server';
import { CreatePayrollInput, CreateStaffInput } from './staff.validator';

export class StaffRepository {
  async listStaff(instituteId: string) {
    return prisma.staff.findMany({
      where: { institute_id: instituteId },
      orderBy: { created_at: 'desc' },
      take: 200,
    });
  }

  async createStaff(instituteId: string, data: CreateStaffInput) {
    return prisma.staff.create({
      data: {
        institute_id: instituteId,
        name: data.name,
        role: data.role,
        phone: data.phone,
        salary: data.salary,
        status: data.status ?? 'active',
      },
    });
  }

  async listPayroll(instituteId: string) {
    return prisma.payrollRecord.findMany({
      where: { institute_id: instituteId },
      include: {
        staff: { select: { id: true, name: true } },
      },
      orderBy: { date: 'desc' },
      take: 200,
    });
  }

  async createPayroll(instituteId: string, data: CreatePayrollInput) {
    return prisma.payrollRecord.create({
      data: {
        institute_id: instituteId,
        staff_id: data.staffId,
        amount: data.amount,
        type: data.type,
        month: data.month,
        date: data.date ? new Date(data.date) : new Date(),
      },
      include: {
        staff: { select: { id: true, name: true } },
      },
    });
  }
}

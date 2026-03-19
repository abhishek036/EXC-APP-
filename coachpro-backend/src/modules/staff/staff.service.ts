import { CreatePayrollInput, CreateStaffInput } from './staff.validator';
import { StaffRepository } from './staff.repository';

export class StaffService {
  private repo: StaffRepository;

  constructor() {
    this.repo = new StaffRepository();
  }

  async listStaff(instituteId: string) {
    return this.repo.listStaff(instituteId);
  }

  async createStaff(instituteId: string, data: CreateStaffInput) {
    return this.repo.createStaff(instituteId, data);
  }

  async listPayroll(instituteId: string) {
    const records = await this.repo.listPayroll(instituteId);
    return records.map((record) => ({
      id: record.id,
      staffId: record.staff_id,
      staffName: record.staff.name,
      amount: Number(record.amount),
      type: record.type,
      month: record.month,
      date: record.date,
    }));
  }

  async createPayroll(instituteId: string, data: CreatePayrollInput) {
    const row = await this.repo.createPayroll(instituteId, data);
    return {
      id: row.id,
      staffId: row.staff_id,
      staffName: row.staff.name,
      amount: Number(row.amount),
      type: row.type,
      month: row.month,
      date: row.date,
    };
  }
}

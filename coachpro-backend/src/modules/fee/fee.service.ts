import { FeeRepository } from './fee.repository';
import { DefineFeeStructureInput, RecordFeePaymentInput, GenerateMonthlyFeesInput } from './fee.validator';
import { ApiError } from '../../middleware/error.middleware';

export class FeeService {
  private repo: FeeRepository;

  constructor() {
    this.repo = new FeeRepository();
  }

  async defineStructure(instituteId: string, data: DefineFeeStructureInput) {
    return this.repo.setFeeStructure(instituteId, data);
  }

  async getBatchFeeStructure(batchId: string, instituteId: string) {
    const struct = await this.repo.getFeeStructure(batchId, instituteId);
    if (!struct) throw new ApiError('Fee structure not found', 404, 'NOT_FOUND');
    return struct;
  }

  async generateMonthly(instituteId: string, data: GenerateMonthlyFeesInput) {
    const struct = await this.repo.getFeeStructure(data.batch_id, instituteId);
    if (!struct) {
        throw new ApiError('First define a fee structure for this batch', 400, 'NO_STRUCTURE');
    }

    const defaultDueDate = new Date(data.year, data.month - 1, struct.late_after_day || 10);
    const { generated } = await this.repo.createMonthlyFeeRecords(instituteId, data, defaultDueDate);
    return { generated };
  }

  async getFeeRecords(instituteId: string, reqQuery: any) {
    const month = reqQuery.month ? parseInt(reqQuery.month) : undefined;
    const year = reqQuery.year ? parseInt(reqQuery.year) : undefined;
    return this.repo.findFeeRecords(instituteId, reqQuery.batchId, reqQuery.studentId, month, year);
  }

  async recordPayment(instituteId: string, userId: string, data: RecordFeePaymentInput) {
    return this.repo.recordPayment(instituteId, userId, data);
  }
}

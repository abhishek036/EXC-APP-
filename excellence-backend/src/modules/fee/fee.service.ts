import { FeeRepository } from './fee.repository';
import {
  DefineFeeStructureInput,
  RecordFeePaymentInput,
  GenerateMonthlyFeesInput,
  SubmitFeeProofInput,
  ReviewFeePaymentInput,
  AdjustFeeRecordInput,
} from './fee.validator';
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

  async getFeeRecords(instituteId: string, reqQuery: any, role?: string) {
    const month = reqQuery.month ? parseInt(reqQuery.month) : undefined;
    const year = reqQuery.year ? parseInt(reqQuery.year) : undefined;
    const statusRaw = (reqQuery.status ?? '').toString().trim().toLowerCase();
    const status = statusRaw === 'pending' ? 'pending_verification' : statusRaw || undefined;

    return this.repo.findFeeRecordsByRole(
      instituteId,
      {
        batchId: reqQuery.batchId,
        studentId: reqQuery.studentId,
        month,
        year,
        status,
      },
      role,
    );
  }

  async recordPayment(instituteId: string, userId: string, data: RecordFeePaymentInput) {
    return this.repo.recordPayment(instituteId, userId, data);
  }

  async submitPaymentProof(
    instituteId: string,
    userId: string,
    data: SubmitFeeProofInput,
    role?: string,
  ) {
    return this.repo.submitPaymentProof(instituteId, userId, data, role);
  }

  async getStudentPaymentHistory(instituteId: string, userId: string, role?: string) {
    return this.repo.listStudentPayments(instituteId, userId, role);
  }

  async getPaymentsForReview(
    instituteId: string,
    query: { status?: string; batchId?: string; studentId?: string },
    role?: string,
  ) {
    return this.repo.listPaymentsForReview(instituteId, query, role);
  }

  async approvePaymentProof(
    instituteId: string,
    paymentId: string,
    reviewerUserId: string,
    review: ReviewFeePaymentInput,
  ) {
    return this.repo.approvePaymentProof(instituteId, paymentId, reviewerUserId, review.note);
  }

  async rejectPaymentProof(
    instituteId: string,
    paymentId: string,
    reviewerUserId: string,
    review: ReviewFeePaymentInput,
  ) {
    if (!review.rejection_reason || !review.rejection_reason.trim()) {
      throw new ApiError('rejection_reason is required', 400, 'MISSING_REJECTION_REASON');
    }
    return this.repo.rejectPaymentProof(
      instituteId,
      paymentId,
      reviewerUserId,
      review.rejection_reason,
      review.note,
    );
  }

  async adjustFeeRecord(instituteId: string, actorUserId: string, data: AdjustFeeRecordInput) {
    return this.repo.adjustFeeRecord(instituteId, actorUserId, data);
  }
}

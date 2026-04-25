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
import { NotificationService } from '../notification/notification.service';

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

  async sendReminder(instituteId: string, recordId: string) {
    const record = await this.repo.findFeeRecordWithUsers(recordId, instituteId);
    if (!record) throw new ApiError('Fee record not found', 404, 'NOT_FOUND');
    if (record.status === 'paid') throw new ApiError('Fee is already paid', 400, 'ALREADY_PAID');

    const monthNames = ["", "January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"];
    const monthStr = monthNames[record.month] || record.month.toString();
    const batchName = record.batch.name;
    const amount = Number(record.final_amount);
    const paid = Number(record.paid_amount);
    const pending = amount - paid;

    const title = 'Fee Payment Reminder';
    const body = `Reminder: Fee of ₹${pending} is pending for ${monthStr} (${batchName}). Please ignore if already paid.`;
    
    const targetUserIds: string[] = [];
    if (record.student.user?.id) targetUserIds.push(record.student.user.id);
    
    record.student.parent_students.forEach(ps => {
        if (ps.parent.user?.id) targetUserIds.push(ps.parent.user.id);
    });

    if (targetUserIds.length === 0) {
        throw new ApiError('No associated users found for notification', 404, 'USERS_NOT_FOUND');
    }

    const payload = {
        title,
        body,
        type: 'fee_reminder',
        institute_id: instituteId,
        meta: {
            fee_record_id: record.id,
            batch_id: record.batch_id,
            month: record.month,
            year: record.year
        }
    };

    let delivered = 0;
    for(const userId of targetUserIds) {
        try {
            await NotificationService.sendNotificationToUser(userId, payload);
            delivered++;
        } catch (e) {
            // Log and continue
            console.error(`Failed to send fee reminder to user ${userId}:`, e);
        }
    }

    return { success: true, deliveredCount: delivered };
  }
}

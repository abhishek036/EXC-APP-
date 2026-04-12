import { Request, Response, NextFunction } from 'express';
import { FeeService } from './fee.service';
import { sendResponse } from '../../utils/response';
import { emitBatchSync, emitInstituteDashboardSync } from '../../config/socket';

export class FeeController {
  private service: FeeService;

  constructor() {
    this.service = new FeeService();
  }

  defineStructure = async (req: Request, res: Response, next: NextFunction) => {
    try {
      const data = await this.service.defineStructure(req.instituteId!, req.body);
      return sendResponse({ res, data, message: 'Fee structure defined' });
    } catch (e) { next(e); }
  }

  getStructure = async (req: Request, res: Response, next: NextFunction) => {
    try {
      const data = await this.service.getBatchFeeStructure(req.params.batchId, req.instituteId!);
      return sendResponse({ res, data, message: 'Fee structure fetched' });
    } catch (e) { next(e); }
  }

  generateMonthly = async (req: Request, res: Response, next: NextFunction) => {
    try {
      const data = await this.service.generateMonthly(req.instituteId!, req.body);
      return sendResponse({ res, data, message: `Successfully generated ${data.generated} fee records` });
    } catch (e) { next(e); }
  }

  getRecords = async (req: Request, res: Response, next: NextFunction) => {
    try {
      const data = await this.service.getFeeRecords(req.instituteId!, req.query, req.user?.role);
      return sendResponse({ res, data, message: 'Fee records fetched' });
    } catch (e) { next(e); }
  }

  recordPayment = async (req: Request, res: Response, next: NextFunction) => {
    try {
      // requires user token to have userId for collected_by mapping
      const data = await this.service.recordPayment(req.instituteId!, req.user!.userId, req.body);
      const batchId = (data as any)?.batch_id;
      if (batchId) {
        emitBatchSync(req.instituteId!, batchId, 'fee_payment_recorded', {
          fee_record_id: (data as any)?.fee_record_id,
          payment_id: (data as any)?.id,
        });
      } else {
        emitInstituteDashboardSync(req.instituteId!, 'fee_payment_recorded');
      }
      return sendResponse({ res, data, message: 'Payment recorded successfully' });
    } catch (e) { next(e); }
  }

  submitPaymentProof = async (req: Request, res: Response, next: NextFunction) => {
    try {
      const data = await this.service.submitPaymentProof(
        req.instituteId!,
        req.user!.userId,
        req.body,
        req.user?.role,
      );
      const payment = (data as any)?.payment;
      const batchId = payment?.batch_id;
      if (batchId) {
        emitBatchSync(req.instituteId!, batchId, 'fee_payment_proof_submitted', {
          fee_record_id: payment?.fee_record_id,
          payment_id: payment?.id,
        });
      } else {
        emitInstituteDashboardSync(req.instituteId!, 'fee_payment_proof_submitted');
      }
      return sendResponse({ res, data, statusCode: 201, message: 'Payment proof submitted for verification' });
    } catch (e) { next(e); }
  }

  getMyPaymentProofs = async (req: Request, res: Response, next: NextFunction) => {
    try {
      const data = await this.service.getStudentPaymentHistory(
        req.instituteId!,
        req.user!.userId,
        req.user?.role,
      );
      return sendResponse({ res, data, message: 'Payment proof history fetched' });
    } catch (e) { next(e); }
  }

  getPaymentsForReview = async (req: Request, res: Response, next: NextFunction) => {
    try {
      const data = await this.service.getPaymentsForReview(
        req.instituteId!,
        {
          status: req.query.status as string | undefined,
          batchId: req.query.batchId as string | undefined,
          studentId: req.query.studentId as string | undefined,
        },
        req.user?.role,
      );
      return sendResponse({ res, data, message: 'Payment verification queue fetched' });
    } catch (e) { next(e); }
  }

  approvePaymentProof = async (req: Request, res: Response, next: NextFunction) => {
    try {
      const data = await this.service.approvePaymentProof(
        req.instituteId!,
        req.params.paymentId,
        req.user!.userId,
        req.body,
      );
      const payment = (data as any)?.payment;
      const batchId = payment?.batch_id;
      if (batchId) {
        emitBatchSync(req.instituteId!, batchId, 'fee_payment_proof_approved', {
          fee_record_id: payment?.fee_record_id,
          payment_id: payment?.id,
        });
      } else {
        emitInstituteDashboardSync(req.instituteId!, 'fee_payment_proof_approved');
      }
      return sendResponse({ res, data, message: 'Payment proof approved' });
    } catch (e) { next(e); }
  }

  rejectPaymentProof = async (req: Request, res: Response, next: NextFunction) => {
    try {
      const data = await this.service.rejectPaymentProof(
        req.instituteId!,
        req.params.paymentId,
        req.user!.userId,
        req.body,
      );
      const payment = (data as any)?.payment;
      const batchId = payment?.batch_id;
      if (batchId) {
        emitBatchSync(req.instituteId!, batchId, 'fee_payment_proof_rejected', {
          fee_record_id: payment?.fee_record_id,
          payment_id: payment?.id,
        });
      } else {
        emitInstituteDashboardSync(req.instituteId!, 'fee_payment_proof_rejected');
      }
      return sendResponse({ res, data, message: 'Payment proof rejected' });
    } catch (e) { next(e); }
  }

  adjustFeeRecord = async (req: Request, res: Response, next: NextFunction) => {
    try {
      const data = await this.service.adjustFeeRecord(req.instituteId!, req.user!.userId, req.body);
      const record = (data as any)?.fee_record;
      const batchId = record?.batch_id;
      if (batchId) {
        emitBatchSync(req.instituteId!, batchId, 'fee_record_adjusted', {
          fee_record_id: record?.id,
        });
      } else {
        emitInstituteDashboardSync(req.instituteId!, 'fee_record_adjusted');
      }
      return sendResponse({ res, data, message: 'Fee adjustment applied successfully' });
    } catch (e) { next(e); }
  }
}

import { Request, Response, NextFunction } from 'express';
import { FeeService } from './fee.service';
import { sendResponse } from '../../utils/response';

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
      const data = await this.service.getFeeRecords(req.instituteId!, req.query);
      return sendResponse({ res, data, message: 'Fee records fetched' });
    } catch (e) { next(e); }
  }

  recordPayment = async (req: Request, res: Response, next: NextFunction) => {
    try {
      // requires user token to have userId for collected_by mapping
      const data = await this.service.recordPayment(req.instituteId!, req.user!.userId, req.body);
      return sendResponse({ res, data, message: 'Payment recorded successfully' });
    } catch (e) { next(e); }
  }
}

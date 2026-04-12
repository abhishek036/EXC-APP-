import { Request, Response, NextFunction } from 'express';
import { ParentService } from './parent.service';
import { sendResponse } from '../../utils/response';

export class ParentController {
  private parentService: ParentService;

  constructor() {
    this.parentService = new ParentService();
  }

  getDashboard = async (req: Request, res: Response, next: NextFunction) => {
    try {
      const data = await this.parentService.getDashboardData(req.user!.userId, req.instituteId!);
      return sendResponse({ res, data, message: 'Parent dashboard fetched' });
    } catch (error) { next(error); }
  };

  getChildren = async (req: Request, res: Response, next: NextFunction) => {
    try {
       const data = await this.parentService.getMyChildren(req.user!.userId, req.instituteId!);
       return sendResponse({ res, data, message: 'Children fetched' });
    } catch (error) { next(error); }
  };

  getPayments = async (req: Request, res: Response, next: NextFunction) => {
    try {
       const data = await this.parentService.getPaymentHistory(req.user!.userId, req.instituteId!);
       return sendResponse({ res, data, message: 'Payments fetched' });
    } catch (error) { next(error); }
  };

  getChildReport = async (req: Request, res: Response, next: NextFunction) => {
    try {
       const data = await this.parentService.getChildReport(req.user!.userId, req.params.childId, req.instituteId!);
       return sendResponse({ res, data, message: 'Report fetched' });
    } catch (error) { next(error); }
  };
}

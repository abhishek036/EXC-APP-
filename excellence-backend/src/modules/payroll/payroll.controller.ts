import { Request, Response, NextFunction } from 'express';
import { PayrollService } from './payroll.service';
import { sendResponse } from '../../utils/response';

export class PayrollController {
  private service: PayrollService;

  constructor() {
    this.service = new PayrollService();
  }

  generate = async (req: Request, res: Response, next: NextFunction) => {
    try {
      const { staffId, month, year } = req.body;
      const data = await this.service.generateMonthlyPayroll(req.instituteId!, staffId, Number(month), Number(year));
      return sendResponse({ res, data, message: 'Payroll generated successfully' });
    } catch (error) { next(error); }
  };

  list = async (req: Request, res: Response, next: NextFunction) => {
    try {
      const { month, staffId } = req.query;
      const data = await this.service.listPayroll(req.instituteId!, { month: month as string, staffId: staffId as string });
      return sendResponse({ res, data, message: 'Payroll records fetched' });
    } catch (error) { next(error); }
  };

  stats = async (req: Request, res: Response, next: NextFunction) => {
    try {
      const data = await this.service.getDashboardStats(req.instituteId!);
      return sendResponse({ res, data, message: 'Payroll stats fetched' });
    } catch (error) { next(error); }
  };
}

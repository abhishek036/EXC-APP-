import { Request, Response, NextFunction } from 'express';
import { sendResponse } from '../../utils/response';
import { StaffService } from './staff.service';

export class StaffController {
  private service: StaffService;

  constructor() {
    this.service = new StaffService();
  }

  listStaff = async (req: Request, res: Response, next: NextFunction) => {
    try {
      const data = await this.service.listStaff(req.instituteId!);
      return sendResponse({ res, data, message: 'Staff fetched successfully' });
    } catch (error) {
      next(error);
    }
  };

  createStaff = async (req: Request, res: Response, next: NextFunction) => {
    try {
      const data = await this.service.createStaff(req.instituteId!, req.body);
      return sendResponse({ res, data, statusCode: 201, message: 'Staff created successfully' });
    } catch (error) {
      next(error);
    }
  };

  listPayroll = async (req: Request, res: Response, next: NextFunction) => {
    try {
      const data = await this.service.listPayroll(req.instituteId!);
      return sendResponse({ res, data, message: 'Payroll records fetched successfully' });
    } catch (error) {
      next(error);
    }
  };

  createPayroll = async (req: Request, res: Response, next: NextFunction) => {
    try {
      const data = await this.service.createPayroll(req.instituteId!, req.body);
      return sendResponse({ res, data, statusCode: 201, message: 'Payroll created successfully' });
    } catch (error) {
      next(error);
    }
  };
}

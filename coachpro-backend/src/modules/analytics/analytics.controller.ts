import { Request, Response, NextFunction } from 'express';
import { AnalyticsService } from './analytics.service';
import { sendResponse } from '../../utils/response';

export class AnalyticsController {
  static async getDashboard(req: Request, res: Response, next: NextFunction) {
    try {
      const stats = await AnalyticsService.getDashboard(req.instituteId!);
      return sendResponse({ res, data: stats });
    } catch (error) {
      next(error);
    }
  }

  static async getStudentPerformance(req: Request, res: Response, next: NextFunction) {
    try {
      const { id } = req.params;
      const performance = await AnalyticsService.getStudentPerformance(id, req.instituteId!);
      return sendResponse({ res, data: performance });
    } catch (error) {
      next(error);
    }
  }
}

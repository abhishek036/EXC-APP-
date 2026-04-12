import { Request, Response, NextFunction } from 'express';
import { DoubtService } from './doubt.service';
import { sendResponse } from '../../utils/response';

export class DoubtController {
  static async listDoubts(req: Request, res: Response, next: NextFunction) {
    try {
      const status = typeof req.query.status === 'string' ? req.query.status : undefined;
      const doubts = await DoubtService.listDoubts(req.user!.userId, req.instituteId!, req.user!.role, status);
      return sendResponse({ res, data: doubts });
    } catch (error) {
      next(error);
    }
  }

  static async createDoubt(req: Request, res: Response, next: NextFunction) {
    try {
      const doubt = await DoubtService.askDoubt(
        req.instituteId!,
        req.user!.userId,
        req.body
      );
      return sendResponse({ res, data: doubt, message: 'Doubt asked successfully', statusCode: 201 });
    } catch (error) {
      next(error);
    }
  }

  static async answerDoubt(req: Request, res: Response, next: NextFunction) {
    try {
      await DoubtService.answerDoubt(req.params.id, req.instituteId!, req.user!.userId, req.body);
      return sendResponse({ res, data: null, message: 'Doubt answered successfully' });
    } catch (error) {
      next(error);
    }
  }

  static async followUpDoubt(req: Request, res: Response, next: NextFunction) {
    try {
      const data = await DoubtService.studentFollowUp(
        req.params.id,
        req.instituteId!,
        req.user!.userId,
        req.body,
      );
      return sendResponse({ res, data, message: 'Doubt follow-up submitted successfully' });
    } catch (error) {
      next(error);
    }
  }

  static async resolveDoubt(req: Request, res: Response, next: NextFunction) {
    try {
      await DoubtService.resolveDoubt(req.params.id, req.instituteId!);
      return sendResponse({ res, data: null, message: 'Doubt marked as resolved' });
    } catch (error) {
      next(error);
    }
  }
}

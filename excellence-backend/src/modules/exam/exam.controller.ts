import { Request, Response, NextFunction } from 'express';
import { sendResponse } from '../../utils/response';
import { ExamService } from './exam.service';

export class ExamController {
  private service: ExamService;

  constructor() {
    this.service = new ExamService();
  }

  list = async (req: Request, res: Response, next: NextFunction) => {
    try {
      const data = await this.service.list(
        req.instituteId!,
        req.query.status as string | undefined,
        { role: req.user?.role, userId: req.user?.userId },
      );
      return sendResponse({ res, data, message: 'Exams fetched successfully' });
    } catch (error) {
      next(error);
    }
  };

  create = async (req: Request, res: Response, next: NextFunction) => {
    try {
      const data = await this.service.create(req.instituteId!, req.user!.userId, req.body);
      return sendResponse({ res, data, statusCode: 201, message: 'Exam created successfully' });
    } catch (error) {
      next(error);
    }
  };

  updateStatus = async (req: Request, res: Response, next: NextFunction) => {
    try {
      const data = await this.service.setStatus(req.instituteId!, req.params.id, req.body.status);
      return sendResponse({ res, data, message: 'Exam status updated successfully' });
    } catch (error) {
      next(error);
    }
  };

  remove = async (req: Request, res: Response, next: NextFunction) => {
    try {
      const data = await this.service.remove(req.instituteId!, req.params.id);
      return sendResponse({ res, data, message: 'Exam deleted successfully' });
    } catch (error) {
      next(error);
    }
  };

  results = async (req: Request, res: Response, next: NextFunction) => {
    try {
      const data = await this.service.listResults(req.instituteId!, {
        role: req.user?.role,
        userId: req.user?.userId,
      });
      return sendResponse({ res, data, message: 'Exam results fetched successfully' });
    } catch (error) {
      next(error);
    }
  };

  saveResult = async (req: Request, res: Response, next: NextFunction) => {
    try {
      const data = await this.service.saveResult(req.instituteId!, req.body, {
        role: req.user?.role,
        userId: req.user?.userId,
      });
      return sendResponse({ res, data, statusCode: 201, message: 'Exam result saved successfully' });
    } catch (error) {
      next(error);
    }
  };
}

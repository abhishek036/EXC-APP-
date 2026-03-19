import { Request, Response, NextFunction } from 'express';
import { LectureService } from './lecture.service';
import { sendResponse } from '../../utils/response';

export class LectureController {
  static async listLectures(req: Request, res: Response, next: NextFunction) {
    try {
      const lectures = await LectureService.listLectures(req.params.batchId, req.instituteId!);
      return sendResponse({ res, data: lectures });
    } catch (error) {
      next(error);
    }
  }

  static async createLecture(req: Request, res: Response, next: NextFunction) {
    try {
      const lecture = await LectureService.createLecture(
        req.instituteId!,
        req.user!.userId,
        req.body
      );
      return sendResponse({ res, data: lecture, message: 'Lecture created successfully', statusCode: 201 });
    } catch (error) {
      next(error);
    }
  }

  static async updateLecture(req: Request, res: Response, next: NextFunction) {
    try {
      await LectureService.updateLecture(req.params.id, req.instituteId!, req.body);
      return sendResponse({ res, data: null, message: 'Lecture updated successfully' });
    } catch (error) {
      next(error);
    }
  }

  static async deleteLecture(req: Request, res: Response, next: NextFunction) {
    try {
      await LectureService.deleteLecture(req.params.id, req.instituteId!);
      return sendResponse({ res, data: null, message: 'Lecture deleted successfully' });
    } catch (error) {
      next(error);
    }
  }
}

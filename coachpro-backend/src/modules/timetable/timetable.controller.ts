import { Request, Response, NextFunction } from 'express';
import { TimetableService } from './timetable.service';
import { sendResponse } from '../../utils/response';

export class TimetableController {
  private service: TimetableService;

  constructor() {
    this.service = new TimetableService();
  }

  schedule = async (req: Request, res: Response, next: NextFunction) => {
    try {
      const data = await this.service.scheduleLecture(req.instituteId!, req.body);
      return sendResponse({ res, data, message: 'Lecture scheduled successfully' });
    } catch (error) { next(error); }
  };

  getByBatch = async (req: Request, res: Response, next: NextFunction) => {
    try {
      const data = await this.service.getBatchTimetable(req.params.batchId, req.instituteId!);
      return sendResponse({ res, data, message: 'Batch timetable fetched' });
    } catch (error) { next(error); }
  };

  getByTeacher = async (req: Request, res: Response, next: NextFunction) => {
    try {
      const data = await this.service.getTeacherTimetable(req.params.teacherId, req.instituteId!);
      return sendResponse({ res, data, message: 'Teacher timetable fetched' });
    } catch (error) { next(error); }
  };
}

import { Request, Response, NextFunction } from 'express';
import { TimetableService } from './timetable.service';
import { sendResponse } from '../../utils/response';
import { emitBatchSync } from '../../config/socket';

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
    } catch (error) {
      if ((error as any)?.code === 'P2022') {
        return sendResponse({
          res,
          data: [],
          message: 'Batch timetable unavailable for current DB schema; returning empty result',
        });
      }
      next(error);
    }
  };

  getByTeacher = async (req: Request, res: Response, next: NextFunction) => {
    try {
      const data = await this.service.getTeacherTimetable(req.params.teacherId, req.instituteId!);
      return sendResponse({ res, data, message: 'Teacher timetable fetched' });
    } catch (error) {
      if ((error as any)?.code === 'P2022') {
        return sendResponse({
          res,
          data: [],
          message: 'Teacher timetable unavailable for current DB schema; returning empty result',
        });
      }
      next(error);
    }
  };

  getMySchedule = async (req: Request, res: Response, next: NextFunction) => {
    try {
      const date = typeof req.query.date === 'string' ? req.query.date : undefined;
      const data = await this.service.getTeacherScheduleByUser(req.user!.userId, req.instituteId!, date);
      return sendResponse({ res, data, message: 'Teacher schedule fetched' });
    } catch (error) {
      const code = (error as any)?.code;
      if (code === 'P2022' || code === 'P2023') {
        return sendResponse({
          res,
          data: [],
          message: 'Teacher schedule partially unavailable due to legacy data/schema mismatch; returning empty result',
        });
      }
      next(error);
    }
  };

  createMySchedule = async (req: Request, res: Response, next: NextFunction) => {
    try {
      const data = await this.service.createTeacherScheduleByUser(req.user!.userId, req.instituteId!, req.body);
      emitBatchSync(req.instituteId!, data.batch_id, 'lecture_schedule_created', {
        lecture_id: data.id,
      });
      return sendResponse({ res, data, message: 'Schedule created', statusCode: 201 });
    } catch (error) {
      next(error);
    }
  };

  updateMySchedule = async (req: Request, res: Response, next: NextFunction) => {
    try {
      const data = await this.service.updateTeacherScheduleByUser(req.user!.userId, req.instituteId!, req.params.lectureId, req.body);
      emitBatchSync(req.instituteId!, data.batch_id, 'lecture_schedule_updated', {
        lecture_id: data.id,
      });
      return sendResponse({ res, data, message: 'Schedule updated' });
    } catch (error) {
      next(error);
    }
  };

  deleteMySchedule = async (req: Request, res: Response, next: NextFunction) => {
    try {
      const existing = await this.service.getTeacherScheduleItemByUser(req.user!.userId, req.instituteId!, req.params.lectureId);
      await this.service.deleteTeacherScheduleByUser(req.user!.userId, req.instituteId!, req.params.lectureId);
      emitBatchSync(req.instituteId!, existing.batch_id, 'lecture_schedule_deleted', {
        lecture_id: req.params.lectureId,
      });
      return sendResponse({ res, data: null, message: 'Schedule deleted' });
    } catch (error) {
      next(error);
    }
  };

  clearMyPastSchedules = async (req: Request, res: Response, next: NextFunction) => {
    try {
      await this.service.clearPastSchedules(req.user!.userId, req.instituteId!);
      // Use a generic event
      emitBatchSync(req.instituteId!, 'all', 'lecture_schedule_cleared');
      return sendResponse({ res, data: null, message: 'Past schedules cleared' });
    } catch (error) {
      next(error);
    }
  };
}

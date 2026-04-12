import { Request, Response, NextFunction } from 'express';
import { TimetableService } from './timetable.service';
import { sendResponse } from '../../utils/response';
import { emitBatchSync } from '../../config/socket';
import { ApiError } from '../../middleware/error.middleware';

export class TimetableController {
  private service: TimetableService;

  constructor() {
    this.service = new TimetableService();
  }

  private async assertCanAccessBatch(batchId: string, req: Request) {
    const role = (req.user?.role || '').toLowerCase();
    if (role === 'admin') return;

    const { prisma } = await import('../../server');

    if (role === 'teacher') {
      const teacher = await prisma.teacher.findFirst({
        where: { user_id: req.user!.userId, institute_id: req.instituteId! },
        select: { id: true },
      });
      if (!teacher) {
        throw new ApiError('Teacher profile not found', 404, 'NOT_FOUND');
      }
      const batch = await prisma.batch.findFirst({
        where: { id: batchId, institute_id: req.instituteId!, teacher_id: teacher.id, is_active: true },
        select: { id: true },
      });
      if (!batch) {
        throw new ApiError('You do not have access to this batch timetable', 403, 'FORBIDDEN');
      }
      return;
    }

    if (role === 'student') {
      const student = await prisma.student.findFirst({
        where: { user_id: req.user!.userId, institute_id: req.instituteId! },
        select: { id: true },
      });
      if (!student) {
        throw new ApiError('Student profile not found', 404, 'NOT_FOUND');
      }
      const membership = await prisma.studentBatch.findFirst({
        where: { student_id: student.id, batch_id: batchId, is_active: true },
        select: { id: true },
      });
      if (!membership) {
        throw new ApiError('You do not have access to this batch timetable', 403, 'FORBIDDEN');
      }
      return;
    }

    if (role === 'parent') {
      const parent = await prisma.parent.findFirst({
        where: { user_id: req.user!.userId, institute_id: req.instituteId! },
        select: { id: true },
      });
      if (!parent) {
        throw new ApiError('Parent profile not found', 404, 'NOT_FOUND');
      }
      const membership = await prisma.studentBatch.findFirst({
        where: {
          batch_id: batchId,
          is_active: true,
          student: {
            parent_students: {
              some: { parent_id: parent.id },
            },
          },
        },
        select: { id: true },
      });
      if (!membership) {
        throw new ApiError('You do not have access to this batch timetable', 403, 'FORBIDDEN');
      }
      return;
    }

    throw new ApiError('You do not have access to this batch timetable', 403, 'FORBIDDEN');
  }

  private async assertCanAccessTeacher(teacherId: string, req: Request) {
    const role = (req.user?.role || '').toLowerCase();
    if (role === 'admin') return;

    const { prisma } = await import('../../server');

    if (role === 'teacher') {
      const teacher = await prisma.teacher.findFirst({
        where: { user_id: req.user!.userId, institute_id: req.instituteId! },
        select: { id: true },
      });
      if (!teacher || teacher.id !== teacherId) {
        throw new ApiError('You do not have access to this teacher timetable', 403, 'FORBIDDEN');
      }
      return;
    }

    if (role === 'student') {
      const student = await prisma.student.findFirst({
        where: { user_id: req.user!.userId, institute_id: req.instituteId! },
        select: { id: true },
      });
      if (!student) {
        throw new ApiError('Student profile not found', 404, 'NOT_FOUND');
      }
      const hasBatch = await prisma.studentBatch.findFirst({
        where: {
          student_id: student.id,
          is_active: true,
          batch: {
            teacher_id: teacherId,
            institute_id: req.instituteId!,
            is_active: true,
          },
        },
        select: { id: true },
      });
      if (!hasBatch) {
        throw new ApiError('You do not have access to this teacher timetable', 403, 'FORBIDDEN');
      }
      return;
    }

    if (role === 'parent') {
      const parent = await prisma.parent.findFirst({
        where: { user_id: req.user!.userId, institute_id: req.instituteId! },
        select: { id: true },
      });
      if (!parent) {
        throw new ApiError('Parent profile not found', 404, 'NOT_FOUND');
      }
      const hasBatch = await prisma.studentBatch.findFirst({
        where: {
          is_active: true,
          batch: {
            teacher_id: teacherId,
            institute_id: req.instituteId!,
            is_active: true,
          },
          student: {
            parent_students: {
              some: { parent_id: parent.id },
            },
          },
        },
        select: { id: true },
      });
      if (!hasBatch) {
        throw new ApiError('You do not have access to this teacher timetable', 403, 'FORBIDDEN');
      }
      return;
    }

    throw new ApiError('You do not have access to this teacher timetable', 403, 'FORBIDDEN');
  }

  schedule = async (req: Request, res: Response, next: NextFunction) => {
    try {
      const data = await this.service.scheduleLecture(req.instituteId!, req.body);
      return sendResponse({ res, data, message: 'Lecture scheduled successfully' });
    } catch (error) { next(error); }
  };

  getByBatch = async (req: Request, res: Response, next: NextFunction) => {
    try {
      await this.assertCanAccessBatch(req.params.batchId, req);
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
      await this.assertCanAccessTeacher(req.params.teacherId, req);
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
      if (data) {
          emitBatchSync(req.instituteId!, data.batch_id, 'lecture_schedule_created', {
            lecture_id: data.id,
          });
      }
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
      const { prisma } = require('../../server');
      const existing = await prisma.lecture.findUnique({ where: { id: req.params.lectureId } });
      await this.service.deleteTeacherScheduleByUser(req.user!.userId, req.instituteId!, req.params.lectureId);
      if (existing) {
          emitBatchSync(req.instituteId!, existing.batch_id, 'lecture_schedule_deleted', {
            lecture_id: req.params.lectureId,
          });
      }
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

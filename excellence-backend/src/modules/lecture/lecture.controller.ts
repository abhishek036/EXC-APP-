import { Request, Response, NextFunction } from 'express';
import { LectureService } from './lecture.service';
import { sendResponse } from '../../utils/response';
import { prisma } from '../../server';
import { emitBatchSync } from '../../config/socket';

export class LectureController {
  static async listLectures(req: Request, res: Response, next: NextFunction) {
    try {
      const { subject } = req.query;
      const lectures = await LectureService.listLectures(req.params.batchId, req.instituteId!, subject as string);
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

      // Emit real-time sync event
      if (req.body.batch_id) {
        emitBatchSync(req.instituteId!, req.body.batch_id, 'lecture_created', {
          lecture_id: (lecture as any)?.id,
        });
      }

      // Notify students about new lecture
      if (req.body.batch_id) {
        try {
          const { NotificationService } = await import('../notification/notification.service');
          const students = await prisma.student.findMany({
            where: { student_batches: { some: { batch_id: req.body.batch_id } }, is_active: true },
            select: { user_id: true }
          });

          const batch = await prisma.batch.findUnique({
            where: { id: req.body.batch_id },
            select: { name: true }
          });

          for (const student of students) {
            if (student.user_id) {
              await NotificationService.sendNotificationToUser(student.user_id, {
                title: 'New Lecture Added',
                body: `A new lecture "${req.body.title || 'Untitled'}" has been added to your batch "${batch?.name || 'your batch'}".`,
                type: 'material',
                institute_id: req.instituteId!,
                meta: {
                  route: '/student/materials',
                  lecture_id: (lecture as any)?.id,
                  batch_id: req.body.batch_id
                }
              });
            }
          }
        } catch (err) {
          console.error('[LectureController] Failed to send lecture notifications:', err);
        }
      }

      return sendResponse({ res, data: lecture, message: 'Lecture created successfully', statusCode: 201 });
    } catch (error) {
      next(error);
    }
  }

  static async updateLecture(req: Request, res: Response, next: NextFunction) {
    try {
      await LectureService.updateLecture(req.params.id, req.instituteId!, req.body);

      // Emit real-time sync event
      if (req.body.batch_id) {
        emitBatchSync(req.instituteId!, req.body.batch_id, 'lecture_updated', {
          lecture_id: req.params.id,
        });
      }

      return sendResponse({ res, data: null, message: 'Lecture updated successfully' });
    } catch (error) {
      next(error);
    }
  }

  static async deleteLecture(req: Request, res: Response, next: NextFunction) {
    try {
      // Get lecture batch_id before deletion for sync
      const lecture = await prisma.lecture.findFirst({
        where: { id: req.params.id, institute_id: req.instituteId! },
        select: { batch_id: true },
      }).catch(() => null);

      await LectureService.deleteLecture(req.params.id, req.instituteId!);

      // Emit real-time sync event
      if (lecture?.batch_id) {
        emitBatchSync(req.instituteId!, lecture.batch_id, 'lecture_deleted', {
          lecture_id: req.params.id,
        });
      }

      return sendResponse({ res, data: null, message: 'Lecture deleted successfully' });
    } catch (error) {
      next(error);
    }
  }
}

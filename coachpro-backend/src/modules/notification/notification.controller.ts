import { NextFunction, Request, Response } from 'express';
import { sendResponse } from '../../utils/response';
import { NotificationService } from './notification.service';
import { NotificationHandler } from '../../jobs/handlers/notification.handler';
import { ApiError } from '../../middleware/error.middleware';

export class NotificationController {
  static async registerToken(req: Request, res: Response, next: NextFunction) {
    try {
      const { token, platform } = req.body;
      const data = await NotificationService.registerDeviceToken({
        instituteId: req.instituteId!,
        userId: req.user!.userId,
        token,
        platform,
      });
      return sendResponse({ res, data, message: 'Device token registered' });
    } catch (error) {
      next(error);
    }
  }

  static async unregisterToken(req: Request, res: Response, next: NextFunction) {
    try {
      const { token } = req.body;
      const data = await NotificationService.unregisterDeviceToken({
        instituteId: req.instituteId!,
        userId: req.user!.userId,
        token,
      });
      return sendResponse({ res, data, message: 'Device token unregistered' });
    } catch (error) {
      next(error);
    }
  }

  static async getHealth(req: Request, res: Response, next: NextFunction) {
    try {
      const data = await NotificationService.getHealth(req.instituteId!);
      return sendResponse({ res, data, message: 'Notification health fetched' });
    } catch (error) {
      next(error);
    }
  }

  static async listMy(req: Request, res: Response, next: NextFunction) {
    try {
      const page = req.query.page ? Number(req.query.page) : 1;
      const perPage = req.query.perPage ? Number(req.query.perPage) : 20;
      const type = req.query.type ? String(req.query.type) : undefined;
      const readStatus = req.query.read_status ? String(req.query.read_status) as 'read' | 'unread' | 'all' : 'all';

      const result = await NotificationService.listMyNotifications({
        instituteId: req.instituteId!,
        userId: req.user!.userId,
        page,
        perPage,
        type,
        readStatus,
      });

      return sendResponse({
        res,
        data: result.items,
        meta: result.meta,
        message: 'Notifications fetched',
      });
    } catch (error) {
      next(error);
    }
  }

  static async markRead(req: Request, res: Response, next: NextFunction) {
    try {
      const readStatus = Boolean(req.body.read_status);
      const data = await NotificationService.markAsRead({
        instituteId: req.instituteId!,
        userId: req.user!.userId,
        notificationId: req.params.id,
        readStatus,
      });
      return sendResponse({ res, data, message: 'Notification status updated' });
    } catch (error) {
      next(error);
    }
  }

  static async markAllRead(req: Request, res: Response, next: NextFunction) {
    try {
      const data = await NotificationService.markAllAsRead({
        instituteId: req.instituteId!,
        userId: req.user!.userId,
      });
      return sendResponse({ res, data, message: 'All notifications marked as read' });
    } catch (error) {
      next(error);
    }
  }

  static async sendManual(req: Request, res: Response, next: NextFunction) {
    try {
      const { title, body, type, role_target, user_id, meta } = req.body;
      const targetInstituteId = req.instituteId!;
      const requesterRole = req.user?.role ?? '';

      if (requesterRole === 'teacher') {
        if (user_id) {
          return next(new ApiError('Teachers must send by role target (student/parent), not direct user id', 403, 'FORBIDDEN'));
        }

        const teacherAllowedTargets = new Set(['student', 'parent']);
        if (!role_target || !teacherAllowedTargets.has(role_target)) {
          return next(new ApiError('Teachers can send notifications only to student or parent roles', 403, 'FORBIDDEN'));
        }
      }

      const metaWithBroadcast = {
        ...(meta ?? {}),
        broadcast_id: (meta?.broadcast_id ?? `manual:${Date.now()}:${Math.random().toString(36).slice(2, 8)}`).toString(),
        sender_role: requesterRole,
      };

      let result;
      if (user_id) {
        result = await NotificationService.sendNotificationToUser(user_id, {
          title,
          body,
          type,
          role_target,
          institute_id: targetInstituteId,
          meta: metaWithBroadcast,
        });
      } else if (role_target && role_target !== 'all') {
        result = await NotificationService.sendNotificationToRole(role_target, {
          title,
          body,
          type,
          role_target,
          institute_id: targetInstituteId,
          meta: metaWithBroadcast,
        });
      } else {
        result = await NotificationService.sendNotificationToInstitute(targetInstituteId, {
          title,
          body,
          type,
          role_target: role_target ?? 'all',
          meta: metaWithBroadcast,
        });
      }

      return sendResponse({ res, data: result, statusCode: 201, message: 'Notification sent successfully' });
    } catch (error) {
      next(error);
    }
  }

  static async triggerFeeReminders(req: Request, res: Response, next: NextFunction) {
    try {
      const data = await NotificationHandler.processFeeReminders();
      return sendResponse({ res, data, message: 'Fee reminders processed' });
    } catch (error) {
      next(error);
    }
  }

  static async triggerClassReminders(req: Request, res: Response, next: NextFunction) {
    try {
      const data = await NotificationHandler.processClassReminders();
      return sendResponse({ res, data, message: 'Class reminders processed' });
    } catch (error) {
      next(error);
    }
  }

  static async triggerDailyRevenueSummary(req: Request, res: Response, next: NextFunction) {
    try {
      const data = await NotificationHandler.processDailyRevenueSummary();
      return sendResponse({ res, data, message: 'Daily revenue summary notifications sent' });
    } catch (error) {
      next(error);
    }
  }

  static async deleteMine(req: Request, res: Response, next: NextFunction) {
    try {
      const data = await NotificationService.deleteMyNotification({
        instituteId: req.instituteId!,
        userId: req.user!.userId,
        notificationId: req.params.id,
      });
      return sendResponse({ res, data, message: 'Notification deleted' });
    } catch (error) {
      next(error);
    }
  }

  static async deleteGlobal(req: Request, res: Response, next: NextFunction) {
    try {
      const data = await NotificationService.deleteGlobalNotification({
        instituteId: req.instituteId!,
        requesterRole: req.user!.role,
        notificationId: req.params.id,
      });
      return sendResponse({ res, data, message: 'Notification deleted for all recipients' });
    } catch (error) {
      next(error);
    }
  }
}

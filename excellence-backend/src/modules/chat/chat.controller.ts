import { Request, Response, NextFunction } from 'express';
import { ChatService } from './chat.service';
import { sendResponse } from '../../utils/response';
import { prisma } from '../../server';
import { ApiError } from '../../middleware/error.middleware';

export class ChatController {
  // List chat rooms the user has access to
  static async getRooms(req: Request, res: Response, next: NextFunction) {
    try {
      const rooms = await ChatService.getRooms(
        req.user!.userId,
        req.user!.role,
        req.instituteId!
      );
      return sendResponse({ res, data: rooms, message: 'Chat rooms fetched' });
    } catch (error) {
      next(error);
    }
  }

  // Get message history for a batch
  static async getHistory(req: Request, res: Response, next: NextFunction) {
    try {
      const limit = parseInt(req.query.limit as string) || 50;
      const before = req.query.before as string | undefined;
      const history = await ChatService.getHistory(
        req.params.batchId,
        req.instituteId!,
        req.user!.userId,
        req.user!.role,
        limit,
        before,
      );
      return sendResponse({ res, data: history, message: 'Chat history fetched' });
    } catch (error) {
      next(error);
    }
  }

  // Send a new message
  static async sendMessage(req: Request, res: Response, next: NextFunction) {
    try {
      const { batchId } = req.params;
      const { text, imageUrl } = req.body;

      if (!text && !imageUrl) {
        throw new ApiError('Message text or image is required', 400, 'VALIDATION_ERROR');
      }

      // Get sender display name
      let senderName = 'Unknown';
      const role = req.user!.role;

      if (role === 'student') {
        const student = await prisma.student.findFirst({
          where: { user_id: req.user!.userId, institute_id: req.instituteId! }
        });
        senderName = student?.name || 'Student';
      } else if (role === 'teacher') {
        const teacher = await prisma.teacher.findFirst({
          where: { user_id: req.user!.userId, institute_id: req.instituteId! }
        });
        senderName = teacher?.name || 'Teacher';
      } else if (role === 'parent') {
        const parent = await prisma.parent.findFirst({
          where: { user_id: req.user!.userId, institute_id: req.instituteId! }
        });
        senderName = parent?.name || 'Parent';
      } else {
        senderName = 'Admin';
      }

      const message = await ChatService.sendMessage({
        batchId,
        instituteId: req.instituteId!,
        senderId: req.user!.userId,
        senderName,
        senderRole: role,
        message: text,
        imageUrl,
      });

      return sendResponse({ res, data: message, statusCode: 201, message: 'Message sent' });
    } catch (error) {
      next(error);
    }
  }

  // Delete a message
  static async deleteMessage(req: Request, res: Response, next: NextFunction) {
    try {
      await ChatService.deleteMessage(req.params.id, req.instituteId!);
      return sendResponse({ res, data: null, message: 'Message deleted successfully' });
    } catch (error) {
      next(error);
    }
  }
}

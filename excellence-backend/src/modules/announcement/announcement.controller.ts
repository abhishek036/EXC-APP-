import { Request, Response, NextFunction } from 'express';
import { sendResponse } from '../../utils/response';
import { AnnouncementService } from './announcement.service';

export class AnnouncementController {
  private service: AnnouncementService;

  constructor() {
    this.service = new AnnouncementService();
  }

  list = async (req: Request, res: Response, next: NextFunction) => {
    try {
      const data = await this.service.list(req.instituteId!, req.query.category as string | undefined);
      return sendResponse({ res, data, message: 'Announcements fetched successfully' });
    } catch (error) {
      next(error);
    }
  };

  create = async (req: Request, res: Response, next: NextFunction) => {
    try {
      const data = await this.service.create(req.instituteId!, req.user!.userId, req.body);
      return sendResponse({ res, data, statusCode: 201, message: 'Announcement created successfully' });
    } catch (error) {
      next(error);
    }
  };

  update = async (req: Request, res: Response, next: NextFunction) => {
    try {
      const data = await this.service.update(req.params.id, req.instituteId!, req.body);
      return sendResponse({ res, data, message: 'Announcement updated successfully' });
    } catch (error) {
      next(error);
    }
  };

  remove = async (req: Request, res: Response, next: NextFunction) => {
    try {
      const data = await this.service.remove(req.params.id, req.instituteId!);
      return sendResponse({ res, data, message: 'Announcement deleted successfully' });
    } catch (error) {
      next(error);
    }
  };
}

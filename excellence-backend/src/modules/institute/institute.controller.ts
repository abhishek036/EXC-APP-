import { Request, Response, NextFunction } from 'express';
import { InstituteService } from './institute.service';
import { sendResponse } from '../../utils/response';

export class InstituteController {
  private service: InstituteService;

  constructor() {
    this.service = new InstituteService();
  }

  getProfile = async (req: Request, res: Response, next: NextFunction) => {
    try {
      const data = await this.service.getProfile(req.instituteId!);
      return sendResponse({ res, data, message: 'Institute config fetched' });
    } catch (e) { next(e); }
  }

  updateProfile = async (req: Request, res: Response, next: NextFunction) => {
    try {
      const data = await this.service.updateProfile(req.instituteId!, req.body);
      return sendResponse({ res, data, message: 'Config updated' });
    } catch (e) { next(e); }
  }
}

import { Request, Response, NextFunction } from 'express';
import { sendResponse } from '../../utils/response';
import { LeadService } from './lead.service';

export class LeadController {
  private service: LeadService;

  constructor() {
    this.service = new LeadService();
  }

  list = async (req: Request, res: Response, next: NextFunction) => {
    try {
      const data = await this.service.list(req.instituteId!);
      return sendResponse({ res, data, message: 'Leads fetched successfully' });
    } catch (error) {
      next(error);
    }
  };

  create = async (req: Request, res: Response, next: NextFunction) => {
    try {
      const data = await this.service.create(req.instituteId!, req.body);
      return sendResponse({ res, data, statusCode: 201, message: 'Lead created successfully' });
    } catch (error) {
      next(error);
    }
  };

  updateStatus = async (req: Request, res: Response, next: NextFunction) => {
    try {
      const data = await this.service.updateStatus(req.instituteId!, req.params.id, req.body.status);
      return sendResponse({ res, data, message: 'Lead status updated successfully' });
    } catch (error) {
      next(error);
    }
  };

  updateLead = async (req: Request, res: Response, next: NextFunction) => {
    try {
      const data = await this.service.updateLead(req.instituteId!, req.params.id, req.body);
      return sendResponse({ res, data, message: 'Lead updated successfully' });
    } catch (error) {
      next(error);
    }
  };

  deleteLead = async (req: Request, res: Response, next: NextFunction) => {
    try {
      await this.service.deleteLead(req.instituteId!, req.params.id);
      return sendResponse({ res, data: null, message: 'Lead deleted successfully' });
    } catch (error) {
      next(error);
    }
  };
}

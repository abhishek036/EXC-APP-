import { Request, Response, NextFunction } from 'express';
import { UsersService } from './users.service';
import { sendResponse } from '../../utils/response';
import { ApiError } from '../../middleware/error.middleware';

export class UsersController {
  private service: UsersService;

  private getInstituteId(req: Request): string {
    const instituteId = req.instituteId || req.user?.instituteId;
    if (!instituteId) {
      throw new ApiError('Institute context is missing for this request', 400, 'INSTITUTE_ID_REQUIRED');
    }
    return instituteId;
  }

  constructor() {
    this.service = new UsersService();
  }

  /** GET /users — list all users for this institute */
  list = async (req: Request, res: Response, next: NextFunction) => {
    try {
      const { role, status, search, page, perPage } = req.query;
      const instituteId = this.getInstituteId(req);
      const data = await this.service.listUsers(instituteId, {
        role: role as string,
        status: status as string,
        search: search as string,
        page: Number(page) || 1,
        perPage: Number(perPage) || 20,
      });
      return sendResponse({ res, data: data.data, meta: data.meta, message: 'Users fetched' });
    } catch (e) { next(e); }
  };

  /** PATCH /users/:id/status — block / activate a user */
  updateStatus = async (req: Request, res: Response, next: NextFunction) => {
    try {
      const { status } = req.body; // ACTIVE | BLOCKED | INACTIVE
      const instituteId = this.getInstituteId(req);
      const data = await this.service.updateStatus(req.params.id, instituteId, status);
      return sendResponse({ res, data, message: `User status updated to ${status}` });
    } catch (e) { next(e); }
  };

  /** PATCH /users/:id/role — change user role */
  changeRole = async (req: Request, res: Response, next: NextFunction) => {
    try {
      const { role } = req.body; // admin | teacher | student | parent
      const instituteId = this.getInstituteId(req);
      const data = await this.service.changeRole(req.params.id, instituteId, role);
      return sendResponse({ res, data, message: `User role changed to ${role}` });
    } catch (e) { next(e); }
  };

  /** GET /users/:id — get full user profile */
  getUser = async (req: Request, res: Response, next: NextFunction) => {
    try {
      const instituteId = this.getInstituteId(req);
      const data = await this.service.getUserById(req.params.id, instituteId);
      return sendResponse({ res, data, message: 'User fetched' });
    } catch (e) { next(e); }
  };
}

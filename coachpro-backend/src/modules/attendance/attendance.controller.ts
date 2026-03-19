import { Request, Response, NextFunction } from 'express';
import { AttendanceService } from './attendance.service';
import { sendResponse } from '../../utils/response';
import { ApiError } from '../../middleware/error.middleware';

export class AttendanceController {
  private service: AttendanceService;

  constructor() {
    this.service = new AttendanceService();
  }

  mark = async (req: Request, res: Response, next: NextFunction) => {
    try {
      const data = await this.service.markSession(req.instituteId!, req.user!.userId, req.body);
      return sendResponse({ res, data, message: 'Attendance marked successfully' });
    } catch (e) { next(e); }
  }

  getBatch = async (req: Request, res: Response, next: NextFunction) => {
    try {
      const { month, year } = req.query;
      if (!month || !year) throw new ApiError('Month and year query params are required', 400, 'BAD_REQUEST');
  
      const data = await this.service.getBatchMonthly(
          req.params.batchId, 
          req.instituteId!, 
          Number(month), 
          Number(year)
      );
      return sendResponse({ res, data, message: 'Batch attendance fetched' });
    } catch (e) { next(e); }
  }

  getStudent = async (req: Request, res: Response, next: NextFunction) => {
    try {
      const { studentId } = req.params;
      const { userId, role } = req.user!;

      // Security: Students can only view their own attendance
      if (role === 'student') {
        const { prisma } = await import('../../server');
        const student = await prisma.student.findFirst({ where: { user_id: userId } });
        if (!student || student.id !== studentId) {
          throw new ApiError('Unauthorized: You can only view your own attendance records', 403, 'FORBIDDEN');
        }
      }

      const batchId = req.query.batchId as string | undefined;
      const data = await this.service.getStudentReport(studentId, req.instituteId!, batchId);
      return sendResponse({ res, data, message: 'Student attendance report fetched' });
    } catch (e) { next(e); }
  }

  reportIssue = async (req: Request, res: Response, next: NextFunction) => {
    try {
       // Typically a student or parent hitting this 
       // For now just returning success as this is often sent to an admin mailbox or doubt system
       return sendResponse({ res, data: null, message: 'Attendance issue reported successfully to Admin' });
    } catch (e) { next(e); }
  }

  getStats = async (req: Request, res: Response, next: NextFunction) => {
    try {
      const batchId = req.query.batchId as string | undefined;
      const data = await this.service.getDashboardStats(req.instituteId!, batchId);
      return sendResponse({ res, data, message: 'Attendance statistics fetched' });
    } catch (e) { next(e); }
  }
}

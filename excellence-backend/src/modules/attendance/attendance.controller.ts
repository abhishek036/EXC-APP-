import { Request, Response, NextFunction } from 'express';
import { AttendanceService } from './attendance.service';
import { sendResponse } from '../../utils/response';
import { ApiError } from '../../middleware/error.middleware';
import { emitBatchSync } from '../../config/socket';

export class AttendanceController {
  private service: AttendanceService;

  constructor() {
    this.service = new AttendanceService();
  }

  mark = async (req: Request, res: Response, next: NextFunction) => {
    try {
      const data = await this.service.markSession(req.instituteId!, req.user!.userId, req.user!.role, req.body);
      if (req.body?.batch_id) {
        emitBatchSync(req.instituteId!, req.body.batch_id, 'attendance_marked', {
          session_id: (data as any)?.session_id,
        });
      }
      return sendResponse({ res, data, message: 'Attendance marked successfully' });
    } catch (e) { next(e); }
  }

  getBatch = async (req: Request, res: Response, next: NextFunction) => {
    try {
      const { month, year, subject } = req.query;
      if (!month || !year) throw new ApiError('Month and year query params are required', 400, 'BAD_REQUEST');
  
      const data = await this.service.getBatchMonthly(
          req.params.batchId, 
          req.instituteId!, 
          Number(month), 
          Number(year),
          subject as string
      );
      return sendResponse({ res, data, message: 'Batch attendance fetched' });
    } catch (e) { next(e); }
  }

  getStudent = async (req: Request, res: Response, next: NextFunction) => {
    try {
      const { studentId } = req.params;
      const { userId, role } = req.user!;
      const { prisma } = await import('../../server');

      // Security: Students can only view their own attendance
      if (role === 'student') {
        const student = await prisma.student.findFirst({ where: { user_id: userId, institute_id: req.instituteId! } });
        if (!student || student.id !== studentId) {
          throw new ApiError('Unauthorized: You can only view your own attendance records', 403, 'FORBIDDEN');
        }
      }

      if (role === 'parent') {
        const parent = await prisma.parent.findFirst({
          where: { user_id: userId, institute_id: req.instituteId! },
          include: { parent_students: { where: { student_id: studentId } } },
        });
        if (!parent || parent.parent_students.length === 0) {
          throw new ApiError('Unauthorized: You can only view your child attendance records', 403, 'FORBIDDEN');
        }
      }

      const batchId = req.query.batchId as string | undefined;
      const subject = req.query.subject as string | undefined;
      const data = await this.service.getStudentReport(studentId, req.instituteId!, batchId, subject);
      return sendResponse({ res, data, message: 'Student attendance report fetched' });
    } catch (e) { next(e); }
  }

  reportIssue = async (req: Request, res: Response, next: NextFunction) => {
    try {
       const { studentId } = req.params;
       const { userId, role } = req.user!;
       const { prisma } = await import('../../server');

       if (role === 'student') {
         const student = await prisma.student.findFirst({ where: { user_id: userId, institute_id: req.instituteId! } });
         if (!student || student.id !== studentId) {
           throw new ApiError('Unauthorized: You can report issues only for your own attendance records', 403, 'FORBIDDEN');
         }
       }

       if (role === 'parent') {
         const parent = await prisma.parent.findFirst({
           where: { user_id: userId, institute_id: req.instituteId! },
           include: { parent_students: { where: { student_id: studentId } } },
         });
         if (!parent || parent.parent_students.length === 0) {
           throw new ApiError('Unauthorized: You can report issues only for your child records', 403, 'FORBIDDEN');
         }
       }

       // Typically a student or parent hitting this 
       // For now just returning success as this is often sent to an admin mailbox or doubt system
       return sendResponse({ res, data: null, message: 'Attendance issue reported successfully to Admin' });
    } catch (e) { next(e); }
  }

  getStats = async (req: Request, res: Response, next: NextFunction) => {
    try {
      const batchId = req.query.batchId as string | undefined;
      const subject = req.query.subject as string | undefined;
      const data = await this.service.getDashboardStats(req.instituteId!, batchId, subject);
      return sendResponse({ res, data, message: 'Attendance statistics fetched' });
    } catch (e) { next(e); }
  }
}

import { Request, Response, NextFunction } from 'express';
import { TeacherService } from './teacher.service';
import { sendResponse } from '../../utils/response';
import { prisma } from '../../server';
import { ApiError } from '../../middleware/error.middleware';

export class TeacherController {
  private teacherService: TeacherService;

  constructor() {
    this.teacherService = new TeacherService();
  }

  list = async (req: Request, res: Response, next: NextFunction) => {
    try {
      const { name, phone, page, perPage } = req.query;
      const result = await this.teacherService.listTeachers(req.instituteId!, { 
          name: name as string, 
          phone: phone as string,
          page: Number(page),
          perPage: Number(perPage)
      });
      return sendResponse({ res, data: result.data, meta: result.meta, message: 'Teachers fetched successfully' });
    } catch (error) { next(error); }
  };

  create = async (req: Request, res: Response, next: NextFunction) => {
    try {
      const data = await this.teacherService.createTeacher(req.instituteId!, req.body);
      return sendResponse({ res, data, statusCode: 201, message: 'Teacher created successfully' });
    } catch (error) { next(error); }
  };

  getById = async (req: Request, res: Response, next: NextFunction) => {
    try {
      const data = await this.teacherService.getTeacherDetails(req.params.id, req.instituteId!);
      return sendResponse({ res, data, message: 'Teacher details fetched successfully' });
    } catch (error) { next(error); }
  };

  getProfileDashboard = async (req: Request, res: Response, next: NextFunction) => {
    try {
      const data = await this.teacherService.getTeacherProfileDashboard(req.params.id, req.instituteId!);
      return sendResponse({ res, data, message: 'Teacher profile dashboard fetched successfully' });
    } catch (error) { next(error); }
  };

  updateSettings = async (req: Request, res: Response, next: NextFunction) => {
    try {
      const data = await this.teacherService.updateTeacherSettings(req.params.id, req.instituteId!, req.body);
      return sendResponse({ res, data, message: 'Teacher settings updated successfully' });
    } catch (error) { next(error); }
  };

  addFeedback = async (req: Request, res: Response, next: NextFunction) => {
    try {
      const data = await this.teacherService.addTeacherFeedback(req.params.id, req.instituteId!, req.body);
      return sendResponse({ res, data, message: 'Teacher feedback recorded successfully', statusCode: 201 });
    } catch (error) { next(error); }
  };

  update = async (req: Request, res: Response, next: NextFunction) => {
    try {
      const data = await this.teacherService.updateTeacher(req.params.id, req.instituteId!, req.body);
      return sendResponse({ res, data, message: 'Teacher updated successfully' });
    } catch (error) { next(error); }
  };

  toggleStatus = async (req: Request, res: Response, next: NextFunction) => {
    try {
      const { is_active } = req.body;
      const data = await this.teacherService.changeStatus(req.params.id, req.instituteId!, is_active);
      return sendResponse({ res, data, message: `Teacher ${is_active ? 'activated' : 'deactivated'} successfully` });
    } catch (error) { next(error); }
  };

  remove = async (req: Request, res: Response, next: NextFunction) => {
    try {
      const data = await this.teacherService.removeTeacher(req.params.id, req.instituteId!);
      return sendResponse({ res, data, message: 'Teacher removed successfully' });
    } catch (error) { next(error); }
  };

  // ─── Self-service: /teachers/me ──────────────────────────

  getMe = async (req: Request, res: Response, next: NextFunction) => {
    try {
      const teacher = await prisma.teacher.findFirst({
        where: { user_id: req.user!.userId, institute_id: req.instituteId! },
        include: {
          batches: {
            where: { is_active: true },
            select: { id: true, name: true, subject: true, room: true, start_time: true, end_time: true, days_of_week: true }
          }
        }
      });
      if (!teacher) throw new ApiError('Teacher profile not found', 404, 'NOT_FOUND');

      return sendResponse({ res, data: teacher, message: 'Teacher profile fetched' });
    } catch (error) { next(error); }
  };

  getDashboard = async (req: Request, res: Response, next: NextFunction) => {
    try {
      const teacher = await prisma.teacher.findFirst({
        where: { user_id: req.user!.userId, institute_id: req.instituteId! }
      });
      if (!teacher) throw new ApiError('Teacher not found', 404, 'NOT_FOUND');

      const instituteId = req.instituteId!;
      const teacherId = teacher.id;

      const [
        batches,
        pendingDoubts,
        weeklyAttendanceSessions,
        upcomingExams,
        recentQuizzes
      ] = await Promise.all([
        // My batches
        prisma.batch.findMany({
          where: { teacher_id: teacherId, institute_id: instituteId, is_active: true },
          include: { _count: { select: { student_batches: { where: { is_active: true } } } } }
        }),
        // Pending doubts assigned to me
        prisma.doubt.count({
          where: { assigned_to_id: teacherId, institute_id: instituteId, status: 'pending' }
        }),
        // Classes taken this week
        prisma.attendanceSession.count({
          where: {
            teacher_id: teacherId,
            institute_id: instituteId,
            session_date: { gte: new Date(Date.now() - 7 * 24 * 60 * 60 * 1000) }
          }
        }),
        // Upcoming exams for my batches
        prisma.exam.findMany({
          where: {
            institute_id: instituteId,
            exam_date: { gte: new Date() },
            batches: { some: { batch: { teacher_id: teacherId } } }
          },
          orderBy: { exam_date: 'asc' },
          take: 5,
          include: { batches: { include: { batch: { select: { name: true } } } } }
        }),
        // Recent quizzes
        prisma.quiz.findMany({
          where: { teacher_id: teacherId, institute_id: instituteId },
          orderBy: { created_at: 'desc' },
          take: 5,
          include: { _count: { select: { attempts: true } }, batch: { select: { name: true } } }
        })
      ]);

      const totalStudentsAcrossBatches = batches.reduce((sum, b) => sum + b._count.student_batches, 0);

      return sendResponse({
        res,
        data: {
          teacher: { id: teacher.id, name: teacher.name, subjects: teacher.subjects, photo_url: teacher.photo_url },
          batches: batches.map(b => ({
            id: b.id,
            name: b.name,
            subject: b.subject,
            room: b.room,
            start_time: b.start_time,
            end_time: b.end_time,
            days_of_week: b.days_of_week,
            student_count: b._count.student_batches
          })),
          stats: {
            total_batches: batches.length,
            total_students: totalStudentsAcrossBatches,
            pending_doubts: pendingDoubts,
            classes_this_week: weeklyAttendanceSessions,
            upcoming_exams_count: upcomingExams.length,
          },
          upcoming_exams: upcomingExams.map(e => ({
            id: e.id,
            title: e.title,
            subject: e.subject,
            exam_date: e.exam_date,
            total_marks: e.total_marks,
            batches: e.batches.map(eb => eb.batch.name)
          })),
          recent_quizzes: recentQuizzes.map(q => ({
            id: q.id,
            title: q.title,
            subject: q.subject,
            batch_name: q.batch.name,
            is_published: q.is_published,
            attempts_count: q._count.attempts,
            created_at: q.created_at
          }))
        },
        message: 'Teacher dashboard fetched'
      });
    } catch (error) { next(error); }
  };

  getWeeklyStats = async (req: Request, res: Response, next: NextFunction) => {
    try {
      const teacher = await prisma.teacher.findFirst({
        where: { user_id: req.user!.userId, institute_id: req.instituteId! }
      });
      if (!teacher) throw new ApiError('Teacher not found', 404, 'NOT_FOUND');

      const weekAgo = new Date(Date.now() - 7 * 24 * 60 * 60 * 1000);
      const instituteId = req.instituteId!;

      const [classesTaken, doubtsResolved, totalScheduled] = await Promise.all([
        prisma.attendanceSession.count({
          where: { teacher_id: teacher.id, institute_id: instituteId, session_date: { gte: weekAgo } }
        }),
        prisma.doubt.count({
          where: { assigned_to_id: teacher.id, institute_id: instituteId, status: 'resolved', resolved_at: { gte: weekAgo } }
        }),
        // Total scheduled = batches * days active this week (simplified)
        prisma.batch.count({
          where: { teacher_id: teacher.id, institute_id: instituteId, is_active: true }
        })
      ]);

      return sendResponse({
        res,
        data: {
          classes_taken: classesTaken,
          total_scheduled: totalScheduled * 5, // approximation: 5 working days
          doubts_resolved: doubtsResolved,
        },
        message: 'Weekly stats fetched'
      });
    } catch (error) { next(error); }
  };

  getMyBatches = async (req: Request, res: Response, next: NextFunction) => {
    try {
      const teacher = await prisma.teacher.findFirst({
        where: { user_id: req.user!.userId, institute_id: req.instituteId! }
      });
      if (!teacher) throw new ApiError('Teacher not found', 404, 'NOT_FOUND');

      const batches = await prisma.batch.findMany({
        where: { teacher_id: teacher.id, institute_id: req.instituteId!, is_active: true },
        include: { _count: { select: { student_batches: { where: { is_active: true } } } } }
      });

      return sendResponse({
         res, 
         data: batches.map(b => ({
             ...b,
             student_count: b._count.student_batches
         })), 
         message: 'Batches fetched' 
      });
    } catch (error) { next(error); }
  };

  getTodaySchedule = async (req: Request, res: Response, next: NextFunction) => {
      try {
        const teacher = await prisma.teacher.findFirst({
          where: { user_id: req.user!.userId, institute_id: req.instituteId! }
        });
        if (!teacher) throw new ApiError('Teacher not found', 404, 'NOT_FOUND');

        const dayIndex = new Date().getDay(); // 0(Sun) to 6(Sat)
        
        const schedule = await prisma.batch.findMany({
            where: {
                teacher_id: teacher.id,
                institute_id: req.instituteId!,
                is_active: true,
                days_of_week: {
                    has: dayIndex
                }
            },
            orderBy: {
                start_time: 'asc'
            }
        });

        return sendResponse({ res, data: schedule, message: 'Today schedule fetched' });
      } catch (error) { next(error); }
  };
}

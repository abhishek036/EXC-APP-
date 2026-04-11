import { Request, Response, NextFunction } from 'express';
import { StudentService } from './student.service';
import { sendResponse } from '../../utils/response';
import { prisma } from '../../server';
import { ApiError } from '../../middleware/error.middleware';
import { isLegacyColumnError } from '../../utils/prisma-errors';

export class StudentController {
  private studentService: StudentService;

  constructor() {
    this.studentService = new StudentService();
  }

  private isTeacherRequest(req: Request): boolean {
    return (req.user?.role ?? '').trim().toLowerCase() === 'teacher';
  }

  private sanitizeStudentForTeacher(student: Record<string, unknown>): Record<string, unknown> {
    const sanitized: Record<string, unknown> = { ...student };
    delete sanitized.phone;
    delete sanitized.parent_phone;

    const parentStudents = sanitized.parent_students;
    if (Array.isArray(parentStudents)) {
      sanitized.parent_students = parentStudents.map((link) => {
        if (!link || typeof link !== 'object') return link;
        const linkObj: Record<string, unknown> = {
          ...(link as Record<string, unknown>),
        };
        const parent = linkObj.parent;
        if (parent && typeof parent === 'object') {
          const parentObj: Record<string, unknown> = {
            ...(parent as Record<string, unknown>),
          };
          delete parentObj.phone;
          linkObj.parent = parentObj;
        }
        return linkObj;
      });
    }

    return sanitized;
  }

  private sanitizeStudentsPayloadForTeacher(payload: unknown): unknown {
    if (Array.isArray(payload)) {
      return payload.map((item) => {
        if (item && typeof item === 'object') {
          return this.sanitizeStudentForTeacher(item as Record<string, unknown>);
        }
        return item;
      });
    }

    if (payload && typeof payload === 'object') {
      return this.sanitizeStudentForTeacher(payload as Record<string, unknown>);
    }

    return payload;
  }

  list = async (req: Request, res: Response, next: NextFunction) => {
    try {
      const { name, phone, batchId, isActive, page, perPage } = req.query;
      const result = await this.studentService.listStudents(req.instituteId!, { 
          name: name as string, 
          phone: phone as string,
          batchId: batchId as string,
          isActive: isActive !== undefined ? isActive === 'true' : undefined,
          page: Number(page),
          perPage: Number(perPage)
      });
      const data = this.isTeacherRequest(req)
        ? this.sanitizeStudentsPayloadForTeacher(result.data)
        : result.data;
      return sendResponse({ res, data, meta: result.meta, message: 'Students fetched successfully' });
    } catch (error) { next(error); }
  };

  create = async (req: Request, res: Response, next: NextFunction) => {
    try {
      const data = await this.studentService.createStudent(req.instituteId!, req.body);
      return sendResponse({ res, data, statusCode: 201, message: 'Student created successfully' });
    } catch (error) { next(error); }
  };

  getById = async (req: Request, res: Response, next: NextFunction) => {
    try {
      const data = await this.studentService.getStudentDetails(req.params.id, req.instituteId!);
      const safeData = this.isTeacherRequest(req)
        ? this.sanitizeStudentsPayloadForTeacher(data)
        : data;
      return sendResponse({ res, data: safeData, message: 'Student details fetched successfully' });
    } catch (error) { next(error); }
  };

  update = async (req: Request, res: Response, next: NextFunction) => {
    try {
      const data = await this.studentService.updateStudent(req.params.id, req.instituteId!, req.body);
      return sendResponse({ res, data, message: 'Student updated successfully' });
    } catch (error) { next(error); }
  };

  toggleStatus = async (req: Request, res: Response, next: NextFunction) => {
    try {
      const { is_active } = req.body;
      const data = await this.studentService.changeStatus(req.params.id, req.instituteId!, is_active);
      return sendResponse({ res, data, message: `Student ${is_active ? 'activated' : 'deactivated'} successfully` });
    } catch (error) { next(error); }
  };

  // ─── Self-service: /students/me ──────────────────────────

  getMe = async (req: Request, res: Response, next: NextFunction) => {
    try {
      const student = await (prisma.student as any).findFirst({
        where: { user_id: req.user!.userId, institute_id: req.instituteId! },
        include: {
          parent_students: { select: { relation: true, parent: { select: { name: true, phone: true } } } },
          student_batches: {
            where: { is_active: true },
            include: { batch: { select: { id: true, name: true, subject: true, room: true, start_time: true, end_time: true, days_of_week: true } } }
          }
        }
      });
      if (!student) throw new ApiError('Student profile not found', 404, 'NOT_FOUND');

      return sendResponse({ res, data: {
        ...student,
        batches: (student as any).student_batches.map((sb: any) => sb.batch)
      }, message: 'Student profile fetched' });
    } catch (error) { next(error); }
  };

  getDashboard = async (req: Request, res: Response, next: NextFunction) => {
    try {
      const student = await prisma.student.findFirst({
        where: { user_id: req.user!.userId, institute_id: req.instituteId! }
      });
      if (!student) throw new ApiError('Student not found', 404, 'NOT_FOUND');

      const instituteId = req.instituteId!;
      const studentId = student.id;

      // Run aggregations in parallel
      const [
        todayLectures,
        attendanceStats,
        upcomingExams,
        pendingFees,
        recentAnnouncements,
        pendingDoubts
      ] = await Promise.all([
        // Combined schedule for today (Recurring + One-off)
        (async () => {
          const nowLocal = new Date();
          const istOffsetMs = 5.5 * 60 * 60 * 1000;
          const targetIst = new Date(nowLocal.getTime() + istOffsetMs);
          const y = targetIst.getUTCFullYear();
          const m = targetIst.getUTCMonth();
          const d = targetIst.getUTCDate();

          const istTodayStart = new Date(Date.UTC(y, m, d) - istOffsetMs);
          const istTodayEnd = new Date(Date.UTC(y, m, d, 23, 59, 59, 999) - istOffsetMs);

          const actualsRaw = await prisma.lecture.findMany({
              where: {
                  batch: { student_batches: { some: { student_id: studentId, is_active: true } } },
                  is_active: true,
                  scheduled_at: { gte: istTodayStart, lte: istTodayEnd }
              },
              include: { teacher: { select: { name: true } }, batch: { select: { name: true } } }
          });

          const actuals = actualsRaw.map(l => {
              const start = l.scheduled_at;
              const duration = l.duration_minutes || 60;
              const end = start ? new Date(start.getTime() + duration * 60000) : null;
              const toIstStr = (d: Date | null) => {
                  if (!d) return 'TBA';
                  const date = d instanceof Date ? d : new Date(d);
                  if (isNaN(date.getTime())) return 'TBA';
                  const istOffsetMs = 5.5 * 60 * 60 * 1000;
                  const ist = new Date(date.getTime() + istOffsetMs);
                  const hh = ist.getUTCHours();
                  const mm = ist.getUTCMinutes().toString().padStart(2, '0');
                  const ampm = hh >= 12 ? 'PM' : 'AM';
                  const hh12 = hh % 12 || 12;
                  return `${hh12}:${mm} ${ampm}`;
              };
              return {
                  ...l,
                  batch_name: l.batch?.name,
                  teacher_name: l.teacher?.name,
                  start_time: toIstStr(start),
                  end_time: toIstStr(end),
                  is_recurring: false
              };
          });

          actuals.sort((a, b) => a.start_time.localeCompare(b.start_time));
          return actuals;
        })(),
        // Attendance summary (last 30 days)
        prisma.attendanceRecord.groupBy({
          by: ['status'],
          where: {
            student_id: studentId,
            institute_id: instituteId,
            session: { session_date: { gte: new Date(Date.now() - 30 * 24 * 60 * 60 * 1000) } }
          },
          _count: { status: true }
        }),
        // Upcoming exams
        prisma.exam.findMany({
          where: {
            institute_id: instituteId,
            exam_date: { gte: new Date() },
            batches: { some: { batch: { student_batches: { some: { student_id: studentId, is_active: true } } } } }
          },
          orderBy: { exam_date: 'asc' },
          take: 5
        }),
        // Pending fee records
        prisma.feeRecord.findMany({
          where: { student_id: studentId, institute_id: instituteId, status: 'pending' },
          orderBy: { due_date: 'asc' },
          take: 3
        }),
        // Recent announcements
        prisma.announcement.findMany({
          where: { institute_id: instituteId },
          orderBy: { created_at: 'desc' },
          take: 5
        }),
        // Pending doubts count
        prisma.doubt.count({
          where: { student_id: studentId, institute_id: instituteId, status: 'pending' }
        })
      ]);

      // Calculate attendance percentage
      const totalClasses = attendanceStats.reduce((sum, s) => sum + s._count.status, 0);
      const presentCount = attendanceStats.find(s => s.status === 'present')?._count.status || 0;
      const attendancePercentage = totalClasses > 0 ? Math.round((presentCount / totalClasses) * 100) : 0;

      // Calculate total pending fee amount
      const totalPendingFees = pendingFees.reduce((sum, f) => sum + Number(f.final_amount), 0);

      return sendResponse({
        res,
        data: {
          student: { id: student.id, name: student.name, phone: student.phone, photo_url: student.photo_url },
          today_schedule: todayLectures,
          stats: {
            attendance_percentage: attendancePercentage,
            total_classes_30d: totalClasses,
            present_30d: presentCount,
            pending_fees_total: totalPendingFees,
            pending_doubts: pendingDoubts,
            upcoming_exams_count: upcomingExams.length,
          },
          upcoming_exams: upcomingExams,
          pending_fees: pendingFees,
          announcements: recentAnnouncements,
        },
        message: 'Dashboard data fetched'
      });
    } catch (error) { next(error); }
  };

  getMyFees = async (req: Request, res: Response, next: NextFunction) => {
    try {
      const student = await prisma.student.findFirst({
        where: { user_id: req.user!.userId, institute_id: req.instituteId! }
      });
      if (!student) throw new ApiError('Student not found', 404, 'NOT_FOUND');

      const records = await prisma.feeRecord.findMany({
        where: { student_id: student.id, institute_id: req.instituteId! },
        include: {
          batch: { select: { name: true } },
          payments: { select: { amount_paid: true, payment_mode: true, paid_at: true, receipt_number: true } }
        },
        orderBy: [{ year: 'desc' }, { month: 'desc' }]
      });

      const totalPaid = records.reduce((sum, r) => {
        const paid = r.payments.reduce((s, p) => s + Number(p.amount_paid), 0);
        return sum + paid;
      }, 0);

      const totalPending = records
        .filter(r => r.status === 'pending')
        .reduce((sum, r) => sum + Number(r.final_amount), 0);

      return sendResponse({
        res,
        data: {
          summary: { total_paid: totalPaid, total_pending: totalPending, total_records: records.length },
          records
        },
        message: 'Fee records fetched'
      });
    } catch (error) { next(error); }
  };

  getMyResults = async (req: Request, res: Response, next: NextFunction) => {
    try {
      const student = await prisma.student.findFirst({
        where: { user_id: req.user!.userId, institute_id: req.instituteId! }
      });
      if (!student) throw new ApiError('Student not found', 404, 'NOT_FOUND');

      const { subject } = req.query;

      const results = await prisma.examResult.findMany({
        where: { 
          student_id: student.id, 
          institute_id: req.instituteId!,
          ...(subject ? { exam: { subject: subject as string } } : {})
        },
        include: {
          exam: { select: { title: true, subject: true, exam_date: true, total_marks: true } }
        },
        orderBy: { exam: { exam_date: 'desc' } }
      });

      return sendResponse({ res, data: results, message: 'Results fetched' });
    } catch (error) { next(error); }
  };

  getMyDoubts = async (req: Request, res: Response, next: NextFunction) => {
    try {
      const student = await prisma.student.findFirst({
        where: { user_id: req.user!.userId, institute_id: req.instituteId! }
      });
      if (!student) throw new ApiError('Student not found', 404, 'NOT_FOUND');

      const { subject, batchId } = req.query;

      try {
        const doubts = await prisma.doubt.findMany({
          where: { 
             student_id: student.id, 
             institute_id: req.instituteId!,
             ...(batchId ? { batch_id: batchId as string } : {}),
             ...(subject ? { subject: subject as string } : {})
          },
          include: {
            assigned_to: { select: { name: true } },
            batch: { select: { name: true } }
          },
          orderBy: { created_at: 'desc' }
        });
        return sendResponse({ res, data: doubts, message: 'Doubts fetched' });
      } catch (error) {
        if (!isLegacyColumnError(error, 'subject')) throw error;
        
        let query = `SELECT * FROM doubts WHERE student_id = $1 AND institute_id = $2`;
        const params: any[] = [student.id, req.instituteId!];
        
        if (batchId) {
          query += ` AND batch_id = $${params.length + 1}`;
          params.push(batchId);
        }
        
        query += ` ORDER BY created_at DESC`;
        
        const rawDoubts = await prisma.$queryRawUnsafe<any[]>(query, ...params);
        return sendResponse({ res, data: rawDoubts, message: 'Doubts fetched (legacy fallback)' });
      }
    } catch (error) { next(error); }
  };

  getMyBatches = async (req: Request, res: Response, next: NextFunction) => {
      try {
          const student = await prisma.student.findFirst({
              where: { user_id: req.user!.userId, institute_id: req.instituteId! },
          });
          if (!student) throw new ApiError('Student not found', 404, 'NOT_FOUND');

          const batches = await prisma.studentBatch.findMany({
              where: { student_id: student.id, institute_id: req.instituteId!, is_active: true },
              include: { batch: { include: { teacher: { select: { name: true } } } } }
          });

          // Fetch batch_meta to get subjects for each batch
          const institute = await prisma.institute.findUnique({
              where: { id: req.instituteId! },
              select: { settings: true },
          });
          const settings = (institute?.settings ?? {}) as Record<string, any>;
          const batchMetaMap = (settings['batch_meta'] ?? {}) as Record<string, any>;

          return sendResponse({ 
              res, 
              data: batches.map(sb => {
                  const meta = (batchMetaMap[sb.batch.id] ?? {}) as Record<string, any>;
                  return {
                      ...sb.batch,
                      teacher_name: sb.batch.teacher?.name,
                      subjects: Array.isArray(meta.subjects) ? meta.subjects : []
                  };
              }), 
              message: 'Batches fetched' 
          });
      } catch (error) { next(error); }
  };

  getMyLectures = async (req: Request, res: Response, next: NextFunction) => {
      try {
          const student = await prisma.student.findFirst({
              where: { user_id: req.user!.userId, institute_id: req.instituteId! },
              include: { student_batches: { where: { is_active: true } } }
          });
          if (!student) throw new ApiError('Student not found', 404, 'NOT_FOUND');

          const batchIds = student.student_batches.map(sb => sb.batch_id);

          const { subject, batchId } = req.query;

          const lectures = await prisma.lecture.findMany({
              where: {
                  batch_id: batchId ? (batchId as string) : { in: batchIds },
                  institute_id: req.instituteId!,
                  is_active: true,
                  link: { not: null },
                  ...(subject ? { subject: subject as string } : {})
              },
              include: { teacher: { select: { name: true } } },
              orderBy: { created_at: 'desc' }
          });

          return sendResponse({ 
              res, 
              data: lectures.map(l => ({...l, teacher_name: l.teacher?.name})), 
              message: 'Lectures fetched' 
          });
      } catch (error) { 
        if ((error as any)?.code === 'P2021' || (error as any)?.code === 'P2022') {
          return sendResponse({res, data: [], message: 'Lectures unavailable due to missing backend table. Array mocked.'});
        }
        next(error); 
      }
  };

  getTodaySchedule = async (req: Request, res: Response, next: NextFunction) => {
      try {
          const student = await prisma.student.findFirst({
              where: { user_id: req.user!.userId, institute_id: req.instituteId! },
              include: { 
                  student_batches: { 
                      where: { is_active: true },
                      include: {
                          batch: {
                              select: {
                                  id: true,
                                  name: true,
                                  subject: true,
                                  room: true,
                                  start_time: true,
                                  end_time: true,
                                  days_of_week: true,
                                  teacher: { select: { name: true } }
                              }
                          }
                      }
                  } 
              }
          });
          if (!student) throw new ApiError('Student not found', 404, 'NOT_FOUND');

          const batchIds = student.student_batches.map(sb => sb.batch_id);

          // NOTE: USER REQUESTED TO DELETE MOCK SCHEDULES AND MAKE IT REAL TIME.
          // We are removing the recurring batch placeholder logic. Only actual lectures show.
          
          const requestedDateStr = req.query.date as string | undefined;
          let startRange: Date;
          let endRange: Date;

          const baseDate = requestedDateStr ? new Date(requestedDateStr) : new Date();
          // We assume requestedDateStr gives the target date in UTC but we want that "day" in IST.
          // Get the local YYYY-MM-DD from the user's date string (or current date if current in IST)
          const istOffsetMs = 5.5 * 60 * 60 * 1000;
          const targetIst = new Date(baseDate.getTime() + (requestedDateStr ? 0 : istOffsetMs));
          
          const y = targetIst.getUTCFullYear();
          const m = targetIst.getUTCMonth();
          const d = targetIst.getUTCDate();
          
          startRange = new Date(Date.UTC(y, m, d) - istOffsetMs);
          endRange = new Date(Date.UTC(y, m, d, 23, 59, 59, 999) - istOffsetMs);

          const requestedBatchId = req.query.batch_id as string | undefined;
          const requestedSubject = req.query.subject as string | undefined;

          const actualLectures = await prisma.lecture.findMany({
              where: {
                  batch_id: requestedBatchId ? requestedBatchId : { in: batchIds },
                  institute_id: req.instituteId!,
                  is_active: true,
                  scheduled_at: { gte: startRange, lte: endRange },
                  ...(requestedSubject ? { subject: requestedSubject } : {})
              },
              include: {
                  teacher: { select: { name: true } },
                  batch: { select: { name: true } }
              },
              orderBy: { scheduled_at: 'asc' }
          });

          const localizedActuals = actualLectures.map(l => {
              const start = l.scheduled_at;
              const duration = l.duration_minutes || 60;
              const end = start ? new Date(start.getTime() + duration * 60000) : null;
              
              // Helper for IST display (assuming server might be UTC)
              const toIstStr = (d: Date | null) => {
                  if (!d) return '00:00';
                  // IST is UTC + 5:30
                  const ist = new Date(d.getTime() + (5.5 * 60 * 60 * 1000));
                  return `${ist.getUTCHours().toString().padStart(2, '0')}:${ist.getUTCMinutes().toString().padStart(2, '0')}`;
              };

              return {
                  ...l,
                  batch_name: l.batch?.name,
                  teacher_name: l.teacher?.name,
                  start_time: toIstStr(start),
                  end_time: toIstStr(end),
                  is_recurring: false
              };
          });

          localizedActuals.sort((a, b) => a.start_time.localeCompare(b.start_time));

          return sendResponse({ 
              res, 
              data: localizedActuals, 
              message: 'Schedule fetched' 
          });
      } catch (error) { next(error); }
  };

  getMyAttendance = async (req: Request, res: Response, next: NextFunction) => {
      try {
          const student = await prisma.student.findFirst({
              where: { user_id: req.user!.userId, institute_id: req.instituteId! }
          });
          if (!student) throw new ApiError('Student not found', 404, 'NOT_FOUND');

          const { batchId, subject } = req.query;

          const records = await prisma.attendanceRecord.findMany({
              where: { 
                  student_id: student.id, 
                  institute_id: req.instituteId!,
                  ...(batchId || subject ? { 
                      session: { 
                          ...(batchId ? { batch_id: batchId as string } : {}),
                          ...(subject ? { subject: subject as string } : {})
                      } 
                  } : {})
              },
              include: { session: { select: { session_date: true, batch: { select: { name: true } } } } },
              orderBy: { session: { session_date: 'desc' } }
          });

          const total = records.length;
          const present = records.filter(r => r.status === 'present').length;
          const percentage = total > 0 ? Math.round((present/total) * 100) : 0;

          return sendResponse({ 
              res, 
              data: {
                  summary: { total, present, percentage },
                  history: records 
              }, 
              message: 'Attendance fetched' 
          });
      } catch (error) { next(error); }
  };

  getUpcomingExams = async (req: Request, res: Response, next: NextFunction) => {
      try {
          const student = await prisma.student.findFirst({
              where: { user_id: req.user!.userId, institute_id: req.instituteId! },
              include: { student_batches: { select: { batch_id: true } } }
          });
          if (!student) throw new ApiError('Student not found', 404, 'NOT_FOUND');

          const batchIds = student.student_batches.map(sb => sb.batch_id);

          const exams = await prisma.exam.findMany({
              where: {
                  institute_id: req.instituteId!,
                  exam_date: { gte: new Date() },
                  batches: { some: { batch_id: { in: batchIds } } }
              },
              include: { batches: { select: { batch: { select: { name: true } } } } },
              orderBy: { exam_date: 'asc' }
          });

          return sendResponse({ 
              res, 
              data: exams.map(e => ({
                  ...e,
                  batches: e.batches.map(eb => eb.batch.name)
              })), 
              message: 'Upcoming exams fetched' 
          });
      } catch (error) { next(error); }
  };

  getMyPerformance = async (req: Request, res: Response, next: NextFunction) => {
      try {
          // Send back simple stats
          const student = await prisma.student.findFirst({
              where: { user_id: req.user!.userId, institute_id: req.instituteId! }
          });
          if (!student) throw new ApiError('Student not found', 404, 'NOT_FOUND');

          const results = await prisma.examResult.findMany({
              where: { student_id: student.id },
              include: { exam: true }
          });
          
          let totalScore = 0;
          let totalMax = 0;
          results.forEach(r => {
             if (r.marks_obtained && r.exam.total_marks) {
                 totalScore += Number(r.marks_obtained);
                 totalMax += r.exam.total_marks;
             }
          });

          return sendResponse({ 
              res, 
              data: {
                  overall_score: totalScore,
                  total_marks: totalMax,
                  percentage: totalMax > 0 ? Math.round((totalScore/totalMax)*100) : 0,
                  exams_taken: results.length
              }, 
              message: 'Performance fetched' 
          });
      } catch (error) { next(error); }
  };

  getFeeHistory = async (req: Request, res: Response, next: NextFunction) => {
      try {
          const student = await prisma.student.findFirst({
              where: { user_id: req.user!.userId, institute_id: req.instituteId! }
          });
          if (!student) throw new ApiError('Student not found', 404, 'NOT_FOUND');

          const records = await prisma.feeRecord.findMany({
              where: { student_id: student.id, institute_id: req.instituteId!, status: 'paid' },
              include: {
                  batch: { select: { name: true } },
                  payments: true
              },
              orderBy: { created_at: 'desc' }
          });

          return sendResponse({ res, data: records, message: 'Fee history fetched' });
      } catch (error) { next(error); }
  };

  getNotifications = async (req: Request, res: Response, next: NextFunction) => {
      try {
          const student = await prisma.student.findFirst({
              where: { user_id: req.user!.userId, institute_id: req.instituteId! },
              include: { student_batches: { select: { batch_id: true } } }
          });
          if (!student) throw new ApiError('Student not found', 404, 'NOT_FOUND');

          const batchIds = student.student_batches.map(sb => sb.batch_id);

          const announcements = await prisma.announcement.findMany({
              where: { 
                  institute_id: req.instituteId!,
                  OR: [
                      { target_batch_id: null },
                      { target_batch_id: { in: batchIds } }
                  ]
               },
              orderBy: { created_at: 'desc' },
              take: 20
          });

          return sendResponse({ res, data: announcements.map(a => ({
              id: a.id,
              title: a.title,
              message: a.body,
              type: 'announcement',
              date: a.created_at
          })), message: 'Notifications fetched' });
      } catch (error) { next(error); }
  };

  importStudents = async (req: Request, res: Response, next: NextFunction) => {
    try {
      if (!req.file) throw new ApiError('No file uploaded', 400, 'NO_FILE');
      const { batchId } = req.body;
      const result = await this.studentService.importExcel(req.instituteId!, req.file.buffer, batchId);
      return sendResponse({ res, data: result, message: 'Import process completed' });
    } catch (error) { next(error); }
  };

  // ── Lecture Progress ─────────────────────────────────────
  getLectureProgress = async (req: Request, res: Response, next: NextFunction) => {
    try {
      const student = await prisma.student.findFirst({
        where: { user_id: req.user!.userId, institute_id: req.instituteId! },
      });
      if (!student) throw new ApiError('Student not found', 404, 'NOT_FOUND');

      const progress = await prisma.lectureProgress.findMany({
        where: { student_id: student.id, institute_id: req.instituteId! },
        orderBy: { updated_at: 'desc' },
      });

      return sendResponse({ res, data: progress, message: 'Lecture progress fetched' });
    } catch (error) {
      if ((error as any)?.code === 'P2021') {
        return sendResponse({ res, data: [], message: 'Progress table not available yet' });
      }
      next(error);
    }
  };

  updateLectureProgress = async (req: Request, res: Response, next: NextFunction) => {
    try {
      const student = await prisma.student.findFirst({
        where: { user_id: req.user!.userId, institute_id: req.instituteId! },
      });
      if (!student) throw new ApiError('Student not found', 404, 'NOT_FOUND');

      const { lecture_id, watched_sec, total_sec, last_position, is_completed } = req.body;
      if (!lecture_id) throw new ApiError('lecture_id is required', 400, 'MISSING_FIELD');

      const progress = await prisma.lectureProgress.upsert({
        where: {
          student_id_lecture_id: {
            student_id: student.id,
            lecture_id: lecture_id,
          },
        },
        create: {
          student_id: student.id,
          lecture_id: lecture_id,
          institute_id: req.instituteId!,
          watched_sec: watched_sec ?? 0,
          total_sec: total_sec ?? 0,
          last_position: last_position ?? 0,
          is_completed: is_completed ?? false,
        },
        update: {
          watched_sec: watched_sec ?? undefined,
          total_sec: total_sec ?? undefined,
          last_position: last_position ?? undefined,
          is_completed: is_completed ?? undefined,
        },
      });

      return sendResponse({ res, data: progress, message: 'Progress updated' });
    } catch (error) {
      if ((error as any)?.code === 'P2021') {
        return sendResponse({ res, data: null, message: 'Progress table not available yet' });
      }
      next(error);
    }
  };

  // ── Live Sessions ────────────────────────────────────────
  getActiveLiveSessions = async (req: Request, res: Response, next: NextFunction) => {
    try {
      const student = await prisma.student.findFirst({
        where: { user_id: req.user!.userId, institute_id: req.instituteId! },
        include: { student_batches: { where: { is_active: true } } },
      });
      if (!student) throw new ApiError('Student not found', 404, 'NOT_FOUND');

      const batchIds = student.student_batches.map(sb => sb.batch_id);

      // Find lectures that are 'live' type and scheduled within the last 4 hours
      const fourHoursAgo = new Date(Date.now() - 4 * 60 * 60 * 1000);
      const lectures = await prisma.lecture.findMany({
        where: {
          batch_id: { in: batchIds },
          institute_id: req.instituteId!,
          is_active: true,
          lecture_type: 'live',
          scheduled_at: { gte: fourHoursAgo },
        },
        include: {
          teacher: { select: { name: true } },
          batch: { select: { name: true } },
        },
        orderBy: { scheduled_at: 'desc' },
      });

      return sendResponse({
        res,
        data: lectures.map(l => ({
          ...l,
          teacher_name: l.teacher?.name,
          batch_name: l.batch?.name,
        })),
        message: 'Active live sessions fetched',
      });
    } catch (error) {
      if ((error as any)?.code === 'P2021' || (error as any)?.code === 'P2022') {
        return sendResponse({ res, data: [], message: 'Live sessions unavailable' });
      }
      next(error);
    }
  };

  getSyllabusTracker = async (req: Request, res: Response, next: NextFunction) => {
    try {
      const student = await prisma.student.findFirst({
        where: { user_id: req.user!.userId, institute_id: req.instituteId! },
        include: { student_batches: { where: { is_active: true } } },
      });
      if (!student) throw new ApiError('Student not found', 404, 'NOT_FOUND');

      const batchIds = student.student_batches.map(sb => sb.batch_id);

      const topics = await prisma.syllabusTopic.findMany({
        where: { batch_id: { in: batchIds }, institute_id: req.instituteId! },
        include: {
          student_progress: {
            where: { student_id: student.id }
          }
        }
      });

      let totalTopics = 0;
      let completedTopics = 0;
      const subjectsMap: Record<string, Record<string, { total: number, completed: number }>> = {};

      for (const t of topics) {
        const sub = t.subject || 'General';
        const chap = t.chapter_name || 'Uncategorized';
        if (!subjectsMap[sub]) subjectsMap[sub] = {};
        if (!subjectsMap[sub][chap]) subjectsMap[sub][chap] = { total: 0, completed: 0 };

        subjectsMap[sub][chap].total += 1;
        totalTopics += 1;

        const isCompleted = t.student_progress[0]?.is_completed || false;
        if (isCompleted) {
          subjectsMap[sub][chap].completed += 1;
          completedTopics += 1;
        }
      }

      const overall_progress = totalTopics > 0 ? (completedTopics / totalTopics) : 0;
      const subjects = Object.keys(subjectsMap);
      const chapters_by_subject: Record<string, any[]> = {};

      for (const sub of subjects) {
        chapters_by_subject[sub] = [];
        for (const chap of Object.keys(subjectsMap[sub])) {
          const stats = subjectsMap[sub][chap];
          chapters_by_subject[sub].push({
            title: chap,
            progress: stats.total > 0 ? stats.completed / stats.total : 0,
            topicsLeft: stats.total - stats.completed
          });
        }
      }

      return sendResponse({
        res,
        data: {
          overall_progress,
          subjects,
          chapters_by_subject
        },
        message: 'Syllabus tracker fetched'
      });
    } catch (error) {
      if ((error as any)?.code === 'P2021' || (error as any)?.code === 'P2022') {
        return sendResponse({ res, data: { overall_progress: 0, subjects: [], chapters_by_subject: {} }, message: 'Syllabus unavailable' });
      }
      next(error);
    }
  };
}

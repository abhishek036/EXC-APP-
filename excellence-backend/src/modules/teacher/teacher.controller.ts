import { Request, Response, NextFunction } from 'express';
import { TeacherService } from './teacher.service';
import { sendResponse } from '../../utils/response';
import { prisma } from '../../config/prisma';
import { ApiError } from '../../middleware/error.middleware';
import { emitBatchSync, emitInstituteDashboardSync } from '../../config/socket';
import { TimetableService } from '../timetable/timetable.service';
import { resolveTeacherScope } from '../../utils/teacher-scope';

export class TeacherController {
  private teacherService: TeacherService;
  private timetableService: TimetableService;

  constructor() {
    this.teacherService = new TeacherService();
    this.timetableService = new TimetableService();
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
      emitInstituteDashboardSync(req.instituteId!, 'teacher_removed', {
        teacher_id: req.params.id,
      });
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
      const teacherScope = await resolveTeacherScope(instituteId, req.user!.userId);
      const scopedBatchIds = teacherScope.batchIds;

      const batchesPromise = scopedBatchIds.length > 0
        ? prisma.batch.findMany({
            where: {
              id: { in: scopedBatchIds },
              institute_id: instituteId,
              is_active: true,
            },
            include: { _count: { select: { student_batches: { where: { is_active: true } } } } },
          })
        : Promise.resolve([]);

      const upcomingExamsPromise = scopedBatchIds.length > 0
        ? prisma.exam.findMany({
            where: {
              institute_id: instituteId,
              exam_date: { gte: new Date() },
              batches: { some: { batch_id: { in: scopedBatchIds } } },
            },
            orderBy: { exam_date: 'asc' },
            take: 3,
          })
        : Promise.resolve([]);

      const [
        batches,
        pendingDoubts,
        assignmentsToReview,
        quizAttempts,
        classesThisWeekCount,
        upcomingExams,
        recentQuizzes,
        todaySchedules
      ] = await Promise.all([
        // My batches (primary assignment + batch_meta teacher_ids)
        batchesPromise,
        // Pending doubts assigned to me
        prisma.doubt.count({
          where: { 
            institute_id: instituteId, 
            status: 'pending',
            OR: [
              { assigned_to_id: teacherId },
              ...(scopedBatchIds.length > 0 ? [{ batch_id: { in: scopedBatchIds } }] : []),
            ]
          }
        }),
        prisma.assignmentSubmission.count({
          where: {
            institute_id: instituteId,
            assignment: {
              teacher_id: teacherId,
            },
            status: 'submitted',
          },
        }),
        prisma.quizAttempt.count({
          where: {
            institute_id: instituteId,
            submitted_at: { not: null },
            quiz: {
              teacher_id: teacherId,
            },
          },
        }),
        // Classes taken this week
        prisma.attendanceSession.count({
          where: {
            teacher_id: teacherId,
            institute_id: instituteId,
            session_date: {
              gte: new Date(Date.now() - 7 * 24 * 60 * 60 * 1000)
            }
          }
        }),
        upcomingExamsPromise,
        prisma.quiz.findMany({
          where: {
            institute_id: instituteId,
            teacher_id: teacherId,
          },
          orderBy: { created_at: 'desc' },
          take: 3
        }),
        this.timetableService.getTeacherScheduleByUser(
          req.user!.userId,
          req.instituteId!
        )
      ]);

      const totalStudentsAcrossBatches = batches.reduce((sum, b) => sum + b._count.student_batches, 0);

      return sendResponse({
        res,
        data: {
          teacher: { id: teacher.id, name: teacher.name, subjects: teacher.subjects, photo_url: teacher.photo_url },
          batches: batches.map(b => {
            const formatTime = (d: Date | null | undefined) => {
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
              id: b.id,
              name: b.name,
              subject: b.subject,
              room: b.room,
              start_time: formatTime(b.start_time),
              end_time: formatTime(b.end_time),
              days_of_week: b.days_of_week,
              student_count: b._count.student_batches
            };
          }),
          schedules: todaySchedules,
          stats: {
            total_batches: batches.length,
            total_students: totalStudentsAcrossBatches,
            pending_doubts: pendingDoubts,
            assignments_to_review: assignmentsToReview,
            quiz_attempts: quizAttempts,
            classes_this_week: classesThisWeekCount
          },
          upcoming_exams: upcomingExams.map(e => ({
            id: e.id,
            title: e.title,
            subject: e.subject,
            exam_date: e.exam_date,
            total_marks: e.total_marks
          })),
          recent_quizzes: recentQuizzes.map(q => ({
            id: q.id,
            title: q.title,
            subject: q.subject,
            is_published: q.is_published,
            created_at: q.created_at
          }))
        },
        message: 'Teacher Dashboard Stats fetched'
      });
    } catch (error) { next(error); }
  };

  getBatchExecutionSummary = async (req: Request, res: Response, next: NextFunction) => {
    try {
      const teacher = await prisma.teacher.findFirst({
        where: { user_id: req.user!.userId, institute_id: req.instituteId! }
      });
      if (!teacher) throw new ApiError('Teacher not found', 404, 'NOT_FOUND');

      const batchId = req.params.batchId;
      const instituteId = req.instituteId!;
      const subject = req.query.subject as string | undefined;
      const teacherScope = await resolveTeacherScope(instituteId, req.user!.userId);

      if (!teacherScope.batchIds.includes(batchId)) {
        throw new ApiError('Batch not found for this teacher', 404, 'NOT_FOUND');
      }

      const batch = await prisma.batch.findFirst({
        where: {
          id: batchId,
          institute_id: instituteId,
          is_active: true,
        },
        include: {
          _count: {
            select: {
              student_batches: { where: { is_active: true } },
            },
          },
        },
      });
      if (!batch) throw new ApiError('Batch not found for this teacher', 404, 'NOT_FOUND');

      const activeLinks = await prisma.studentBatch.findMany({
        where: { batch_id: batchId, institute_id: instituteId, is_active: true },
        select: { student_id: true, student: { select: { id: true, name: true } } },
      });
      const studentIds = activeLinks.map((s) => s.student_id);

      const [
        topics,
        progressRows,
        lastLecture,
        assignmentSubmissions,
        pendingDoubts,
        quizzes,
        attempts,
        attendanceRecords,
      ] = await Promise.all([
        prisma.syllabusTopic.findMany({
          where: { 
            batch_id: batchId, 
            institute_id: instituteId,
            ...(subject ? { subject } : {})
          },
          orderBy: [{ chapter_name: 'asc' }, { order_index: 'asc' }],
          select: { id: true, chapter_name: true, topic_name: true, subject: true },
        }),
        prisma.studentSyllabusProgress.findMany({
          where: {
            institute_id: instituteId,
            is_completed: true,
            topic: { 
                batch_id: batchId,
                ...(subject ? { subject } : {})
            },
            ...(studentIds.length > 0 ? { student_id: { in: studentIds } } : {}),
          },
          select: { topic_id: true, student_id: true },
        }),
        prisma.lecture.findFirst({
          where: { 
              institute_id: instituteId, 
              batch_id: batchId,
              ...(subject ? { subject } : {})
          },
          orderBy: [{ scheduled_at: 'desc' }, { created_at: 'desc' }],
          select: { title: true, description: true, scheduled_at: true },
        }),
        prisma.assignmentSubmission.findMany({
          where: {
            institute_id: instituteId,
            assignment: {
              batch_id: batchId,
              teacher_id: teacher.id,
              ...(subject ? { subject } : {})
            },
          },
          orderBy: { submitted_at: 'desc' },
          take: 200,
          select: {
            id: true,
            status: true,
            submitted_at: true,
            assignment: { select: { due_date: true } },
          },
        }),
        prisma.doubt.findMany({
          where: { 
              institute_id: instituteId, 
              batch_id: batchId, 
              assigned_to_id: teacher.id, 
              status: 'pending',
              ...(subject ? { subject } : {})
          },
          orderBy: { created_at: 'desc' },
          take: 30,
          select: {
            id: true,
            question_text: true,
            question_img: true,
            status: true,
            created_at: true,
            student: { select: { id: true, name: true } },
          },
        }),
        prisma.quiz.findMany({
          where: { 
              institute_id: instituteId, 
              batch_id: batchId, 
              teacher_id: teacher.id,
              ...(subject ? { subject } : {})
          },
          orderBy: { created_at: 'desc' },
          select: { id: true, title: true, subject: true, created_at: true, is_published: true },
        }),
        prisma.quizAttempt.findMany({
          where: {
            institute_id: instituteId,
            quiz: { 
                batch_id: batchId, 
                teacher_id: teacher.id,
                ...(subject ? { subject } : {})
            },
            submitted_at: { not: null },
          },
          select: {
            obtained_marks: true,
            total_marks: true,
            student_id: true,
            student: { select: { id: true, name: true } },
            quiz: { select: { id: true, title: true } },
          },
        }),
        prisma.attendanceRecord.findMany({
          where: {
            institute_id: instituteId,
            session: { 
                batch_id: batchId,
                ...(subject ? { subject } : {})
            },
            ...(studentIds.length > 0 ? { student_id: { in: studentIds } } : {}),
          },
          select: { student_id: true, status: true },
        }),
      ]);

      const totalStudents = studentIds.length;
      const totalTopics = topics.length;

      const byTopic = new Map<string, Set<string>>();
      for (const row of progressRows) {
        const set = byTopic.get(row.topic_id) ?? new Set<string>();
        set.add(row.student_id);
        byTopic.set(row.topic_id, set);
      }

      const syllabusTopics = topics.map((topic) => {
        const completedStudents = byTopic.get(topic.id)?.size ?? 0;
        const completionPct = totalStudents > 0 ? Math.round((completedStudents / totalStudents) * 100) : 0;
        return {
          id: topic.id,
          chapter_name: topic.chapter_name,
          topic_name: topic.topic_name,
          subject: topic.subject,
          completed_students: completedStudents,
          completion_percent: completionPct,
        };
      });

      const overallProgress = totalTopics > 0
        ? Math.round(syllabusTopics.reduce((sum, topic) => sum + topic.completion_percent, 0) / totalTopics)
        : 0;

      const totalAttempts = attempts.length;
      const avgScore = totalAttempts > 0
        ? Number((attempts.reduce((sum, a) => sum + (a.obtained_marks ?? 0), 0) / totalAttempts).toFixed(2))
        : 0;

      let topper: { student_id: string; student_name: string; score: number; quiz_title: string } | null = null;
      for (const attempt of attempts) {
        const score = attempt.obtained_marks ?? 0;
        if (!topper || score > topper.score) {
          topper = {
            student_id: attempt.student_id,
            student_name: attempt.student.name,
            score,
            quiz_title: attempt.quiz.title,
          };
        }
      }

      const studentQuizAgg = new Map<string, { name: string; totalPct: number; count: number }>();
      for (const attempt of attempts) {
        const total = attempt.total_marks ?? 0;
        if (total <= 0) continue;
        const pct = ((attempt.obtained_marks ?? 0) / total) * 100;
        const current = studentQuizAgg.get(attempt.student_id) ?? { name: attempt.student.name, totalPct: 0, count: 0 };
        current.totalPct += pct;
        current.count += 1;
        studentQuizAgg.set(attempt.student_id, current);
      }
      const weakStudentsByTest = Array.from(studentQuizAgg.entries())
        .map(([studentId, agg]) => ({
          student_id: studentId,
          student_name: agg.name,
          average_percent: agg.count > 0 ? Number((agg.totalPct / agg.count).toFixed(2)) : 0,
        }))
        .filter((row) => row.average_percent < 40)
        .sort((a, b) => a.average_percent - b.average_percent)
        .slice(0, 10);

      const attendanceAgg = new Map<string, { total: number; presentLike: number }>();
      for (const record of attendanceRecords) {
        const current = attendanceAgg.get(record.student_id) ?? { total: 0, presentLike: 0 };
        current.total += 1;
        if (record.status === 'present' || record.status === 'late') current.presentLike += 1;
        attendanceAgg.set(record.student_id, current);
      }
      const lowAttendanceStudents = activeLinks
        .map((link) => {
          const agg = attendanceAgg.get(link.student_id) ?? { total: 0, presentLike: 0 };
          const percent = agg.total > 0 ? Number(((agg.presentLike / agg.total) * 100).toFixed(2)) : 0;
          return {
            student_id: link.student.id,
            student_name: link.student.name,
            attendance_percent: percent,
          };
        })
        .filter((row) => row.attendance_percent < 75)
        .sort((a, b) => a.attendance_percent - b.attendance_percent)
        .slice(0, 12);

      const pendingEvaluationCount = assignmentSubmissions.filter((s) => (s.status ?? 'submitted') == 'submitted').length;
      const lateAssignmentsCount = assignmentSubmissions.filter((s) => {
        if (!s.submitted_at) return false;
        const dueDate = s.assignment?.due_date;
        if (!dueDate) return false;
        return s.submitted_at > dueDate;
      }).length;

      return sendResponse({
        res,
        data: {
          batch: {
            id: batch.id,
            name: batch.name,
            subject: batch.subject,
            room: batch.room,
            start_time: batch.start_time,
            end_time: batch.end_time,
            days_of_week: batch.days_of_week,
            student_count: batch._count.student_batches,
          },
          overview: {
            teaching_progress_percent: overallProgress,
            total_topics: totalTopics,
            last_lecture: lastLecture
              ? {
                  ...lastLecture,
                  subject: batch.subject,
                }
              : null,
            upcoming_class_time: batch.start_time,
          },
          syllabus: {
            topics: syllabusTopics,
          },
          assignments: {
            pending_evaluation_count: pendingEvaluationCount,
            late_submissions_count: lateAssignmentsCount,
          },
          tests: {
            total_quizzes: quizzes.length,
            avg_score: avgScore,
            topper,
            weak_students: weakStudentsByTest,
          },
          attendance: {
            low_attendance_students: lowAttendanceStudents,
          },
          doubts: {
            pending_count: pendingDoubts.length,
            pending_items: pendingDoubts,
          },
        },
        message: 'Teacher batch execution summary fetched',
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
      const teacherScope = await resolveTeacherScope(instituteId, req.user!.userId);
      const scopedBatchIds = teacherScope.batchIds;

      const totalScheduledPromise = scopedBatchIds.length > 0
        ? prisma.batch.count({
            where: {
              id: { in: scopedBatchIds },
              institute_id: instituteId,
              is_active: true,
            },
          })
        : Promise.resolve(0);

      const [classesTaken, doubtsResolved, totalScheduled] = await Promise.all([
        prisma.attendanceSession.count({
          where: { teacher_id: teacher.id, institute_id: instituteId, session_date: { gte: weekAgo } }
        }),
        prisma.doubt.count({
          where: { assigned_to_id: teacher.id, institute_id: instituteId, status: 'resolved', resolved_at: { gte: weekAgo } }
        }),
        // Total scheduled = batches * days active this week (simplified)
        totalScheduledPromise,
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

      const teacherScope = await resolveTeacherScope(req.instituteId!, req.user!.userId);
      if (teacherScope.batchIds.length === 0) {
        return sendResponse({
          res,
          data: [],
          message: 'Batches fetched',
        });
      }

      const batches = await prisma.batch.findMany({
        where: {
          id: { in: teacherScope.batchIds },
          institute_id: req.instituteId!,
          is_active: true,
        },
        include: { _count: { select: { student_batches: { where: { is_active: true } } } } }
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
         data: batches.map(b => {
             const meta = (batchMetaMap[b.id] ?? {}) as Record<string, any>;
             return {
                 ...b,
                 student_count: b._count.student_batches,
                 subjects: Array.isArray(meta.subjects) ? meta.subjects : []
             };
         }), 
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

        const teacherScope = await resolveTeacherScope(req.instituteId!, req.user!.userId);
        const scopedBatchIds = teacherScope.batchIds;

        const now = new Date();
        // Standardize IST Day: 1=Mon, 7=Sun
        const istDate = new Date(now.getTime() + (5.5 * 60 * 60 * 1000));
        const dayIndex = istDate.getUTCDay();
        const dayMapping = dayIndex === 0 ? 7 : dayIndex;
        
        // 1. Recurring schedules
        const recurringBatches = scopedBatchIds.length > 0
          ? await prisma.batch.findMany({
              where: {
                id: { in: scopedBatchIds },
                institute_id: req.instituteId!,
                is_active: true,
                days_of_week: { has: dayMapping },
              },
            })
          : [];

        // Use standard time formatting
        const formatRawTime = (date: Date | null) => {
            if (!date) return '00:00';
            return `${date.getUTCHours().toString().padStart(2, '0')}:${date.getUTCMinutes().toString().padStart(2, '0')}`;
        };

        const formattedRecurring = recurringBatches.map(b => ({
            id: `recurring-${b.id}-${dayMapping}`,
            batch_id: b.id,
            name: b.name,
            subject: b.subject,
            start_time: formatRawTime(b.start_time),
            end_time: formatRawTime(b.end_time),
            room: b.room || 'Online',
            is_recurring: true
        }));

        // 2. One-off Lecture records
        const istTodayStart = new Date(new Date(now).setHours(0, 0, 0, 0));
        const istTodayEnd = new Date(new Date(now).setHours(23, 59, 59, 999));

        const actualLectures = await prisma.lecture.findMany({
            where: {
                teacher_id: teacher.id,
                institute_id: req.instituteId!,
                is_active: true,
                scheduled_at: { gte: istTodayStart, lte: istTodayEnd }
            },
            include: { batch: { select: { name: true, subject: true } } }
        });

        const formattedActuals = actualLectures.map(l => {
            const start = l.scheduled_at;
            const duration = l.duration_minutes || 60;
            const end = start ? new Date(start.getTime() + duration * 60000) : null;
            
            const toIstStr = (d: Date | null) => {
                if (!d) return '00:00';
                const ist = new Date(d.getTime() + (5.5 * 60 * 60 * 1000));
                return `${ist.getUTCHours().toString().padStart(2, '0')}:${ist.getUTCMinutes().toString().padStart(2, '0')}`;
            };

            return {
                id: l.id,
                batch_id: l.batch_id,
                name: l.batch?.name || l.title || 'Untitled Lecture',
                subject: l.batch?.subject || l.subject || 'Subject',
                start_time: toIstStr(start),
                end_time: toIstStr(end),
                room: l.class_room || 'Online',
                is_recurring: false
            };
        });

        // 3. Merging (Deduplication)
        const merged: any[] = [...formattedActuals];
        for (const rec of formattedRecurring) {
            const hasOverride = formattedActuals.some(act => 
                act.batch_id === rec.batch_id && act.start_time === rec.start_time
            );
            if (!hasOverride) {
                merged.push(rec);
            }
        }

        merged.sort((a, b) => a.start_time.localeCompare(b.start_time));

        return sendResponse({ res, data: merged, message: 'Today schedule fetched' });
      } catch (error) { next(error); }
  };

  updateSyllabusTopicStatus = async (req: Request, res: Response, next: NextFunction) => {
    try {
      const teacher = await prisma.teacher.findFirst({
        where: { user_id: req.user!.userId, institute_id: req.instituteId! }
      });
      if (!teacher) throw new ApiError('Teacher not found', 404, 'NOT_FOUND');

      const { batchId, topicId } = req.params;
      const { is_completed } = req.body;
      const instituteId = req.instituteId!;
      const teacherScope = await resolveTeacherScope(instituteId, req.user!.userId);

      if (!teacherScope.batchIds.includes(batchId)) {
        throw new ApiError('Batch not found or unauthorized', 404, 'NOT_FOUND');
      }

      // 1. Verify batch belongs to teacher
      const batch = await prisma.batch.findFirst({
        where: { id: batchId, institute_id: instituteId }
      });
      if (!batch) throw new ApiError('Batch not found or unauthorized', 404, 'NOT_FOUND');

      // 2. Get all students in the batch
      const studentBatches = await prisma.studentBatch.findMany({
        where: { batch_id: batchId, institute_id: instituteId, is_active: true },
        select: { student_id: true }
      });
      const studentIds = studentBatches.map(sb => sb.student_id);

      // 3. Update or create progress for each student
      if (is_completed) {
        // Mark as completed for all students
        await Promise.all(studentIds.map(studentId => 
          prisma.studentSyllabusProgress.upsert({
            where: { student_id_topic_id: { student_id: studentId, topic_id: topicId } },
            update: { is_completed: true, completed_at: new Date() },
            create: { 
              student_id: studentId, 
              topic_id: topicId, 
              institute_id: instituteId, 
              is_completed: true, 
              completed_at: new Date() 
            }
          })
        ));
      } else {
        // Mark as not completed for all students
        await prisma.studentSyllabusProgress.updateMany({
          where: { 
            topic_id: topicId, 
            student_id: { in: studentIds },
            institute_id: instituteId 
          },
          data: { is_completed: false, completed_at: null }
        });
      }

        emitBatchSync(instituteId, batchId, 'syllabus_topic_status_changed', {
          topic_id: topicId,
          is_completed: !!is_completed,
        });

      return sendResponse({ res, data: { success: true }, message: `Topic status updated for ${studentIds.length} students` });
    } catch (error) { next(error); }
  };
}

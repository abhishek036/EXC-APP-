import { ParentRepository } from './parent.repository';
import { prisma } from '../../config/prisma';
import { ApiError } from '../../middleware/error.middleware';
import { ATTENDANCE_PRESENT_STATUSES, calculateFeeAmounts, normalizeStatus } from '../../utils/metrics';

// Circular dependency safe require
let FeeRepoClass: any = null;
const getFeeRepo = () => {
  if (!FeeRepoClass) {
    FeeRepoClass = require('../fee/fee.repository').FeeRepository;
  }
  return new FeeRepoClass();
};

type ParentStudentLite = {
  id: string;
  name: string;
  phone?: string | null;
  student_batches?: Array<{
    batch_id: string;
    batch?: {
      id: string;
      name: string;
      subject?: string | null;
      teacher?: { name: string } | null;
    } | null;
  }>;
};

export class ParentService {
  private parentRepo: ParentRepository;

  constructor() {
    this.parentRepo = new ParentRepository();
  }

  private toNumber(value: unknown): number {
    if (typeof value === 'number') return value;
    if (typeof value === 'string') {
      const parsed = Number(value);
      return Number.isFinite(parsed) ? parsed : 0;
    }
    if (value && typeof value === 'object' && 'toString' in (value as Record<string, unknown>)) {
      const parsed = Number((value as { toString: () => string }).toString());
      return Number.isFinite(parsed) ? parsed : 0;
    }
    return 0;
  }

  private toDateKey(date: Date): string {
    return date.toISOString().split('T')[0];
  }

  private safePercent(obtained: number, total: number): number {
    if (!Number.isFinite(total) || total <= 0) return 0;
    return Math.max(0, Math.min(100, Math.round((obtained / total) * 100)));
  }

  private async resolveParentContext(userId: string, instituteId: string) {
    const user = await prisma.user.findFirst({
      where: { id: userId, institute_id: instituteId },
      select: { phone: true },
    });

    const parent = await this.parentRepo.findParentByUserIdOrPhone(userId, instituteId, user?.phone);
    if (!parent) {
      return { parent: null, students: [] as ParentStudentLite[] };
    }

    const students = (await this.parentRepo.getParentStudents(instituteId, parent.id)) as ParentStudentLite[];
    return { parent, students };
  }

  private async resolveLinkedChild(userId: string, instituteId: string, childId: string) {
    const { parent, students } = await this.resolveParentContext(userId, instituteId);
    if (!parent) {
      throw new ApiError('Parent profile not found', 404, 'NOT_FOUND');
    }

    const child = students.find((student) => student.id === childId) ?? null;
    if (!child) {
      throw new ApiError('Unauthorized or child not found', 403, 'FORBIDDEN');
    }

    return { parent, child, students };
  }

  private noLinkPayload(parent: any = null) {
    return {
      linked: false,
      message: 'No student linked to this account',
      action: 'Contact coaching',
      parent: parent ? { id: parent.id, name: parent.name, phone: parent.phone } : null,
      children: [],
      todaySchedule: [],
      upcomingExams: [],
      pendingFees: [],
      pendingAssignments: [],
      quizHighlights: [],
      testHighlights: [],
      activityFeed: [],
      announcements: [],
    };
  }

  async getDashboardData(userId: string, instituteId: string) {
    const { parent, students } = await this.resolveParentContext(userId, instituteId);
    if (!parent || students.length === 0) {
      return this.noLinkPayload(parent);
    }

    const studentIds = students.map((student) => student.id);
    const studentBatchMap = new Map<string, Set<string>>();
    const allBatchIds = new Set<string>();

    for (const student of students) {
      const batchIds = new Set<string>();
      for (const sb of student.student_batches ?? []) {
        if (sb.batch_id) {
          batchIds.add(sb.batch_id);
          allBatchIds.add(sb.batch_id);
        }
      }
      studentBatchMap.set(student.id, batchIds);
    }

    // Auto-sync fees for all children to ensure up to date records
    try {
      const feeRepo = getFeeRepo();
      for (const student of students) {
        await feeRepo.autoSyncStudentFees(instituteId, student.id);
      }
    } catch (e: any) {
      console.error('[ParentService] Dashboard fee auto-sync skipped:', e.message);
    }

    const now = new Date();
    const thirtyDaysAgo = new Date(now.getTime() - 30 * 24 * 60 * 60 * 1000);
    const twoWeeksAhead = new Date(now.getTime() + 14 * 24 * 60 * 60 * 1000);
    const todayStart = new Date(now.getFullYear(), now.getMonth(), now.getDate());
    const todayEnd = new Date(now.getFullYear(), now.getMonth(), now.getDate(), 23, 59, 59, 999);

    const [
      attendanceRows,
      todayAttendanceRows,
      upcomingLectures,
      upcomingExams,
      feeRecords,
      quizAttempts,
      examResults,
      assignments,
      recentSubmissions,
      announcements,
    ] = await Promise.all([
      prisma.attendanceRecord.findMany({
        where: {
          institute_id: instituteId,
          student_id: { in: studentIds },
          session: { session_date: { gte: thirtyDaysAgo } },
        },
        select: {
          student_id: true,
          status: true,
          session: { select: { session_date: true } },
        },
        orderBy: { session: { session_date: 'desc' } },
        take: 500,
      }),
      prisma.attendanceRecord.findMany({
        where: {
          institute_id: instituteId,
          student_id: { in: studentIds },
          session: { session_date: { gte: todayStart, lte: todayEnd } },
        },
        select: {
          student_id: true,
          status: true,
        },
      }),
      prisma.lecture.findMany({
        where: {
          institute_id: instituteId,
          is_active: true,
          batch_id: { in: Array.from(allBatchIds) },
          scheduled_at: { gte: now, lte: twoWeeksAhead },
        },
        select: {
          id: true,
          title: true,
          subject: true,
          scheduled_at: true,
          duration_minutes: true,
          batch_id: true,
          batch: { select: { id: true, name: true } },
          teacher: { select: { name: true } },
        },
        orderBy: { scheduled_at: 'asc' },
        take: 40,
      }),
      prisma.exam.findMany({
        where: {
          institute_id: instituteId,
          exam_date: { gte: todayStart },
          batches: { some: { batch_id: { in: Array.from(allBatchIds) } } },
        },
        select: {
          id: true,
          title: true,
          subject: true,
          exam_date: true,
          total_marks: true,
          batches: {
            select: {
              batch_id: true,
              batch: { select: { name: true } },
            },
          },
        },
        orderBy: { exam_date: 'asc' },
        take: 20,
      }),
      prisma.feeRecord.findMany({
        where: {
          institute_id: instituteId,
          student_id: { in: studentIds },
        },
        select: {
          id: true,
          student_id: true,
          month: true,
          year: true,
          final_amount: true,
          paid_amount: true,
          status: true,
          due_date: true,
          batch: { select: { id: true, name: true } },
          student: { select: { name: true } },
        },
        orderBy: { due_date: 'asc' },
        take: 200,
      }),
      prisma.quizAttempt.findMany({
        where: {
          institute_id: instituteId,
          student_id: { in: studentIds },
          submitted_at: { not: null },
        },
        select: {
          student_id: true,
          obtained_marks: true,
          total_marks: true,
          submitted_at: true,
          quiz: {
            select: {
              title: true,
              subject: true,
              scheduled_at: true,
            },
          },
          student: { select: { name: true } },
        },
        orderBy: { submitted_at: 'desc' },
        take: 30,
      }),
      prisma.examResult.findMany({
        where: {
          institute_id: instituteId,
          student_id: { in: studentIds },
        },
        select: {
          student_id: true,
          marks_obtained: true,
          is_absent: true,
          exam: {
            select: {
              title: true,
              subject: true,
              exam_date: true,
              total_marks: true,
            },
          },
          student: { select: { name: true } },
        },
        orderBy: { exam: { exam_date: 'desc' } },
        take: 30,
      }),
      prisma.assignment.findMany({
        where: {
          institute_id: instituteId,
          batch_id: { in: Array.from(allBatchIds) },
        },
        select: {
          id: true,
          title: true,
          subject: true,
          due_date: true,
          batch_id: true,
          batch: { select: { name: true } },
          submissions: {
            where: {
              student_id: { in: studentIds },
              is_latest: true,
            },
            select: {
              student_id: true,
              status: true,
              is_draft: true,
              submitted_at: true,
            },
          },
        },
        orderBy: { due_date: 'asc' },
        take: 120,
      }),
      prisma.assignmentSubmission.findMany({
        where: {
          institute_id: instituteId,
          student_id: { in: studentIds },
          is_latest: true,
          submitted_at: { not: null },
        },
        select: {
          student_id: true,
          status: true,
          submitted_at: true,
          assignment: {
            select: {
              title: true,
              subject: true,
            },
          },
          student: { select: { name: true } },
        },
        orderBy: { submitted_at: 'desc' },
        take: 30,
      }),
      prisma.announcement.findMany({
        where: { institute_id: instituteId },
        orderBy: { created_at: 'desc' },
        take: 5,
      }),
    ]);

    const attendanceSummary = new Map<string, { total: number; present: number }>();
    for (const row of attendanceRows) {
      const current = attendanceSummary.get(row.student_id) ?? { total: 0, present: 0 };
      const isPresent = ATTENDANCE_PRESENT_STATUSES.has(normalizeStatus(row.status));
      current.total += 1;
      if (isPresent) current.present += 1;
      attendanceSummary.set(row.student_id, current);
    }

    const todayAttendance = new Map<string, string>();
    for (const row of todayAttendanceRows) {
      const status = normalizeStatus(row.status);
      if (ATTENDANCE_PRESENT_STATUSES.has(status)) {
        todayAttendance.set(row.student_id, 'present');
      } else if (!todayAttendance.has(row.student_id)) {
        todayAttendance.set(row.student_id, status || 'unknown');
      }
    }

    const pendingFeeByStudent = new Map<string, number>();
    const firstPendingRecordIdByStudent = new Map<string, string>();
    const pendingFees = feeRecords
      .map((record) => {
        const metrics = calculateFeeAmounts(record.final_amount, record.paid_amount, record.status);

        if (metrics.is_pending) {
          pendingFeeByStudent.set(
            record.student_id,
            (pendingFeeByStudent.get(record.student_id) ?? 0) + metrics.remaining_amount,
          );
          if (!firstPendingRecordIdByStudent.has(record.student_id)) {
            firstPendingRecordIdByStudent.set(record.student_id, record.id);
          }
        }

        return {
          ...record,
          ...metrics,
        };
      })
      .filter((record) => record.is_pending)
      .slice(0, 20);

    const quizScoreByStudent = new Map<string, { sum: number; count: number }>();
    const quizHighlights = quizAttempts.map((attempt) => {
      const obtained = this.toNumber(attempt.obtained_marks);
      const total = this.toNumber(attempt.total_marks);
      const percent = this.safePercent(obtained, total);
      const acc = quizScoreByStudent.get(attempt.student_id) ?? { sum: 0, count: 0 };
      acc.sum += percent;
      acc.count += 1;
      quizScoreByStudent.set(attempt.student_id, acc);

      return {
        student_id: attempt.student_id,
        student_name: attempt.student?.name ?? 'Student',
        title: attempt.quiz?.title ?? 'Quiz',
        subject: attempt.quiz?.subject ?? '',
        submitted_at: attempt.submitted_at,
        percentage: percent,
      };
    });

    const testScoreByStudent = new Map<string, { sum: number; count: number }>();
    const testHighlights = examResults.map((result) => {
      const obtained = this.toNumber(result.marks_obtained);
      const total = this.toNumber(result.exam?.total_marks);
      const percent = this.safePercent(obtained, total);
      const acc = testScoreByStudent.get(result.student_id) ?? { sum: 0, count: 0 };
      acc.sum += percent;
      acc.count += 1;
      testScoreByStudent.set(result.student_id, acc);

      return {
        student_id: result.student_id,
        student_name: result.student?.name ?? 'Student',
        title: result.exam?.title ?? 'Test',
        subject: result.exam?.subject ?? '',
        exam_date: result.exam?.exam_date,
        percentage: percent,
        is_absent: result.is_absent === true,
      };
    });

    const upcomingClassesByStudent = new Map<string, number>();
    const todaySchedule = upcomingLectures.map((lecture) => {
      const linkedStudents = students.filter((student) =>
        (studentBatchMap.get(student.id) ?? new Set<string>()).has(lecture.batch_id),
      );

      for (const student of linkedStudents) {
        upcomingClassesByStudent.set(student.id, (upcomingClassesByStudent.get(student.id) ?? 0) + 1);
      }

      return {
        id: lecture.id,
        name: lecture.title,
        subject: lecture.subject,
        start_time: lecture.scheduled_at,
        duration_minutes: lecture.duration_minutes,
        teacher_name: lecture.teacher?.name ?? 'Teacher',
        batch_name: lecture.batch?.name ?? 'Batch',
        student_name: linkedStudents.map((student) => student.name).join(', '),
      };
    });

    const upcomingExamsByStudent = new Map<string, number>();
    const mappedUpcomingExams = upcomingExams.map((exam) => {
      const examBatchIds = new Set(exam.batches.map((batch) => batch.batch_id));
      const linkedStudents = students.filter((student) => {
        const studentBatchIds = studentBatchMap.get(student.id) ?? new Set<string>();
        for (const batchId of studentBatchIds) {
          if (examBatchIds.has(batchId)) return true;
        }
        return false;
      });

      for (const student of linkedStudents) {
        upcomingExamsByStudent.set(student.id, (upcomingExamsByStudent.get(student.id) ?? 0) + 1);
      }

      return {
        id: exam.id,
        title: exam.title,
        subject: exam.subject,
        exam_date: exam.exam_date,
        total_marks: exam.total_marks,
        batch_names: exam.batches.map((batch) => batch.batch?.name).filter(Boolean),
        student_names: linkedStudents.map((student) => student.name),
      };
    });

    const pendingAssignmentCount = new Map<string, number>();
    const submittedAssignmentCount = new Map<string, number>();
    const pendingAssignments: Array<{
      assignment_id: string;
      title: string;
      subject: string | null;
      due_date: Date | null;
      batch_name: string;
      student_id: string;
      student_name: string;
      status: string;
    }> = [];

    for (const assignment of assignments) {
      for (const student of students) {
        const studentBatchIds = studentBatchMap.get(student.id) ?? new Set<string>();
        if (!studentBatchIds.has(assignment.batch_id)) continue;

        const submission = assignment.submissions.find((item) => item.student_id === student.id);
        const submissionStatus = (submission?.status ?? '').toString().toLowerCase();
        const isSubmitted = Boolean(submission && submission.is_draft !== true && submissionStatus !== 'draft');

        if (isSubmitted) {
          submittedAssignmentCount.set(student.id, (submittedAssignmentCount.get(student.id) ?? 0) + 1);
          continue;
        }

        pendingAssignmentCount.set(student.id, (pendingAssignmentCount.get(student.id) ?? 0) + 1);
        pendingAssignments.push({
          assignment_id: assignment.id,
          title: assignment.title,
          subject: assignment.subject,
          due_date: assignment.due_date,
          batch_name: assignment.batch?.name ?? 'Batch',
          student_id: student.id,
          student_name: student.name,
          status: submissionStatus || 'pending',
        });
      }
    }

    const activityFeed = [
      ...quizHighlights.map((item) => ({
        type: 'quiz',
        title: `${item.student_name} scored ${item.percentage}% in ${item.title}`,
        subtitle: item.subject || 'Quiz update',
        timestamp: item.submitted_at,
      })),
      ...testHighlights.map((item) => ({
        type: 'test',
        title: `${item.student_name} scored ${item.percentage}% in ${item.title}`,
        subtitle: item.subject || 'Test result',
        timestamp: item.exam_date,
      })),
      ...recentSubmissions.map((item) => ({
        type: 'assignment',
        title: `${item.student?.name ?? 'Student'} submitted ${item.assignment?.title ?? 'an assignment'}`,
        subtitle: (item.assignment?.subject ?? 'Assignment').toString(),
        timestamp: item.submitted_at,
      })),
    ]
      .filter((item) => item.timestamp)
      .sort((a, b) => new Date(b.timestamp as Date).getTime() - new Date(a.timestamp as Date).getTime())
      .slice(0, 20);

    const children = students.map((student) => {
      const attendance = attendanceSummary.get(student.id) ?? { total: 0, present: 0 };
      const attendancePercent = attendance.total > 0
        ? Math.round((attendance.present / attendance.total) * 100)
        : 0;
      const quizStats = quizScoreByStudent.get(student.id) ?? { sum: 0, count: 0 };
      const testStats = testScoreByStudent.get(student.id) ?? { sum: 0, count: 0 };

      return {
        id: student.id,
        name: student.name,
        attendance: attendancePercent,
        todayAttendance: todayAttendance.get(student.id) ?? 'not_marked',
        pendingFee: pendingFeeByStudent.get(student.id) ?? 0,
        pendingFeeRecordId: firstPendingRecordIdByStudent.get(student.id) ?? null,
        avgQuizScore: quizStats.count > 0 ? Math.round(quizStats.sum / quizStats.count) : 0,
        avgTestScore: testStats.count > 0 ? Math.round(testStats.sum / testStats.count) : 0,
        pendingAssignments: pendingAssignmentCount.get(student.id) ?? 0,
        submittedAssignments: submittedAssignmentCount.get(student.id) ?? 0,
        upcomingClasses: upcomingClassesByStudent.get(student.id) ?? 0,
        upcomingExams: upcomingExamsByStudent.get(student.id) ?? 0,
        batches: (student.student_batches ?? [])
          .map((item) => item.batch)
          .filter((batch): batch is NonNullable<typeof batch> => Boolean(batch)),
      };
    });

    return {
      linked: true,
      parent: { id: parent.id, name: parent.name, phone: parent.phone },
      children,
      todaySchedule,
      upcomingExams: mappedUpcomingExams,
      pendingFees,
      pendingAssignments: pendingAssignments.slice(0, 15),
      quizHighlights: quizHighlights.slice(0, 10),
      testHighlights: testHighlights.slice(0, 10),
      activityFeed,
      announcements,
    };
  }

  async getParentStudents(userId: string, instituteId: string) {
    const { students } = await this.resolveParentContext(userId, instituteId);
    return students;
  }

  async getMyChildren(userId: string, instituteId: string) {
    return this.getParentStudents(userId, instituteId);
  }

  async getPaymentHistory(userId: string, instituteId: string) {
    const students = await this.getParentStudents(userId, instituteId);
    const studentIds = students.map((s: ParentStudentLite) => s.id);
    if (!studentIds.length) return [];

    try {
      const feeRepo = getFeeRepo();
      for (const id of studentIds) {
        await feeRepo.autoSyncStudentFees(instituteId, id);
      }
    } catch (e: any) {
      console.error('[ParentService] Payment history fee auto-sync skipped:', e.message);
    }

    const records = await prisma.feeRecord.findMany({
      where: { student_id: { in: studentIds }, institute_id: instituteId },
      include: {
        student: { select: { id: true, name: true } },
        batch: { select: { id: true, name: true } },
        payments: {
          orderBy: { submitted_at: 'desc' },
        },
      },
      orderBy: [
        { year: 'desc' },
        { month: 'desc' },
      ],
    });

    return records.map((record) => {
      const metrics = calculateFeeAmounts(record.final_amount, record.paid_amount, record.status);
      const latestRejectedPayment = (record.payments ?? []).find(
        (payment) => (payment.status ?? '').toString().toLowerCase() === 'rejected',
      );
      const latestRejectionReason = latestRejectedPayment?.rejection_reason?.toString().trim() || null;

      return {
        ...record,
        ...metrics,
        final_amount: metrics.final_amount,
        paid_amount: metrics.paid_amount,
        remaining_amount: metrics.remaining_amount,
        latest_rejection_reason: latestRejectionReason,
        latest_rejected_at: latestRejectedPayment?.rejected_at ?? null,
      };
    });
  }

  async getChildReport(userId: string, childId: string, instituteId: string) {
    await this.resolveLinkedChild(userId, instituteId, childId);

    const student = await prisma.student.findFirst({
      where: { id: childId, institute_id: instituteId },
      select: {
        id: true,
        name: true,
        phone: true,
        student_code: true,
        is_active: true,
        student_batches: {
          where: { is_active: true },
          select: {
            batch_id: true,
            batch: {
              select: {
                id: true,
                name: true,
                subject: true,
                teacher: { select: { name: true } },
              },
            },
          },
        },
      },
    });

    if (!student) {
      throw new ApiError('Student not found', 404, 'NOT_FOUND');
    }

    const batchIds = student.student_batches.map((item) => item.batch_id);
    const now = new Date();
    const thirtyDaysAgo = new Date(now.getTime() - 30 * 24 * 60 * 60 * 1000);
    const sixtyDaysAgo = new Date(now.getTime() - 60 * 24 * 60 * 60 * 1000);
    const twoWeeksAhead = new Date(now.getTime() + 14 * 24 * 60 * 60 * 1000);

    const [attendanceRows, examResults, quizAttempts, feeRecords, upcomingSchedule, assignments, recentSubmissions] =
      await Promise.all([
        prisma.attendanceRecord.findMany({
          where: {
            student_id: childId,
            institute_id: instituteId,
            session: { session_date: { gte: sixtyDaysAgo } },
          },
          select: {
            status: true,
            session: {
              select: {
                session_date: true,
                batch: { select: { name: true } },
              },
            },
          },
          orderBy: { session: { session_date: 'desc' } },
          take: 120,
        }),
        prisma.examResult.findMany({
          where: { student_id: childId, institute_id: instituteId },
          select: {
            marks_obtained: true,
            is_absent: true,
            exam: {
              select: {
                title: true,
                subject: true,
                exam_date: true,
                total_marks: true,
                passing_marks: true,
              },
            },
          },
          orderBy: { exam: { exam_date: 'desc' } },
          take: 12,
        }),
        prisma.quizAttempt.findMany({
          where: {
            student_id: childId,
            institute_id: instituteId,
            submitted_at: { not: null },
          },
          select: {
            obtained_marks: true,
            total_marks: true,
            submitted_at: true,
            rank: true,
            quiz: {
              select: {
                title: true,
                subject: true,
                scheduled_at: true,
              },
            },
          },
          orderBy: { submitted_at: 'desc' },
          take: 12,
        }),
        prisma.feeRecord.findMany({
          where: { student_id: childId, institute_id: instituteId },
          select: {
            id: true,
            month: true,
            year: true,
            final_amount: true,
            paid_amount: true,
            status: true,
            due_date: true,
            updated_at: true,
            batch: { select: { name: true } },
          },
          orderBy: { due_date: 'desc' },
          take: 18,
        }),
        prisma.lecture.findMany({
          where: {
            institute_id: instituteId,
            batch_id: { in: batchIds },
            is_active: true,
            scheduled_at: { gte: now, lte: twoWeeksAhead },
          },
          select: {
            id: true,
            title: true,
            subject: true,
            scheduled_at: true,
            duration_minutes: true,
            batch: { select: { name: true } },
            teacher: { select: { name: true } },
          },
          orderBy: { scheduled_at: 'asc' },
          take: 20,
        }),
        prisma.assignment.findMany({
          where: {
            institute_id: instituteId,
            batch_id: { in: batchIds },
          },
          select: {
            id: true,
            title: true,
            subject: true,
            due_date: true,
            max_marks: true,
            batch: { select: { name: true } },
            submissions: {
              where: {
                student_id: childId,
                is_latest: true,
              },
              select: {
                status: true,
                is_draft: true,
                submitted_at: true,
                marks_obtained: true,
                remarks: true,
                is_late: true,
              },
              take: 1,
            },
          },
          orderBy: { due_date: 'asc' },
          take: 30,
        }),
        prisma.assignmentSubmission.findMany({
          where: {
            institute_id: instituteId,
            student_id: childId,
            is_latest: true,
            submitted_at: { not: null },
          },
          select: {
            status: true,
            submitted_at: true,
            marks_obtained: true,
            assignment: {
              select: {
                title: true,
                subject: true,
                batch: { select: { name: true } },
              },
            },
          },
          orderBy: { submitted_at: 'desc' },
          take: 15,
        }),
      ]);

    const attendanceCount = attendanceRows.reduce(
      (acc, row) => {
        const status = normalizeStatus(row.status);
        acc.total += 1;
        if (status === 'present') acc.present += 1;
        if (status === 'absent') acc.absent += 1;
        if (status === 'late') acc.late += 1;
        if (status === 'leave') acc.leave += 1;
        return acc;
      },
      { total: 0, present: 0, absent: 0, late: 0, leave: 0 },
    );

    const attendanceRows30d = attendanceRows.filter(
      (row) => row.session?.session_date && row.session.session_date >= thirtyDaysAgo,
    );
    const attendanceCount30d = attendanceRows30d.reduce(
      (acc, row) => {
        const status = normalizeStatus(row.status);
        acc.total += 1;
        if (ATTENDANCE_PRESENT_STATUSES.has(status)) acc.present += 1;
        return acc;
      },
      { total: 0, present: 0 },
    );

    const attendanceByDate = new Map<string, { present: number; total: number; date: Date }>();
    for (const row of attendanceRows) {
      const date = row.session?.session_date;
      if (!date) continue;
      const key = this.toDateKey(date);
      const current = attendanceByDate.get(key) ?? { present: 0, total: 0, date };
      current.total += 1;
      if (ATTENDANCE_PRESENT_STATUSES.has(normalizeStatus(row.status))) {
        current.present += 1;
      }
      attendanceByDate.set(key, current);
    }

    const attendanceDaily = Array.from(attendanceByDate.values())
      .sort((a, b) => b.date.getTime() - a.date.getTime())
      .slice(0, 14)
      .map((item) => ({
        date: item.date,
        present_count: item.present,
        total_count: item.total,
        attendance_percent: this.safePercent(item.present, item.total),
        status: item.present === item.total ? 'present' : item.present === 0 ? 'absent' : 'mixed',
      }));

    const mappedExamResults = examResults.map((result) => {
      const obtained = this.toNumber(result.marks_obtained);
      const total = this.toNumber(result.exam?.total_marks);
      return {
        ...result,
        marks_obtained: obtained,
        percentage: this.safePercent(obtained, total),
      };
    });

    const mappedQuizAttempts = quizAttempts.map((attempt) => {
      const obtained = this.toNumber(attempt.obtained_marks);
      const total = this.toNumber(attempt.total_marks);
      return {
        ...attempt,
        obtained_marks: obtained,
        total_marks: total,
        percentage: this.safePercent(obtained, total),
      };
    });

    const quizAverage = mappedQuizAttempts.length > 0
      ? Math.round(mappedQuizAttempts.reduce((sum, item) => sum + item.percentage, 0) / mappedQuizAttempts.length)
      : 0;
    const testAverage = mappedExamResults.length > 0
      ? Math.round(mappedExamResults.reduce((sum, item) => sum + item.percentage, 0) / mappedExamResults.length)
      : 0;

    const mappedFees = feeRecords.map((record) => ({
      ...record,
      ...calculateFeeAmounts(record.final_amount, record.paid_amount, record.status),
    }));

    const pendingFeeAmount = mappedFees
      .filter((record) => record.is_pending)
      .reduce((sum, record) => sum + record.remaining_amount, 0);

    const mappedAssignments = assignments.map((assignment) => {
      const submission = assignment.submissions[0] ?? null;
      const status = (submission?.status ?? '').toString().toLowerCase();
      const isSubmitted = Boolean(submission && submission.is_draft !== true && status !== 'draft');
      const dueDate = assignment.due_date;
      const overdue = Boolean(dueDate && dueDate < now && !isSubmitted);
      return {
        id: assignment.id,
        title: assignment.title,
        subject: assignment.subject,
        due_date: dueDate,
        max_marks: this.toNumber(assignment.max_marks),
        batch_name: assignment.batch?.name ?? 'Batch',
        submission_status: isSubmitted ? (submission?.status ?? 'submitted') : 'pending',
        submitted_at: submission?.submitted_at ?? null,
        marks_obtained: this.toNumber(submission?.marks_obtained),
        remarks: submission?.remarks ?? null,
        is_late: submission?.is_late === true,
        is_pending: !isSubmitted,
        is_overdue: overdue,
      };
    });

    const pendingAssignments = mappedAssignments.filter((item) => item.is_pending);
    const upcomingAssignments = mappedAssignments.filter((item) => {
      if (!item.due_date) return false;
      return item.due_date >= now && item.is_pending;
    });

    const mappedRecentSubmissions = recentSubmissions.map((item) => ({
      status: item.status,
      submitted_at: item.submitted_at,
      marks_obtained: this.toNumber(item.marks_obtained),
      assignment_title: item.assignment?.title ?? 'Assignment',
      subject: item.assignment?.subject ?? '',
      batch_name: item.assignment?.batch?.name ?? 'Batch',
    }));

    const mappedSchedule = upcomingSchedule.map((lecture) => ({
      id: lecture.id,
      title: lecture.title,
      subject: lecture.subject,
      scheduled_at: lecture.scheduled_at,
      duration_minutes: lecture.duration_minutes,
      batch_name: lecture.batch?.name ?? 'Batch',
      teacher_name: lecture.teacher?.name ?? 'Teacher',
    }));

    const activityFeed = [
      ...mappedQuizAttempts.map((item) => ({
        type: 'quiz',
        title: `${item.quiz?.title ?? 'Quiz'} scored ${item.percentage}%`,
        subtitle: item.quiz?.subject ?? 'Quiz attempt',
        timestamp: item.submitted_at,
      })),
      ...mappedExamResults.map((item) => ({
        type: 'exam',
        title: `${item.exam?.title ?? 'Test'} scored ${item.percentage}%`,
        subtitle: item.exam?.subject ?? 'Exam result',
        timestamp: item.exam?.exam_date,
      })),
      ...mappedRecentSubmissions.map((item) => ({
        type: 'assignment',
        title: `${item.assignment_title} submitted`,
        subtitle: item.subject || 'Assignment submission',
        timestamp: item.submitted_at,
      })),
      ...attendanceDaily.map((item) => ({
        type: 'attendance',
        title: `Attendance ${item.attendance_percent}%`,
        subtitle: item.status,
        timestamp: item.date,
      })),
    ]
      .filter((item) => item.timestamp)
      .sort((a, b) => new Date(b.timestamp as Date).getTime() - new Date(a.timestamp as Date).getTime())
      .slice(0, 30);

    const attendanceGrouped = [
      { status: 'present', _count: { status: attendanceCount.present } },
      { status: 'absent', _count: { status: attendanceCount.absent } },
      { status: 'late', _count: { status: attendanceCount.late } },
      { status: 'leave', _count: { status: attendanceCount.leave } },
    ].filter((item) => item._count.status > 0);

    return {
      child: {
        id: student.id,
        name: student.name,
        phone: student.phone,
        student_code: student.student_code,
        is_active: student.is_active,
        batches: student.student_batches.map((item) => item.batch).filter(Boolean),
      },
      summary: {
        attendance_percentage_30d: attendanceCount30d.total > 0
          ? Math.round((attendanceCount30d.present / attendanceCount30d.total) * 100)
          : 0,
        total_classes_30d: attendanceCount30d.total,
        present_classes_30d: attendanceCount30d.present,
        avg_quiz_score: quizAverage,
        avg_test_score: testAverage,
        pending_fee_amount: pendingFeeAmount,
        pending_assignments: pendingAssignments.length,
        submitted_assignments: mappedRecentSubmissions.length,
        upcoming_classes: mappedSchedule.length,
      },
      attendance: attendanceGrouped,
      attendance_daily: attendanceDaily,
      results: mappedExamResults,
      quizzes: mappedQuizAttempts,
      fees: {
        summary: {
          total_records: mappedFees.length,
          pending_amount: pendingFeeAmount,
          paid_amount: mappedFees.reduce((sum, item) => sum + item.paid_amount, 0),
        },
        records: mappedFees,
      },
      schedule: mappedSchedule,
      assignments: {
        all: mappedAssignments,
        pending: pendingAssignments,
        upcoming: upcomingAssignments,
        recent_submissions: mappedRecentSubmissions,
      },
      activity_feed: activityFeed,
      generated_at: new Date(),
    };
  }

  async getChildrenDoubts(userId: string, instituteId: string) {
    const { parent, students } = await this.resolveParentContext(userId, instituteId);
    
    if (!parent || students.length === 0) {
      return [];
    }

    const childIds = students.map(s => s.id);

    const doubts = await prisma.doubt.findMany({
      where: {
        student_id: { in: childIds },
        institute_id: instituteId
      },
      include: {
        assigned_to: { select: { name: true } },
        batch: { select: { name: true } },
        student: { select: { name: true } }
      },
      orderBy: { created_at: 'desc' }
    });

    return doubts;
  }
}

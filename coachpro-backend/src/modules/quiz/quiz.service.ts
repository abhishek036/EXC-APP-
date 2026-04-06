import { QuizRepository } from './quiz.repository';
import { Prisma } from '@prisma/client';
import { prisma } from '../../server';
import { ApiError } from '../../middleware/error.middleware';

export class QuizService {
  private static rankStudentCandidates(candidates: any[], userId: string): any[] {
    return [...candidates].sort((a, b) => {
      const aLinked = a.user_id === userId ? 1 : 0;
      const bLinked = b.user_id === userId ? 1 : 0;
      if (bLinked != aLinked) return bLinked - aLinked;

      const aBatchCount = a.student_batches?.length || 0;
      const bBatchCount = b.student_batches?.length || 0;
      if (bBatchCount != aBatchCount) return bBatchCount - aBatchCount;

      const aUnlinked = !a.user_id ? 1 : 0;
      const bUnlinked = !b.user_id ? 1 : 0;
      if (bUnlinked != aUnlinked) return bUnlinked - aUnlinked;

      const aCreated = new Date(a.created_at as any).getTime() || 0;
      const bCreated = new Date(b.created_at as any).getTime() || 0;
      return bCreated - aCreated;
    });
  }

  private static pickPreferredStudentCandidate(candidates: any[], userId: string): any | null {
    const ranked = QuizService.rankStudentCandidates(candidates, userId);
    if (ranked.length === 0) return null;

    const top = ranked[0];
    if ((top.student_batches?.length || 0) > 0) {
      return top;
    }

    // Prefer a candidate with active batch membership when available.
    return ranked.find((candidate) => (candidate.student_batches?.length || 0) > 0) || top;
  }

  private static async ensureTeacherOwnsQuiz(userId: string, instituteId: string, quizTeacherId: string | null | undefined) {
    const teacherId = await QuizService.resolveTeacherProfileId(userId, instituteId);
    if (!quizTeacherId || quizTeacherId !== teacherId) {
      throw new ApiError('You can only manage quizzes created by you', 403, 'FORBIDDEN');
    }
  }

  private static async resolveTeacherProfileId(userId: string, instituteId: string): Promise<string> {
    const teacher = await prisma.teacher.findFirst({
      where: { user_id: userId, institute_id: instituteId, is_active: true },
      select: { id: true },
    });
    if (!teacher) {
      throw new ApiError('Teacher profile not found for this account', 404, 'NOT_FOUND');
    }
    return teacher.id;
  }

  private static phoneVariants(phone: string | null | undefined): string[] {
    const raw = String(phone ?? '').replace(/[\s\-()]/g, '');
    if (!raw) return [];

    const variants = new Set<string>([raw]);
    if (raw.startsWith('+91') && raw.length >= 13) variants.add(raw.substring(3));
    if (raw.startsWith('91') && raw.length === 12) {
      const tenDigits = raw.substring(2);
      variants.add(tenDigits);
      variants.add(`+91${tenDigits}`);
    }
    if (/^\d{10}$/.test(raw)) {
      variants.add(`+91${raw}`);
      variants.add(`91${raw}`);
    }

    return Array.from(variants);
  }

  private static async resolveStudentUserIdFromPhone(
    instituteId: string,
    phone: string | null | undefined,
  ): Promise<string | null> {
    const variants = QuizService.phoneVariants(phone);
    if (variants.length === 0) return null;

    const user = await prisma.user.findFirst({
      where: {
        institute_id: instituteId,
        role: 'student',
        is_active: true,
        phone: { in: variants },
      },
      orderBy: [
        { last_login_at: 'desc' },
        { created_at: 'desc' },
      ],
      select: { id: true },
    });

    return user?.id ?? null;
  }

  private static async resolveStudentProfileId(userId: string, instituteId: string): Promise<string> {
    const user = await prisma.user.findUnique({
      where: { id: userId },
      select: { phone: true, institute_id: true },
    });

    if (!user || user.institute_id !== instituteId) {
      throw new ApiError('Student profile not found for this account', 404, 'NOT_FOUND');
    }

    const orFilters: Array<Record<string, any>> = [{ user_id: userId }];

    const variants = QuizService.phoneVariants(user.phone);
    if (variants.length > 0) {
      orFilters.push({
        AND: [
          { phone: { in: variants } },
          { OR: [{ user_id: null }, { user_id: userId }] },
        ],
      });
    }

    const loadCandidates = async (includeInactiveStudents: boolean) => prisma.student.findMany({
      where: {
        institute_id: instituteId,
        AND: [
          ...(includeInactiveStudents ? [] : [{ OR: [{ is_active: true }, { is_active: null }] }]),
          { OR: orFilters },
        ],
      },
      include: {
        student_batches: {
          where: {
            OR: [{ is_active: true }, { is_active: null }],
          },
          select: { id: true },
        },
      },
      orderBy: { created_at: 'desc' },
    });

    let candidates = await loadCandidates(false);
    if (candidates.length === 0) {
      candidates = await loadCandidates(true);
    }

    const selected = QuizService.pickPreferredStudentCandidate(candidates, userId);

    if (!selected) {
      throw new ApiError('Student profile not found for this account', 404, 'NOT_FOUND');
    }

    if (!selected.user_id) {
      await prisma.student.update({ where: { id: selected.id }, data: { user_id: userId } });
    }

    return selected.id;
  }

  private static async ensureStudentCanAccessQuizBatch(
    studentProfileId: string,
    batchId: string,
    instituteId: string,
  ): Promise<void> {
    const membership = await prisma.studentBatch.findFirst({
      where: {
        student_id: studentProfileId,
        batch_id: batchId,
        institute_id: instituteId,
        OR: [{ is_active: true }, { is_active: null }],
      },
      select: { id: true },
    });

    if (!membership) {
      throw new ApiError('You are not allowed to access this quiz', 403, 'FORBIDDEN');
    }
  }

  static async createQuiz(
    instituteId: string,
    teacherUserId: string,
    batchId: string,
    title: string,
    subject?: string,
    timeLimitMin?: number,
    questions?: any[],
    assessmentType: 'QUIZ' | 'TEST' = 'QUIZ',
    scheduledAt?: string,
    negativeMarking?: number,
    allowRetry?: boolean,
    showInstantResult?: boolean,
  ) {
    const teacherId = await QuizService.resolveTeacherProfileId(teacherUserId, instituteId);

    const defaultAllowRetry = assessmentType === 'QUIZ';
    const defaultShowInstantResult = assessmentType === 'QUIZ';

    const quizData: Prisma.QuizUncheckedCreateInput = {
      batch_id: batchId,
      institute_id: instituteId,
      teacher_id: teacherId,
      assessment_type: assessmentType,
      title,
      subject,
      time_limit_min: timeLimitMin,
      scheduled_at: scheduledAt ? new Date(scheduledAt) : undefined,
      negative_marking: negativeMarking,
      allow_retry: allowRetry ?? defaultAllowRetry,
      show_instant_result: showInstantResult ?? defaultShowInstantResult,
      is_published: false,
    };

    const formattedQuestions: Prisma.QuizQuestionUncheckedCreateWithoutQuizInput[] = (questions || []).map((q, index) => ({
      question_text: q.question_text,
      image_url: q.image_url,
      option_a: q.option_a,
      option_a_image: q.option_a_image,
      option_b: q.option_b,
      option_b_image: q.option_b_image,
      option_c: q.option_c,
      option_c_image: q.option_c_image,
      option_d: q.option_d,
      option_d_image: q.option_d_image,
      correct_option: q.correct_option,
      marks: q.marks ?? 1,
      order_index: q.order_index ?? index,
    }));

    return QuizRepository.createQuiz(quizData, formattedQuestions);
  }

  static async listQuizzes(instituteId: string, batchId?: string, assessmentType?: string) {
    const filter = {
      ...(batchId ? { batch_id: batchId } : {}),
      ...(assessmentType ? { assessment_type: assessmentType.toUpperCase() } : {}),
    };
    return QuizRepository.listQuizzes(instituteId, filter);
  }

  static async getQuizById(id: string, instituteId: string, role: string, requesterUserId: string) {
    const quiz = await QuizRepository.findQuizById(id, instituteId);
    if (!quiz) throw new ApiError('Quiz not found', 404, 'NOT_FOUND');

    const normalizedRole = (role || '').toLowerCase();

    if (normalizedRole === 'teacher') {
      await QuizService.ensureTeacherOwnsQuiz(requesterUserId, instituteId, quiz.teacher_id);
    }

    if (normalizedRole === 'student') {
        const studentProfileId = await QuizService.resolveStudentProfileId(requesterUserId, instituteId);
        await QuizService.ensureStudentCanAccessQuizBatch(studentProfileId, quiz.batch_id, instituteId);

        if (!quiz.is_published) {
          throw new ApiError('This quiz is not published yet', 403, 'FORBIDDEN');
        }

        if (quiz.scheduled_at && new Date(quiz.scheduled_at) > new Date()) {
          throw new ApiError('This quiz is not available yet', 403, 'FORBIDDEN');
        }

        const studentQuiz = JSON.parse(JSON.stringify(quiz));
        studentQuiz.questions.forEach((q: any) => {
            delete q.correct_option; // Don't expose answers to students
        });
        return studentQuiz;
    }

    return quiz;
  }

  static async updateQuiz(id: string, instituteId: string, data: any, requesterRole: string, requesterUserId: string) {
    const quiz = await QuizRepository.findQuizById(id, instituteId);
    if (!quiz) throw new ApiError('Quiz not found', 404, 'NOT_FOUND');
    if (quiz.is_published) throw new ApiError('Cannot edit a published quiz', 400, 'BAD_REQUEST');
    if ((requesterRole || '').toLowerCase() === 'teacher') {
      await QuizService.ensureTeacherOwnsQuiz(requesterUserId, instituteId, quiz.teacher_id);
    }

    const normalizedData: Prisma.QuizUncheckedUpdateInput = {
      ...(data.batch_id ? { batch_id: data.batch_id } : {}),
      ...(data.assessment_type ? { assessment_type: data.assessment_type } : {}),
      ...(data.title ? { title: data.title } : {}),
      ...(data.subject !== undefined ? { subject: data.subject } : {}),
      ...(data.time_limit_min !== undefined ? { time_limit_min: data.time_limit_min } : {}),
      ...(data.scheduled_at !== undefined ? { scheduled_at: data.scheduled_at ? new Date(data.scheduled_at) : null } : {}),
      ...(data.negative_marking !== undefined ? { negative_marking: data.negative_marking } : {}),
      ...(data.allow_retry !== undefined ? { allow_retry: data.allow_retry } : {}),
      ...(data.show_instant_result !== undefined ? { show_instant_result: data.show_instant_result } : {}),
    };

    const questions = Array.isArray(data.questions) ? data.questions : undefined;
    if (!questions) {
      await QuizRepository.updateQuiz(id, instituteId, normalizedData);
      return QuizRepository.findQuizById(id, instituteId);
    }

    const formattedQuestions: Prisma.QuizQuestionUncheckedCreateWithoutQuizInput[] = questions.map((q: any, index: number) => ({
      question_text: q.question_text,
      image_url: q.image_url,
      option_a: q.option_a,
      option_a_image: q.option_a_image,
      option_b: q.option_b,
      option_b_image: q.option_b_image,
      option_c: q.option_c,
      option_c_image: q.option_c_image,
      option_d: q.option_d,
      option_d_image: q.option_d_image,
      correct_option: q.correct_option,
      marks: q.marks ?? 1,
      order_index: q.order_index ?? index,
    }));

    return QuizRepository.updateQuizWithQuestions(id, instituteId, normalizedData, formattedQuestions);
  }

  static async publishQuiz(id: string, instituteId: string, requesterRole: string, requesterUserId: string) {
    const quiz = await QuizRepository.findQuizById(id, instituteId);
    if (!quiz) throw new ApiError('Quiz not found', 404, 'NOT_FOUND');
    if (quiz.is_published) throw new ApiError('Quiz is already published', 400, 'BAD_REQUEST');
    if ((requesterRole || '').toLowerCase() === 'teacher') {
      await QuizService.ensureTeacherOwnsQuiz(requesterUserId, instituteId, quiz.teacher_id);
    }

    const result = await QuizRepository.publishQuiz(id, instituteId);

    // Notify students in the batch
    if (quiz.batch_id) {
      try {
        const { NotificationService } = await import('../notification/notification.service');
        const students = await prisma.student.findMany({
          where: {
            institute_id: instituteId,
            OR: [{ is_active: true }, { is_active: null }],
            student_batches: {
              some: {
                batch_id: quiz.batch_id,
                institute_id: instituteId,
                OR: [{ is_active: true }, { is_active: null }],
              },
            },
          },
          select: { id: true, user_id: true, phone: true },
        });

        const typeLabel = (quiz.assessment_type || 'Quiz').toLowerCase();
        const notifiedUserIds = new Set<string>();

        for (const student of students) {
          let targetUserId = student.user_id;
          if (!targetUserId) {
            targetUserId = await QuizService.resolveStudentUserIdFromPhone(instituteId, student.phone);
            if (targetUserId) {
              await prisma.student.updateMany({
                where: {
                  id: student.id,
                  institute_id: instituteId,
                  user_id: null,
                },
                data: { user_id: targetUserId },
              });
            }
          }

          if (!targetUserId || notifiedUserIds.has(targetUserId)) {
            continue;
          }

          notifiedUserIds.add(targetUserId);
          await NotificationService.sendNotificationToUser(targetUserId, {
            title: `New ${typeLabel.toUpperCase()}: ${quiz.title}`,
            body: `A new ${typeLabel} "${quiz.title}" is now available for your batch.`,
            type: 'exam',
            institute_id: instituteId,
            meta: {
              route: '/student/quiz',
              quiz_id: quiz.id,
              batch_id: quiz.batch_id,
            },
          });
        }
      } catch (err) {
        console.error('Failed to send quiz publication notifications:', err);
      }
    }

    return result;
  }

  static async startAttempt(quizId: string, studentId: string, instituteId: string) {
    const studentProfileId = await QuizService.resolveStudentProfileId(studentId, instituteId);

    const quiz = await QuizRepository.findQuizById(quizId, instituteId);
    if (!quiz) throw new ApiError('Quiz not found', 404, 'NOT_FOUND');

    await QuizService.ensureStudentCanAccessQuizBatch(studentProfileId, quiz.batch_id, instituteId);

    if (!quiz.is_published) {
      throw new ApiError('Quiz is not published yet', 403, 'FORBIDDEN');
    }

    if (quiz.scheduled_at && new Date(quiz.scheduled_at) > new Date()) {
      throw new ApiError('Quiz is not available yet', 403, 'FORBIDDEN');
    }

    const existingAttempt = await QuizRepository.findAttempt(quizId, studentProfileId);
    if (existingAttempt) {
      if ((quiz.assessment_type ?? 'QUIZ') === 'TEST') {
        if (existingAttempt.submitted_at) {
          throw new ApiError('One attempt only for this test', 403, 'FORBIDDEN');
        }
        return existingAttempt;
      }

      const allowRetry = quiz.allow_retry ?? true;
      if (existingAttempt.submitted_at && allowRetry) {
        return QuizRepository.resetAttemptForRetry(quizId, studentProfileId);
      }
      return existingAttempt;
    }

    return QuizRepository.createAttempt({
      quiz_id: quizId,
      student_id: studentProfileId,
      institute_id: instituteId,
    });
  }

  static async submitQuiz(quizId: string, studentId: string, instituteId: string, answers: Record<string, string>) {
    const studentProfileId = await QuizService.resolveStudentProfileId(studentId, instituteId);

    const quiz = await QuizRepository.findQuizById(quizId, instituteId);
    if (!quiz) throw new ApiError('Quiz not found', 404, 'NOT_FOUND');

    await QuizService.ensureStudentCanAccessQuizBatch(studentProfileId, quiz.batch_id, instituteId);

    if (!quiz.is_published) {
      throw new ApiError('Quiz is not published yet', 403, 'FORBIDDEN');
    }

    if (quiz.scheduled_at && new Date(quiz.scheduled_at) > new Date()) {
      throw new ApiError('Quiz is not available yet', 403, 'FORBIDDEN');
    }

    const attempt = await QuizRepository.findAttempt(quizId, studentProfileId);
    if (!attempt) throw new ApiError('Quiz attempt not started', 404, 'NOT_FOUND');
    if (attempt.submitted_at) throw new ApiError('Quiz already submitted', 400, 'BAD_REQUEST');

    const startedAtMs = attempt.started_at ? new Date(attempt.started_at).getTime() : Date.now();
    const timeLimitMin = Number(quiz.time_limit_min ?? 0);
    if (timeLimitMin > 0) {
      const allowedMs = timeLimitMin * 60 * 1000;
      const elapsedMs = Date.now() - startedAtMs;
      if (elapsedMs > allowedMs + 5000) {
        throw new ApiError('Time limit exceeded for this quiz', 400, 'TIME_LIMIT_EXCEEDED');
      }
    }

    const allowedQuestionIds = new Set(quiz.questions.map((q) => q.id));
    for (const questionId of Object.keys(answers || {})) {
      if (!allowedQuestionIds.has(questionId)) {
        throw new ApiError('Submitted answers contain invalid question ids', 400, 'INVALID_ANSWERS');
      }
    }

    let totalMarks = 0;
    let obtainedMarks = 0;
    const negativeMark = Number(quiz.negative_marking ?? 0);

    for (const q of quiz.questions) {
      const qMarks = q.marks ?? 1;
      totalMarks += qMarks;

      const studentAnswer = answers[q.id];
      if (studentAnswer) {
        if (studentAnswer === q.correct_option) {
          obtainedMarks += qMarks;
        } else {
          obtainedMarks -= negativeMark;
        }
      }
    }

    if (obtainedMarks < 0) obtainedMarks = 0;

    const finalObtainedMarks = obtainedMarks;
    const finalTotalMarks = totalMarks;

    const updatedAttempt = await prisma.$transaction(async (tx) => {
      return tx.quizAttempt.update({
        where: { quiz_id_student_id: { quiz_id: quizId, student_id: studentProfileId } },
        data: {
          submitted_at: new Date(),
          total_marks: finalTotalMarks,
          obtained_marks: finalObtainedMarks,
          answers: answers as Prisma.JsonObject,
        },
      });
    });

    // Notify student about result if enabled
    if (quiz.show_instant_result) {
      try {
        const { NotificationService } = await import('../notification/notification.service');
        const studentUser = await prisma.student.findUnique({
          where: { id: studentProfileId },
          select: { user_id: true }
        });
        if (studentUser?.user_id) {
          await NotificationService.sendNotificationToUser(studentUser.user_id, {
            title: 'Quiz Result Available',
            body: `You scored ${finalObtainedMarks}/${finalTotalMarks} in "${quiz.title}".`,
            type: 'exam',
            institute_id: instituteId,
            meta: {
              route: '/student/quiz',
              quiz_id: quiz.id
            }
          });
        }
      } catch (err) {
        console.error('Failed to send quiz result notification:', err);
      }
    }

    // Notify teacher about submission
    try {
      const { NotificationService } = await import('../notification/notification.service');
      const studentUser = await prisma.student.findUnique({
        where: { id: studentProfileId },
        select: { user_id: true, name: true }
      });
      const teacherUser = quiz.teacher_id 
        ? await prisma.teacher.findFirst({
            where: { id: quiz.teacher_id },
            select: { user_id: true }
          })
        : null;
      if (teacherUser?.user_id && studentUser) {
        await NotificationService.sendNotificationToUser(teacherUser.user_id, {
          title: 'Quiz Submitted',
          body: `${studentUser.name || 'A student'} submitted "${quiz.title}"${quiz.show_instant_result ? ` and scored ${finalObtainedMarks}/${finalTotalMarks}` : ''}.`,
          type: 'exam',
          institute_id: instituteId,
          meta: {
            route: quiz.batch_id ? `/teacher/batches/${quiz.batch_id}?tab=tests` : '/teacher/batches',
            quiz_id: quiz.id,
            student_id: studentProfileId
          }
        });
      }
    } catch (err) {
      console.error('Failed to send teacher quiz submission notification:', err);
    }

    return updatedAttempt;
  }

  static async getStudentResult(quizId: string, studentId: string, instituteId: string) {
    const studentProfileId = await QuizService.resolveStudentProfileId(studentId, instituteId);

    const quiz = await QuizRepository.findQuizById(quizId, instituteId);
    if (!quiz) throw new ApiError('Quiz not found', 404, 'NOT_FOUND');

    await QuizService.ensureStudentCanAccessQuizBatch(studentProfileId, quiz.batch_id, instituteId);

    const attempt = await QuizRepository.findAttempt(quizId, studentProfileId);
    if (!attempt) throw new ApiError('Attempt not found', 404, 'NOT_FOUND');
    if (!attempt.submitted_at) throw new ApiError('Quiz not submitted yet', 400, 'BAD_REQUEST');

    const answerMap = (attempt.answers && typeof attempt.answers === 'object')
      ? (attempt.answers as Record<string, string>)
      : {};

    let correctAnswers = 0;
    let wrongAnswers = 0;
    let unansweredQuestions = 0;

    const questions = quiz.questions.map((q, idx) => {
      const qAny = q as any;
      const selectedOption = answerMap[q.id] ?? null;
      const hasAnswered = !!selectedOption;
      const isCorrect = hasAnswered && selectedOption === q.correct_option;

      if (!hasAnswered) {
        unansweredQuestions += 1;
      } else if (isCorrect) {
        correctAnswers += 1;
      } else {
        wrongAnswers += 1;
      }

      return {
        id: q.id,
        order_index: q.order_index ?? idx,
        question_text: q.question_text,
        image_url: q.image_url,
        option_a: q.option_a,
        option_a_image: qAny.option_a_image ?? null,
        option_b: q.option_b,
        option_b_image: qAny.option_b_image ?? null,
        option_c: q.option_c,
        option_c_image: qAny.option_c_image ?? null,
        option_d: q.option_d,
        option_d_image: qAny.option_d_image ?? null,
        correct_option: q.correct_option,
        selected_option: selectedOption,
        is_correct: isCorrect,
        marks: q.marks ?? 1,
      };
    });

    const totalQuestions = questions.length;
    const answeredQuestions = totalQuestions - unansweredQuestions;
    const totalMarks = attempt.total_marks ?? quiz.questions.reduce((sum, q) => sum + (q.marks ?? 1), 0);
    const obtainedMarks = attempt.obtained_marks ?? 0;
    const percentage = totalMarks > 0 ? Number(((obtainedMarks / totalMarks) * 100).toFixed(2)) : 0;

    return {
      quiz: {
        id: quiz.id,
        title: quiz.title,
        subject: quiz.subject,
        assessment_type: quiz.assessment_type,
        batch_id: quiz.batch_id,
      },
      attempt: {
        id: attempt.id,
        started_at: attempt.started_at,
        submitted_at: attempt.submitted_at,
      },
      summary: {
        total_questions: totalQuestions,
        answered_questions: answeredQuestions,
        correct_answers: correctAnswers,
        wrong_answers: wrongAnswers,
        unanswered_questions: unansweredQuestions,
        total_marks: totalMarks,
        obtained_marks: obtainedMarks,
        percentage,
      },
      questions,
    };
  }

  static async getLeaderboard(
    quizId: string,
    instituteId: string,
    requesterRole: string,
    requesterUserId: string,
  ) {
    const quiz = await QuizRepository.findQuizById(quizId, instituteId);
    if (!quiz) throw new ApiError('Quiz not found', 404, 'NOT_FOUND');

    if ((requesterRole || '').toLowerCase() === 'teacher') {
      await QuizService.ensureTeacherOwnsQuiz(requesterUserId, instituteId, quiz.teacher_id);
    }

    return QuizRepository.getLeaderboard(quizId, instituteId);
  }

  static async getFullReport(
    quizId: string,
    instituteId: string,
    requesterRole: string,
    requesterUserId: string,
  ) {
    const attempts = await QuizRepository.getAttemptsByQuiz(quizId, instituteId);
    const quiz = await QuizRepository.findQuizById(quizId, instituteId);
    if (!quiz) throw new ApiError('Quiz not found', 404, 'NOT_FOUND');

    if ((requesterRole || '').toLowerCase() === 'teacher') {
      await QuizService.ensureTeacherOwnsQuiz(requesterUserId, instituteId, quiz.teacher_id);
    }

    const batchStudents = await prisma.studentBatch.findMany({
      where: {
        batch_id: quiz.batch_id,
        institute_id: instituteId,
        OR: [{ is_active: true }, { is_active: null }],
      },
      include: {
        student: {
          select: {
            id: true,
            name: true,
            phone: true,
            photo_url: true,
          },
        },
      },
    });

    const attemptByStudent = new Map<string, any>();
    for (const attempt of attempts) {
      attemptByStudent.set(attempt.student_id, attempt);
    }

    const class_results = batchStudents
      .map((sb) => {
        const att = attemptByStudent.get(sb.student_id);
        return {
          student_id: sb.student_id,
          student_name: sb.student?.name ?? 'Student',
          student_phone: sb.student?.phone ?? '',
          student_photo_url: sb.student?.photo_url ?? null,
          submitted_at: att?.submitted_at ?? null,
          obtained_marks: att?.obtained_marks ?? null,
          total_marks: att?.total_marks ?? null,
          status: att?.submitted_at ? 'submitted' : 'pending',
        };
      })
      .sort((a, b) => {
        if (a.status !== b.status) return a.status === 'submitted' ? -1 : 1;
        const aMarks = a.obtained_marks ?? -1;
        const bMarks = b.obtained_marks ?? -1;
        if (aMarks !== bMarks) return bMarks - aMarks;
        return a.student_name.localeCompare(b.student_name);
      });
    
    return {
       quiz,
       attempts,
       class_results,
    };
  }

  static async deleteQuiz(id: string, instituteId: string, requesterRole: string, requesterUserId: string) {
    const quiz = await QuizRepository.findQuizById(id, instituteId);
    if (!quiz) throw new ApiError('Quiz not found', 404, 'NOT_FOUND');
    if ((requesterRole || '').toLowerCase() === 'teacher') {
      await QuizService.ensureTeacherOwnsQuiz(requesterUserId, instituteId, quiz.teacher_id);
    }

    await QuizRepository.deleteQuiz(id, instituteId);
    return { id };
  }
}

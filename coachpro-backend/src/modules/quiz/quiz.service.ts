import { QuizRepository } from './quiz.repository';
import { Prisma } from '@prisma/client';
import { prisma } from '../../server';
import { ApiError } from '../../middleware/error.middleware';

export class QuizService {
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

  private static async resolveStudentProfileId(userId: string, instituteId: string): Promise<string> {
    const user = await prisma.user.findUnique({
      where: { id: userId },
      select: { phone: true, institute_id: true },
    });

    if (!user || user.institute_id !== instituteId) {
      throw new ApiError('Student profile not found for this account', 404, 'NOT_FOUND');
    }

    const orFilters: Array<Record<string, any>> = [{ user_id: userId }];

    const raw = String(user.phone ?? '').replace(/[\s\-()]/g, '');
    if (raw) {
      const variants = new Set<string>([raw]);
      if (raw.startsWith('+91') && raw.length >= 13) variants.add(raw.substring(3));
      if (raw.startsWith('91') && raw.length === 12) {
        variants.add(raw.substring(2));
        variants.add(`+91${raw.substring(2)}`);
      }
      if (/^\d{10}$/.test(raw)) {
        variants.add(`+91${raw}`);
        variants.add(`91${raw}`);
      }
      orFilters.push({ phone: { in: Array.from(variants) } });
    }

    const candidates = await prisma.student.findMany({
      where: {
        institute_id: instituteId,
        is_active: true,
        OR: orFilters,
      },
      include: {
        student_batches: {
          where: { is_active: true },
          select: { id: true },
        },
      },
      orderBy: { created_at: 'desc' },
    });

    const ranked = [...candidates].sort((a, b) => {
      const aBatchCount = a.student_batches?.length || 0;
      const bBatchCount = b.student_batches?.length || 0;
      if (bBatchCount != aBatchCount) return bBatchCount - aBatchCount;

      const aLinked = a.user_id === userId ? 1 : 0;
      const bLinked = b.user_id === userId ? 1 : 0;
      if (bLinked != aLinked) return bLinked - aLinked;

      const aHasUser = a.user_id ? 1 : 0;
      const bHasUser = b.user_id ? 1 : 0;
      if (bHasUser != aHasUser) return bHasUser - aHasUser;

      const aCreated = new Date(a.created_at as any).getTime() || 0;
      const bCreated = new Date(b.created_at as any).getTime() || 0;
      return bCreated - aCreated;
    });

    const selected = ranked[0] || null;

    if (!selected) {
      throw new ApiError('Student profile not found for this account', 404, 'NOT_FOUND');
    }

    if (!selected.user_id) {
      await prisma.student.update({ where: { id: selected.id }, data: { user_id: userId } });
    }

    return selected.id;
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

  static async getQuizById(id: string, instituteId: string, role: string) {
    const quiz = await QuizRepository.findQuizById(id, instituteId);
    if (!quiz) throw new ApiError('Quiz not found', 404, 'NOT_FOUND');

    // NOTE: Allowing access if the student is assigned to the batch
    // if (role === 'student' && !quiz.is_published) {
    //   throw new ApiError('This quiz is not published yet', 403, 'FORBIDDEN');
    // }

    if (role === 'student') {
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
          where: { student_batches: { some: { batch_id: quiz.batch_id } }, is_active: true },
          select: { user_id: true }
        });

        const typeLabel = (quiz.assessment_type || 'Quiz').toLowerCase();
        for (const student of students) {
          if (student.user_id) {
            await NotificationService.sendNotificationToUser(student.user_id, {
              title: `New ${typeLabel.toUpperCase()}: ${quiz.title}`,
              body: `A new ${typeLabel} "${quiz.title}" is now available for your batch.`,
              type: 'exam',
              institute_id: instituteId,
              meta: {
                route: '/student/quizzes',
                quiz_id: quiz.id
              }
            });
          }
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
    // NOTE: We allow starting even if not published if the student is assigned.
    // In many cases, "published" simply means "visible in catalog", but students in a batch
    // should be able to take it if it appears in their batch panel.
    // if (!quiz.is_published) throw new ApiError('Quiz is not published yet', 403, 'FORBIDDEN');

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

    const attempt = await QuizRepository.findAttempt(quizId, studentProfileId);
    if (!attempt) throw new ApiError('Quiz attempt not started', 404, 'NOT_FOUND');
    if (attempt.submitted_at) throw new ApiError('Quiz already submitted', 400, 'BAD_REQUEST');

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
              route: '/student/quizzes',
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
            route: `/teacher/quiz/${quiz.id}/results`,
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

    const attempt = await QuizRepository.findAttempt(quizId, studentProfileId);
    if (!attempt) throw new ApiError('Attempt not found', 404, 'NOT_FOUND');
    if (!attempt.submitted_at) throw new ApiError('Quiz not submitted yet', 400, 'BAD_REQUEST');
    
    return attempt;
  }

  static async getLeaderboard(quizId: string, instituteId: string) {
    return QuizRepository.getLeaderboard(quizId, instituteId);
  }

  static async getFullReport(quizId: string, instituteId: string) {
    const attempts = await QuizRepository.getAttemptsByQuiz(quizId, instituteId);
    const quiz = await QuizRepository.findQuizById(quizId, instituteId);
    
    return {
       quiz,
       attempts
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

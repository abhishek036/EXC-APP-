import { prisma } from '../../server';
import { CreateNoteInput, CreateAssignmentInput, SubmitAssignmentInput, ReviewAssignmentSubmissionInput, CreateDoubtInput, RespondDoubtInput } from './content.validator';
import { isLegacyColumnError } from '../../utils/prisma-errors';
import { ApiError } from '../../middleware/error.middleware';

export class ContentRepository {
    private isLegacyError(error: unknown, columnName?: string): boolean {
        return isLegacyColumnError(error, columnName);
    }

    private mapAssignmentRow(row: any) {
        return {
            id: row.id,
            batch_id: row.batch_id,
            institute_id: row.institute_id,
            teacher_id: row.teacher_id,
            title: row.title,
            subject: row.subject ?? null,
            description: row.description ?? null,
            instructions: row.instructions ?? null,
            max_marks: row.max_marks ?? null,
            due_date: row.due_date ?? null,
            file_url: row.file_url ?? null,
            allow_late_submission: row.allow_late_submission ?? false,
            late_grace_minutes: row.late_grace_minutes ?? 0,
            max_attempts: row.max_attempts ?? 1,
            allow_text_submission: row.allow_text_submission ?? true,
            allow_file_submission: row.allow_file_submission ?? true,
            max_file_size_kb: row.max_file_size_kb ?? 20480,
            allowed_file_types: Array.isArray(row.allowed_file_types)
              ? row.allowed_file_types
              : ['pdf', 'jpg', 'jpeg', 'png', 'doc', 'docx'],
            correct_solution_url: row.correct_solution_url ?? null,
            created_at: row.created_at ?? null,
            updated_at: row.updated_at ?? null,
        };
    }

  private extractExtension(value?: string | null): string | null {
      const raw = String(value ?? '').trim().toLowerCase();
      if (!raw) return null;
      const withoutQuery = raw.split('?')[0];
      const parts = withoutQuery.split('.');
      if (parts.length < 2) return null;
      return parts[parts.length - 1] || null;
  }

  private normalizeFileTypes(value: unknown): string[] {
      const fallback = ['pdf', 'jpg', 'jpeg', 'png', 'doc', 'docx'];
      if (!Array.isArray(value) || value.length === 0) return fallback;
      const normalized = Array.from(new Set(value.map((item) => String(item).trim().toLowerCase()).filter(Boolean)));
      return normalized.length > 0 ? normalized : fallback;
  }

  private trimOrNull(value: unknown): string | null {
      const text = String(value ?? '').trim();
      return text.length > 0 ? text : null;
  }

  private toNumberOrNull(value: unknown): number | null {
      if (value === null || value === undefined || value === '') return null;
      const num = Number(value);
      return Number.isFinite(num) ? num : null;
  }

  private toIsoDateOrNull(value?: string | null): Date | null {
      if (!value) return null;
      const date = new Date(value);
      return Number.isFinite(date.getTime()) ? date : null;
  }

  private isLate(dueDate: Date | null, graceMinutes: number): boolean {
      if (!dueDate) return false;
      const graceMs = Math.max(0, graceMinutes || 0) * 60 * 1000;
      return Date.now() > (dueDate.getTime() + graceMs);
  }

  private ensureSubmissionFileRules(assignment: any, payload: SubmitAssignmentInput) {
      const text = this.trimOrNull(payload.submission_text);
      const fileUrl = this.trimOrNull(payload.file_url);
      const hasText = !!text;
      const hasFile = !!fileUrl;

      if (!payload.is_draft && !hasText && !hasFile) {
          throw new ApiError('Either text answer or file upload is required', 400, 'INVALID_SUBMISSION');
      }

      if (hasText && assignment.allow_text_submission === false) {
          throw new ApiError('Text submission is disabled for this assignment', 400, 'TEXT_SUBMISSION_DISABLED');
      }

      if (hasFile && assignment.allow_file_submission === false) {
          throw new ApiError('File submission is disabled for this assignment', 400, 'FILE_SUBMISSION_DISABLED');
      }

      const fileSizeKb = this.toNumberOrNull(payload.file_size_kb);
      if (hasFile && fileSizeKb !== null && assignment.max_file_size_kb && fileSizeKb > Number(assignment.max_file_size_kb)) {
          throw new ApiError(`File size exceeds ${assignment.max_file_size_kb}KB limit`, 400, 'FILE_TOO_LARGE');
      }

      const ext = this.trimOrNull((payload as any).file_ext)?.toLowerCase()
        ?? this.extractExtension((payload as any).file_name)
        ?? this.extractExtension(fileUrl);

      if (hasFile && ext) {
          const allowed = this.normalizeFileTypes(assignment.allowed_file_types);
          if (!allowed.includes(ext)) {
              throw new ApiError(`File type .${ext} is not allowed for this assignment`, 400, 'INVALID_FILE_TYPE');
          }
      }

      if ((payload as any).scan_status === 'infected') {
          throw new ApiError('Blocked unsafe file upload', 400, 'MALWARE_DETECTED');
      }
  }

    private mergeSubmissionPayload(payload: SubmitAssignmentInput, fallback?: any) {
            const fileUrl = this.trimOrNull(payload.file_url) ?? this.trimOrNull(fallback?.file_url);
            const text = this.trimOrNull(payload.submission_text) ?? this.trimOrNull(fallback?.submission_text);
            const fileName = this.trimOrNull((payload as any).file_name) ?? this.trimOrNull(fallback?.file_name);
            const fileMimeType = this.trimOrNull((payload as any).file_mime_type) ?? this.trimOrNull(fallback?.file_mime_type);
            const fileSizeKb = this.toNumberOrNull((payload as any).file_size_kb) ?? this.toNumberOrNull(fallback?.file_size_kb);
            const scanStatus = this.trimOrNull((payload as any).scan_status)
                ?? this.trimOrNull(fallback?.scan_status)
                ?? (fileUrl ? 'pending' : 'clean');

            return {
                file_url: fileUrl,
                submission_text: text,
                file_name: fileName,
                file_mime_type: fileMimeType,
                file_size_kb: fileSizeKb,
                scan_status: scanStatus,
            };
    }

  // NOTES
    async createNote(instituteId: string, teacherId: string | null, data: CreateNoteInput) {
      return prisma.note.create({
                    data: { ...data, institute_id: instituteId, teacher_id: teacherId ?? null }
      });
  }

  async listNotes(instituteId: string, filter: { batchId?: string, subject?: string }) {
      try {
          return await prisma.note.findMany({
              where: { 
                institute_id: instituteId, 
                ...(filter.batchId && { batch_id: filter.batchId }),
                ...(filter.subject && { subject: filter.subject })
              },
              orderBy: { created_at: 'desc' }
          });
      } catch (error) {
          if (!this.isLegacyError(error, 'subject')) throw error;
          return this.listNotesLegacy(instituteId, filter);
      }
  }

  private async listNotesLegacy(instituteId: string, filter: { batchId?: string, subject?: string }) {
      // Fallback for when subject or file_type columns are missing
      const rows = await prisma.$queryRawUnsafe<any[]>(
          `SELECT id::text, 
                  title, 
                  description, 
                  file_url, 
                  COALESCE(file_type, 'note') as file_type, 
                  created_at, 
                  batch_id::text
           FROM notes
           WHERE institute_id::text = $1::text
             AND ($2::text IS NULL OR batch_id::text = $2::text)`,
          instituteId,
          filter.batchId ?? null
      );
      return rows;
  }

  // ASSIGNMENTS
  async createAssignment(instituteId: string, teacherId: string | null, data: CreateAssignmentInput) {
      const assignmentData: any = {
          title: data.title,
          description: this.trimOrNull(data.description),
          instructions: this.trimOrNull((data as any).instructions),
          batch_id: data.batch_id,
          subject: this.trimOrNull(data.subject),
          file_url: this.trimOrNull((data as any).question_file_url) ?? this.trimOrNull(data.file_url),
          max_marks: this.toNumberOrNull((data as any).max_marks),
          due_date: this.toIsoDateOrNull(data.due_date),
          allow_late_submission: (data as any).allow_late_submission ?? false,
          late_grace_minutes: Number((data as any).late_grace_minutes ?? 0),
          max_attempts: Number((data as any).max_attempts ?? 1),
          allow_text_submission: (data as any).allow_text_submission ?? true,
          allow_file_submission: (data as any).allow_file_submission ?? true,
          max_file_size_kb: Number((data as any).max_file_size_kb ?? 20480),
          allowed_file_types: this.normalizeFileTypes((data as any).allowed_file_types),
          correct_solution_url: this.trimOrNull((data as any).correct_solution_url),
          institute_id: instituteId,
          teacher_id: teacherId ?? null,
      };

      try {
          return await prisma.assignment.create({
              data: assignmentData
          });
      } catch (error) {
          if (!this.isLegacyError(error)) throw error;
          return this.createAssignmentLegacy(instituteId, teacherId, data);
      }
  }

  async listAssignments(instituteId: string, filter: { batchId?: string, teacherId?: string, subject?: string }) {
      try {
          return await prisma.assignment.findMany({
              where: { 
                institute_id: instituteId, 
                ...(filter.batchId && { batch_id: filter.batchId }),
                ...(filter.teacherId && { teacher_id: filter.teacherId }),
                ...(filter.subject && { subject: filter.subject })
              },
              orderBy: { created_at: 'desc' }
          });
      } catch (error) {
                    if (!this.isLegacyError(error)) throw error;
          return this.listAssignmentsLegacy(instituteId, {
            batchId: filter.batchId,
            teacherId: filter.teacherId,
          });
      }
  }

  private async createAssignmentLegacy(instituteId: string, teacherId: string | null, data: CreateAssignmentInput) {
      // Manual SQL insert avoiding columns that might not exist in production
      const id = crypto.randomUUID();
      const dueDate = data.due_date ? new Date(data.due_date).toISOString() : null;
      const fileUrl = this.trimOrNull((data as any).question_file_url) ?? this.trimOrNull(data.file_url);
      
      await prisma.$executeRawUnsafe(
          `INSERT INTO assignments (id, institute_id, teacher_id, batch_id, title, description, file_url, due_date, created_at)
           VALUES ($1::uuid, $2::uuid, $3::uuid, $4::uuid, $5, $6, $7, $8::timestamp, NOW())`,
          id,
          instituteId,
          teacherId,
          data.batch_id,
          data.title,
          this.trimOrNull(data.description),
          fileUrl,
          dueDate
      );
      
      return {
        id,
        ...data,
        file_url: fileUrl,
        institute_id: instituteId,
        teacher_id: teacherId,
        allow_late_submission: false,
        late_grace_minutes: 0,
        max_attempts: 1,
        allow_text_submission: true,
        allow_file_submission: true,
        max_file_size_kb: 20480,
        allowed_file_types: ['pdf', 'jpg', 'jpeg', 'png', 'doc', 'docx'],
      };
  }

  private async listAssignmentsLegacy(instituteId: string, filter: { batchId?: string, teacherId?: string, subject?: string }) {
      const rows = await prisma.$queryRawUnsafe<any[]>(
          `SELECT id::text, title, description, due_date, file_url, created_at, batch_id::text
           FROM assignments
           WHERE institute_id::text = $1::text
             AND ($2::text IS NULL OR batch_id::text = $2::text)
             AND ($3::text IS NULL OR teacher_id::text = $3::text)`,
          instituteId,
          filter.batchId ?? null,
          filter.teacherId ?? null
      );
      return rows.map((row) => this.mapAssignmentRow(row));
  }

  async saveAssignmentDraft(instituteId: string, assignmentId: string, studentId: string, data: SubmitAssignmentInput) {
      const assignment = await prisma.assignment.findFirst({
          where: { id: assignmentId, institute_id: instituteId },
          select: {
              id: true,
              due_date: true,
              allow_late_submission: true,
              late_grace_minutes: true,
              max_attempts: true,
              allow_text_submission: true,
              allow_file_submission: true,
              max_file_size_kb: true,
              allowed_file_types: true,
          },
      });

      if (!assignment) {
          throw new ApiError('Assignment not found', 404, 'NOT_FOUND');
      }

      const payload = { ...(data as any), is_draft: true } as SubmitAssignmentInput;
      this.ensureSubmissionFileRules(assignment, payload);

      const dueDate = assignment.due_date ? new Date(assignment.due_date as any) : null;
      const isLateNow = this.isLate(dueDate, Number(assignment.late_grace_minutes ?? 0));
      if (isLateNow && assignment.allow_late_submission === false) {
          throw new ApiError('Deadline has passed. Draft cannot be edited now.', 400, 'DEADLINE_PASSED');
      }

      const maxAttempts = Math.max(1, Number(assignment.max_attempts ?? 1));
      const now = new Date();
      const latest = await prisma.assignmentSubmission.findFirst({
          where: {
              institute_id: instituteId,
              assignment_id: assignmentId,
              student_id: studentId,
              is_latest: true,
          },
          orderBy: { attempt_no: 'desc' },
      });

      if (latest?.is_draft) {
          const merged = this.mergeSubmissionPayload(payload, latest);
          return prisma.assignmentSubmission.update({
              where: { id: latest.id },
              data: {
                  ...merged,
                  status: 'in_progress',
                  draft_saved_at: now,
                  submitted_at: null,
                  is_draft: true,
                  is_late: false,
                  is_latest: true,
              },
          });
      }

      if (latest && !latest.is_draft && latest.attempt_no >= maxAttempts) {
          if (maxAttempts === 1) {
              await prisma.assignmentFeedback.updateMany({
                  where: { assignment_submission_id: latest.id, is_latest: true },
                  data: { is_latest: false },
              });

              const merged = this.mergeSubmissionPayload(payload, latest);
              return prisma.assignmentSubmission.update({
                  where: { id: latest.id },
                  data: {
                      ...merged,
                      status: 'in_progress',
                      draft_saved_at: now,
                      submitted_at: null,
                      reviewed_at: null,
                      reviewed_by_id: null,
                      marks_obtained: null,
                      remarks: null,
                      is_draft: true,
                      is_late: false,
                      is_latest: true,
                  },
              });
          }

          throw new ApiError('Maximum attempts reached. Draft cannot be created.', 400, 'MAX_ATTEMPTS_REACHED');
      }

      await prisma.assignmentSubmission.updateMany({
          where: {
              institute_id: instituteId,
              assignment_id: assignmentId,
              student_id: studentId,
              is_latest: true,
          },
          data: { is_latest: false },
      });

      const merged = this.mergeSubmissionPayload(payload, latest);
      const nextAttemptNo = latest ? Number(latest.attempt_no) + 1 : 1;

      return prisma.assignmentSubmission.create({
          data: {
              institute_id: instituteId,
              assignment_id: assignmentId,
              student_id: studentId,
              attempt_no: nextAttemptNo,
              ...merged,
              status: 'in_progress',
              draft_saved_at: now,
              submitted_at: null,
              is_draft: true,
              is_late: false,
              is_latest: true,
          },
      });
  }

  async submitAssignment(instituteId: string, assignmentId: string, studentId: string, data: SubmitAssignmentInput) {
      const assignment = await prisma.assignment.findFirst({
          where: { id: assignmentId, institute_id: instituteId },
          select: {
              id: true,
              due_date: true,
              allow_late_submission: true,
              late_grace_minutes: true,
              max_attempts: true,
              allow_text_submission: true,
              allow_file_submission: true,
              max_file_size_kb: true,
              allowed_file_types: true,
          },
      });

      if (!assignment) {
          throw new ApiError('Assignment not found', 404, 'NOT_FOUND');
      }

      this.ensureSubmissionFileRules(assignment, data);

      const dueDate = assignment.due_date ? new Date(assignment.due_date as any) : null;
      const isLateNow = this.isLate(dueDate, Number(assignment.late_grace_minutes ?? 0));
      if (isLateNow && assignment.allow_late_submission === false) {
          throw new ApiError('Submission is after deadline and late submissions are disabled', 400, 'DEADLINE_PASSED');
      }

      const maxAttempts = Math.max(1, Number(assignment.max_attempts ?? 1));
      const now = new Date();
      const latest = await prisma.assignmentSubmission.findFirst({
          where: {
              institute_id: instituteId,
              assignment_id: assignmentId,
              student_id: studentId,
              is_latest: true,
          },
          orderBy: { attempt_no: 'desc' },
      });

      const submittedAttempts = await prisma.assignmentSubmission.count({
          where: {
              institute_id: instituteId,
              assignment_id: assignmentId,
              student_id: studentId,
              is_draft: false,
          },
      });

      if (latest?.is_draft) {
          if (latest.attempt_no > maxAttempts) {
              throw new ApiError('Maximum attempts reached', 400, 'MAX_ATTEMPTS_REACHED');
          }

          const merged = this.mergeSubmissionPayload(data, latest);
          return prisma.assignmentSubmission.update({
              where: { id: latest.id },
              data: {
                  ...merged,
                  status: isLateNow ? 'late_submission' : 'submitted',
                  submitted_at: now,
                  draft_saved_at: now,
                  reviewed_at: null,
                  reviewed_by_id: null,
                  marks_obtained: null,
                  remarks: null,
                  is_draft: false,
                  is_late: isLateNow,
                  is_latest: true,
              },
          });
      }

      if (submittedAttempts >= maxAttempts) {
          if (maxAttempts === 1 && latest && !isLateNow) {
              await prisma.assignmentFeedback.updateMany({
                  where: { assignment_submission_id: latest.id, is_latest: true },
                  data: { is_latest: false },
              });

              const merged = this.mergeSubmissionPayload(data, latest);
              return prisma.assignmentSubmission.update({
                  where: { id: latest.id },
                  data: {
                      ...merged,
                      status: 'submitted',
                      submitted_at: now,
                      draft_saved_at: now,
                      reviewed_at: null,
                      reviewed_by_id: null,
                      marks_obtained: null,
                      remarks: null,
                      is_draft: false,
                      is_late: false,
                      is_latest: true,
                  },
              });
          }

          throw new ApiError('Maximum attempts reached for this assignment', 400, 'MAX_ATTEMPTS_REACHED');
      }

      await prisma.assignmentSubmission.updateMany({
          where: {
              institute_id: instituteId,
              assignment_id: assignmentId,
              student_id: studentId,
              is_latest: true,
          },
          data: { is_latest: false },
      });

      const merged = this.mergeSubmissionPayload(data, latest);
      const nextAttemptNo = latest ? Number(latest.attempt_no) + 1 : 1;

      return prisma.assignmentSubmission.create({
          data: {
              institute_id: instituteId,
              assignment_id: assignmentId,
              student_id: studentId,
              attempt_no: nextAttemptNo,
              ...merged,
              status: isLateNow ? 'late_submission' : 'submitted',
              submitted_at: now,
              draft_saved_at: now,
              is_draft: false,
              is_late: isLateNow,
              is_latest: true,
          },
      });
  }

  async listAssignmentSubmissions(instituteId: string, assignmentId: string) {
      const items = await prisma.assignmentSubmission.findMany({
          where: {
              institute_id: instituteId,
              assignment_id: assignmentId,
              is_latest: true,
              is_draft: false,
          },
          include: {
              student: { select: { id: true, name: true, photo_url: true } },
              assignment: {
                select: {
                  id: true,
                  title: true,
                  due_date: true,
                  max_marks: true,
                  batch_id: true,
                  subject: true,
                },
              },
              reviewed_by: { select: { id: true, role: true } },
              feedbacks: {
                  where: { is_latest: true },
                  orderBy: { revision_no: 'desc' },
                  take: 1,
              },
          },
          orderBy: [{ status: 'asc' }, { submitted_at: 'desc' }],
      });

      return items.map((item: any) => ({
          ...item,
          feedback: Array.isArray(item.feedbacks) && item.feedbacks.length > 0 ? item.feedbacks[0] : null,
      }));
  }

  async listMyAssignmentSubmissions(instituteId: string, assignmentId: string, studentId: string) {
      const items = await prisma.assignmentSubmission.findMany({
          where: {
              institute_id: instituteId,
              assignment_id: assignmentId,
              student_id: studentId,
          },
          include: {
              feedbacks: {
                  where: { is_latest: true },
                  orderBy: { revision_no: 'desc' },
                  take: 1,
              },
          },
          orderBy: [{ attempt_no: 'desc' }, { draft_saved_at: 'desc' }],
      });

      return items.map((item: any) => ({
          ...item,
          feedback: Array.isArray(item.feedbacks) && item.feedbacks.length > 0 ? item.feedbacks[0] : null,
      }));
  }

  async getAssignmentSubmissionFeedback(instituteId: string, submissionId: string) {
      return prisma.assignmentFeedback.findMany({
          where: {
              institute_id: instituteId,
              assignment_submission_id: submissionId,
          },
          orderBy: { revision_no: 'desc' },
      });
  }

  async reviewAssignmentSubmission(instituteId: string, submissionId: string, reviewerUserId: string, data: ReviewAssignmentSubmissionInput) {
      const submission = await prisma.assignmentSubmission.findFirst({
          where: { id: submissionId, institute_id: instituteId },
          include: {
              student: { select: { id: true, name: true } },
              assignment: {
                select: {
                  id: true,
                  title: true,
                  max_marks: true,
                },
              },
          },
      });

      if (!submission) {
          throw new ApiError('Assignment submission not found', 404, 'NOT_FOUND');
      }

      if (submission.is_draft) {
          throw new ApiError('Draft cannot be evaluated before submission', 400, 'INVALID_REVIEW_STATE');
      }

      const maxMarks = submission.assignment?.max_marks != null ? Number(submission.assignment.max_marks) : null;
      if (data.marks_obtained != null && maxMarks != null && data.marks_obtained > maxMarks) {
          throw new ApiError(`Marks cannot exceed assignment max marks (${maxMarks})`, 400, 'INVALID_MARKS');
      }

      const latestFeedback = await prisma.assignmentFeedback.findFirst({
          where: { assignment_submission_id: submissionId, is_latest: true },
          orderBy: { revision_no: 'desc' },
      });

      if (latestFeedback) {
          await prisma.assignmentFeedback.updateMany({
              where: { assignment_submission_id: submissionId, is_latest: true },
              data: { is_latest: false },
          });
      }

      const feedbackText = this.trimOrNull((data as any).feedback_text) ?? this.trimOrNull(data.remarks);
      const nextMarks = data.marks_obtained
        ?? (latestFeedback?.marks_obtained != null ? Number(latestFeedback.marks_obtained) : this.toNumberOrNull(submission.marks_obtained));

      const feedback = await prisma.assignmentFeedback.create({
          data: {
              assignment_id: submission.assignment_id,
              assignment_submission_id: submission.id,
              institute_id: instituteId,
              student_id: submission.student_id,
              reviewer_user_id: reviewerUserId,
              marks_obtained: nextMarks,
              feedback_text: feedbackText,
              feedback_audio_url: this.trimOrNull((data as any).feedback_audio_url),
              annotated_file_url: this.trimOrNull((data as any).annotated_file_url),
              rubric_json: (data as any).rubric_json ?? null,
              revision_no: (latestFeedback?.revision_no ?? 0) + 1,
              is_latest: true,
          },
      });

      const reviewed = await prisma.assignmentSubmission.update({
          where: { id: submissionId, institute_id: instituteId },
          data: {
              status: data.status ?? 'evaluated',
              marks_obtained: nextMarks,
              remarks: feedbackText,
              reviewed_at: new Date(),
              reviewed_by_id: reviewerUserId,
              is_draft: false,
          },
          include: {
              student: { select: { id: true, name: true } },
              assignment: { select: { id: true, title: true, max_marks: true } },
              reviewed_by: { select: { id: true, role: true } },
          },
      });

      return { ...reviewed, feedback };
  }

  async getAssignmentAnalytics(instituteId: string, filter: { batchId?: string, teacherId?: string, subject?: string }) {
      const assignments = await prisma.assignment.findMany({
          where: {
              institute_id: instituteId,
              ...(filter.batchId && { batch_id: filter.batchId }),
              ...(filter.teacherId && { teacher_id: filter.teacherId }),
              ...(filter.subject && { subject: filter.subject }),
          },
          select: {
              id: true,
              title: true,
              batch_id: true,
              due_date: true,
              max_marks: true,
          },
      });

      if (assignments.length === 0) {
          return {
              assignments_count: 0,
              average_marks: 0,
              submission_rate: 0,
              late_submissions: 0,
              evaluated_submissions: 0,
              pending_evaluation: 0,
              by_assignment: [],
          };
      }

      const assignmentIds = assignments.map((a) => a.id);
      const latestSubmissions = await prisma.assignmentSubmission.findMany({
          where: {
              institute_id: instituteId,
              assignment_id: { in: assignmentIds },
              is_latest: true,
              is_draft: false,
          },
          select: {
              assignment_id: true,
              status: true,
              is_late: true,
              marks_obtained: true,
              student_id: true,
          },
      });

      const batchIds = Array.from(new Set(assignments.map((a) => a.batch_id).filter(Boolean)));
      const activeBatchStudents = await prisma.studentBatch.findMany({
          where: {
              batch_id: { in: batchIds },
              is_active: true,
          },
          select: {
              batch_id: true,
              student_id: true,
          },
      });

      const enrollmentByBatch = new Map<string, number>();
      for (const item of activeBatchStudents) {
          enrollmentByBatch.set(item.batch_id, (enrollmentByBatch.get(item.batch_id) ?? 0) + 1);
      }

      const marks = latestSubmissions
        .map((item) => this.toNumberOrNull(item.marks_obtained))
        .filter((value): value is number => value !== null);

      const lateSubmissions = latestSubmissions.filter((item) => item.is_late || item.status === 'late_submission').length;
      const evaluated = latestSubmissions.filter((item) => item.status === 'evaluated').length;
      const pending = latestSubmissions.filter((item) => item.status === 'submitted' || item.status === 'late_submission').length;

      const byAssignment = assignments.map((assignment) => {
          const assignmentSubs = latestSubmissions.filter((item) => item.assignment_id === assignment.id);
          const enrolled = Math.max(1, enrollmentByBatch.get(assignment.batch_id) ?? 0);
          const submissionRate = (assignmentSubs.length / enrolled) * 100;

          return {
              assignment_id: assignment.id,
              title: assignment.title,
              batch_id: assignment.batch_id,
              submissions_count: assignmentSubs.length,
              enrolled_students: enrolled,
              submission_rate: Number(submissionRate.toFixed(2)),
              late_submissions: assignmentSubs.filter((item) => item.is_late || item.status === 'late_submission').length,
              evaluated_submissions: assignmentSubs.filter((item) => item.status === 'evaluated').length,
          };
      });

      const avgSubmissionRate = byAssignment.reduce((sum, item) => sum + item.submission_rate, 0) / byAssignment.length;
      const avgMarks = marks.length > 0 ? marks.reduce((sum, value) => sum + value, 0) / marks.length : 0;

      return {
          assignments_count: assignments.length,
          average_marks: Number(avgMarks.toFixed(2)),
          submission_rate: Number(avgSubmissionRate.toFixed(2)),
          late_submissions: lateSubmissions,
          evaluated_submissions: evaluated,
          pending_evaluation: pending,
          by_assignment: byAssignment,
      };
  }

  // DOUBTS
  async createDoubt(instituteId: string, studentId: string, data: CreateDoubtInput) {
      return prisma.doubt.create({
          data: { ...data, institute_id: instituteId, student_id: studentId }
      });
  }

  async respondToDoubt(doubtId: string, instituteId: string, teacherId: string, data: RespondDoubtInput) {
      return prisma.doubt.update({
          where: { id: doubtId, institute_id: instituteId },
          data: {
              ...data,
              assigned_to_id: teacherId,
              ...(data.status === 'resolved' && { resolved_at: new Date() })
          }
      });
  }

  async listDoubts(instituteId: string, filters: { batch_id?: string, student_id?: string, status?: string, subject?: string }) {
      try {
          return await prisma.doubt.findMany({
              where: { 
                institute_id: instituteId, 
                ...filters 
              },
              include: {
                  student: { select: { name: true } },
                  assigned_to: { select: { name: true } }
              },
              orderBy: { created_at: 'desc' }
          });
      } catch (error) {
          if (!this.isLegacyError(error, 'subject')) throw error;
          return this.listDoubtsLegacy(instituteId, filters);
      }
  }

  private async listDoubtsLegacy(instituteId: string, filters: { batch_id?: string, student_id?: string, status?: string, subject?: string }) {
       const rows = await prisma.$queryRawUnsafe<any[]>(
          `SELECT d.id::text, 
                  d.title, 
                  d.description, 
                  d.status, 
                  d.created_at, 
                  d.student_id::text,
                  s.name as student_name
           FROM doubts d
           LEFT JOIN students s ON d.student_id = s.id
           WHERE d.institute_id::text = $1::text
             AND ($2::text IS NULL OR d.batch_id::text = $2::text)
             AND ($3::text IS NULL OR d.student_id::text = $3::text)
             AND ($4::text IS NULL OR d.status = $4::text)`,
          instituteId,
          filters.batch_id ?? null,
          filters.student_id ?? null,
          filters.status ?? null
      );
      return rows.map(r => ({
          ...r,
          student: { name: r.student_name },
          assigned_to: null
      }));
  }
}

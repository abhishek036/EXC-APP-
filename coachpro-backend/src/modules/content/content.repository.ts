import { prisma } from '../../server';
import { CreateNoteInput, CreateAssignmentInput, SubmitAssignmentInput, ReviewAssignmentSubmissionInput, CreateDoubtInput, RespondDoubtInput } from './content.validator';

export class ContentRepository {
    private isLegacyAssignmentColumnError(error: unknown): boolean {
        const code = (error as any)?.code;
        const column = String((error as any)?.meta?.column ?? '').toLowerCase();
        return code === 'P2022' && column.includes('assignments.subject');
    }

    private mapAssignmentRow(row: any) {
        return {
            id: row.id,
            batch_id: row.batch_id,
            institute_id: row.institute_id,
            teacher_id: row.teacher_id,
            title: row.title,
            description: row.description ?? null,
            due_date: row.due_date ?? null,
            file_url: row.file_url ?? null,
            created_at: row.created_at ?? null,
        };
    }

    private async listAssignmentsLegacy(instituteId: string, filter: { batchId?: string, teacherId?: string }) {
        const rows = await prisma.$queryRawUnsafe<any[]>(
            `SELECT id::text, batch_id::text, institute_id::text, teacher_id::text, title, description, due_date, file_url, created_at
             FROM assignments
             WHERE institute_id::text = $1
                 AND ($2::text IS NULL OR batch_id::text = $2::text)
                 AND ($3::text IS NULL OR teacher_id::text = $3::text)
             ORDER BY created_at DESC`,
            instituteId,
            filter.batchId ?? null,
            filter.teacherId ?? null,
        );

        return rows.map((row) => this.mapAssignmentRow(row));
    }

    private async createAssignmentLegacy(instituteId: string, teacherId: string | null, data: CreateAssignmentInput) {
        const rows = await prisma.$queryRawUnsafe<any[]>(
            `INSERT INTO assignments (batch_id, institute_id, teacher_id, title, description, due_date, file_url)
             VALUES ($1::uuid, $2::uuid, $3::uuid, $4, $5, $6, $7)
             RETURNING id::text, batch_id::text, institute_id::text, teacher_id::text, title, description, due_date, file_url, created_at`,
            data.batch_id,
            instituteId,
            teacherId,
            data.title,
            data.description ?? null,
            data.due_date ? new Date(data.due_date) : null,
            data.file_url ?? null,
        );

        return this.mapAssignmentRow(rows[0]);
    }

  // NOTES
    async createNote(instituteId: string, teacherId: string | null, data: CreateNoteInput) {
      return prisma.note.create({
                    data: { ...data, institute_id: instituteId, teacher_id: teacherId ?? null }
      });
  }

  async listNotes(instituteId: string, filter: { batchId?: string, subject?: string }) {
      return prisma.note.findMany({
          where: { 
            institute_id: instituteId, 
            ...(filter.batchId && { batch_id: filter.batchId }),
            ...(filter.subject && { subject: filter.subject })
          },
          orderBy: { created_at: 'desc' }
      });
  }

  // ASSIGNMENTS
  async createAssignment(instituteId: string, teacherId: string | null, data: CreateAssignmentInput) {
      try {
          return await prisma.assignment.create({
              data: { 
                 ...data, 
                 institute_id: instituteId, 
                 teacher_id: teacherId ?? null, 
                 ...(data.due_date && { due_date: new Date(data.due_date) })
              } as any
          });
      } catch (error) {
          if (!this.isLegacyAssignmentColumnError(error)) throw error;
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
          if (!this.isLegacyAssignmentColumnError(error)) throw error;
          return this.listAssignmentsLegacy(instituteId, {
            batchId: filter.batchId,
            teacherId: filter.teacherId,
          });
      }
  }

  async submitAssignment(instituteId: string, assignmentId: string, studentId: string, data: SubmitAssignmentInput) {
      return prisma.assignmentSubmission.upsert({
          where: {
              assignment_id_student_id: {
                  assignment_id: assignmentId,
                  student_id: studentId,
              }
          },
          update: {
              file_url: data.file_url,
              submission_text: data.submission_text,
              status: 'submitted',
              submitted_at: new Date(),
              reviewed_at: null,
              reviewed_by_id: null,
              marks_obtained: null,
              remarks: null,
          },
          create: {
              institute_id: instituteId,
              assignment_id: assignmentId,
              student_id: studentId,
              file_url: data.file_url,
              submission_text: data.submission_text,
              status: 'submitted',
          }
      });
  }

  async listAssignmentSubmissions(instituteId: string, assignmentId: string) {
      return prisma.assignmentSubmission.findMany({
          where: { institute_id: instituteId, assignment_id: assignmentId },
          include: {
              student: { select: { id: true, name: true, photo_url: true } },
              assignment: { select: { id: true, title: true, due_date: true } },
              reviewed_by: { select: { id: true, role: true } },
          },
          orderBy: { submitted_at: 'desc' },
      });
  }

  async reviewAssignmentSubmission(instituteId: string, submissionId: string, reviewerUserId: string, data: ReviewAssignmentSubmissionInput) {
      return prisma.assignmentSubmission.update({
          where: { id: submissionId, institute_id: instituteId },
          data: {
              status: data.status ?? 'reviewed',
              marks_obtained: data.marks_obtained,
              remarks: data.remarks,
              reviewed_at: new Date(),
              reviewed_by_id: reviewerUserId,
          },
          include: {
              student: { select: { id: true, name: true } },
              assignment: { select: { id: true, title: true } },
          },
      });
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
      return prisma.doubt.findMany({
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
  }
}

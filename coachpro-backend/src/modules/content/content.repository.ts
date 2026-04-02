import { prisma } from '../../server';
import { CreateNoteInput, CreateAssignmentInput, SubmitAssignmentInput, ReviewAssignmentSubmissionInput, CreateDoubtInput, RespondDoubtInput } from './content.validator';
import { isLegacyColumnError } from '../../utils/prisma-errors';

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
            description: row.description ?? null,
            due_date: row.due_date ?? null,
            file_url: row.file_url ?? null,
            created_at: row.created_at ?? null,
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
          if (!this.isLegacyError(error, 'subject')) throw error;
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
          if (!this.isLegacyError(error, 'subject')) throw error;
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
      
      await prisma.$executeRawUnsafe(
          `INSERT INTO assignments (id, institute_id, teacher_id, batch_id, title, description, file_url, due_date, created_at)
           VALUES ($1::uuid, $2::uuid, $3::uuid, $4::uuid, $5, $6, $7, $8::timestamp, NOW())`,
          id,
          instituteId,
          teacherId,
          data.batch_id,
          data.title,
          data.description ?? null,
          data.file_url ?? null,
          dueDate
      );
      
      return { id, ...data, institute_id: instituteId, teacher_id: teacherId };
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
      return rows;
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

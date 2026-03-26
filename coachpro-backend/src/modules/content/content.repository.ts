import { prisma } from '../../server';
import { CreateNoteInput, CreateAssignmentInput, SubmitAssignmentInput, ReviewAssignmentSubmissionInput, CreateDoubtInput, RespondDoubtInput } from './content.validator';

export class ContentRepository {
  // NOTES
    async createNote(instituteId: string, teacherId: string | null, data: CreateNoteInput) {
      return prisma.note.create({
                    data: { ...data, institute_id: instituteId, teacher_id: teacherId ?? null }
      });
  }

  async listNotes(instituteId: string, batchId?: string) {
      return prisma.note.findMany({
          where: { institute_id: instituteId, ...(batchId && { batch_id: batchId }) },
          orderBy: { created_at: 'desc' }
      });
  }

  // ASSIGNMENTS
  async createAssignment(instituteId: string, teacherId: string | null, data: CreateAssignmentInput) {
      return prisma.assignment.create({
          data: { 
             ...data, 
             institute_id: instituteId, 
             teacher_id: teacherId ?? null, 
             ...(data.due_date && { due_date: new Date(data.due_date) })
          } as any
      });
  }

  async listAssignments(instituteId: string, filter: { batchId?: string, teacherId?: string }) {
      return prisma.assignment.findMany({
          where: { 
            institute_id: instituteId, 
            ...(filter.batchId && { batch_id: filter.batchId }),
            ...(filter.teacherId && { teacher_id: filter.teacherId })
          },
          orderBy: { created_at: 'desc' }
      });
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

  async listDoubts(instituteId: string, filters: { batch_id?: string, student_id?: string, status?: string }) {
      return prisma.doubt.findMany({
          where: { institute_id: instituteId, ...filters },
          include: {
              student: { select: { name: true } },
              assigned_to: { select: { name: true } }
          },
          orderBy: { created_at: 'desc' }
      });
  }
}

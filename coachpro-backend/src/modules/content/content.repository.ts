import { prisma } from '../../server';
import { CreateNoteInput, CreateAssignmentInput, CreateDoubtInput, RespondDoubtInput } from './content.validator';

export class ContentRepository {
  // NOTES
  async createNote(instituteId: string, teacherId: string, data: CreateNoteInput) {
      return prisma.note.create({
          data: { ...data, institute_id: instituteId, teacher_id: teacherId }
      });
  }

  async listNotes(instituteId: string, batchId?: string) {
      return prisma.note.findMany({
          where: { institute_id: instituteId, ...(batchId && { batch_id: batchId }) },
          orderBy: { created_at: 'desc' }
      });
  }

  // ASSIGNMENTS
  async createAssignment(instituteId: string, teacherId: string, data: CreateAssignmentInput) {
      return prisma.assignment.create({
          data: { 
             ...data, 
             institute_id: instituteId, 
             teacher_id: teacherId, 
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

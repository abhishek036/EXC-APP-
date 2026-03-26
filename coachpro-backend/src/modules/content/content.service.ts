import { ContentRepository } from './content.repository';
import { CreateNoteInput, CreateAssignmentInput, SubmitAssignmentInput, ReviewAssignmentSubmissionInput, CreateDoubtInput, RespondDoubtInput } from './content.validator';

export class ContentService {
  private repo: ContentRepository;

  constructor() {
    this.repo = new ContentRepository();
  }

  // NOTES
    async createNote(instituteId: string, teacherId: string | null, data: CreateNoteInput) {
      return this.repo.createNote(instituteId, teacherId, data);
  }

  async listNotes(instituteId: string, batchId?: string) {
      return this.repo.listNotes(instituteId, batchId);
  }

  // ASSIGNMENTS
    async createAssignment(instituteId: string, teacherId: string | null, data: CreateAssignmentInput) {
      return this.repo.createAssignment(instituteId, teacherId, data);
  }

  async listAssignments(instituteId: string, filter: { batchId?: string, teacherId?: string }) {
      return this.repo.listAssignments(instituteId, filter);
  }

  async submitAssignment(instituteId: string, assignmentId: string, studentId: string, data: SubmitAssignmentInput) {
      return this.repo.submitAssignment(instituteId, assignmentId, studentId, data);
  }

  async listAssignmentSubmissions(instituteId: string, assignmentId: string) {
      return this.repo.listAssignmentSubmissions(instituteId, assignmentId);
  }

  async reviewAssignmentSubmission(instituteId: string, submissionId: string, reviewerUserId: string, data: ReviewAssignmentSubmissionInput) {
      return this.repo.reviewAssignmentSubmission(instituteId, submissionId, reviewerUserId, data);
  }

  // DOUBTS
  async askDoubt(instituteId: string, studentId: string, data: CreateDoubtInput) {
      return this.repo.createDoubt(instituteId, studentId, data);
  }

  async respondToDoubt(doubtId: string, instituteId: string, teacherId: string, data: RespondDoubtInput) {
      return this.repo.respondToDoubt(doubtId, instituteId, teacherId, data);
  }

  async listDoubts(instituteId: string, query: { batchId?: string, studentId?: string, status?: string }) {
      return this.repo.listDoubts(instituteId, {
          batch_id: query.batchId,
          student_id: query.studentId,
          status: query.status
      });
  }
}

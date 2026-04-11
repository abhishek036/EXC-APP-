import { ContentRepository } from './content.repository';
import {
    CreateNoteInput,
    UpdateNoteInput,
    CreateAssignmentInput,
    UpdateAssignmentInput,
    SubmitAssignmentInput,
    ReviewAssignmentSubmissionInput,
    CreateDoubtInput,
    RespondDoubtInput,
} from './content.validator';

export class ContentService {
  private repo: ContentRepository;

  constructor() {
    this.repo = new ContentRepository();
  }

  // NOTES
    async createNote(instituteId: string, teacherId: string | null, data: CreateNoteInput) {
      return this.repo.createNote(instituteId, teacherId, data);
  }

  async listNotes(instituteId: string, filter: { batchId?: string, subject?: string, chapterTitle?: string, includeDeleted?: boolean }) {
      return this.repo.listNotes(instituteId, filter);
  }

  async getNoteById(instituteId: string, noteId: string) {
      return this.repo.getNoteById(instituteId, noteId);
  }

  async updateNote(instituteId: string, noteId: string, data: UpdateNoteInput) {
      return this.repo.updateNote(instituteId, noteId, data);
  }

  async getNoteFile(instituteId: string, noteId: string, fileId: string) {
      return this.repo.getNoteFile(instituteId, noteId, fileId);
  }

  async bookmarkNote(instituteId: string, noteId: string, studentId: string) {
      return this.repo.bookmarkNote(instituteId, noteId, studentId);
  }

  async unbookmarkNote(instituteId: string, noteId: string, studentId: string) {
      return this.repo.unbookmarkNote(instituteId, noteId, studentId);
  }

  async listBookmarkedNotes(instituteId: string, studentId: string, filter: { batchId?: string, subject?: string }) {
      return this.repo.listBookmarkedNotes(instituteId, studentId, filter);
  }

  async listStudentBookmarksMap(instituteId: string, studentId: string, noteIds: string[]) {
      return this.repo.listStudentBookmarksMap(instituteId, studentId, noteIds);
  }

  async logNoteAccess(params: {
      instituteId: string;
      noteId: string;
      noteFileId?: string | null;
      studentId?: string | null;
      action: 'view' | 'download';
      ipAddress?: string | null;
      userAgent?: string | null;
  }) {
      return this.repo.logNoteAccess(params);
  }

    async getNotesAnalytics(instituteId: string, filter: { batchId?: string, subject?: string, chapterTitle?: string, teacherId?: string }) {
      return this.repo.getNotesAnalytics(instituteId, filter);
  }

  async softDeleteNote(instituteId: string, noteId: string) {
      return this.repo.softDeleteNote(instituteId, noteId);
  }

  // ASSIGNMENTS
    async createAssignment(instituteId: string, teacherId: string | null, data: CreateAssignmentInput) {
      return this.repo.createAssignment(instituteId, teacherId, data);
  }

  async listAssignments(instituteId: string, filter: { batchId?: string, teacherId?: string, subject?: string }) {
      return this.repo.listAssignments(instituteId, filter);
  }

  async updateAssignment(instituteId: string, assignmentId: string, data: UpdateAssignmentInput) {
      return this.repo.updateAssignment(instituteId, assignmentId, data);
  }

  async deleteAssignment(instituteId: string, assignmentId: string) {
      return this.repo.deleteAssignment(instituteId, assignmentId);
  }

  async saveAssignmentDraft(instituteId: string, assignmentId: string, studentId: string, data: SubmitAssignmentInput) {
      return this.repo.saveAssignmentDraft(instituteId, assignmentId, studentId, data);
  }

  async submitAssignment(instituteId: string, assignmentId: string, studentId: string, data: SubmitAssignmentInput) {
      return this.repo.submitAssignment(instituteId, assignmentId, studentId, data);
  }

  async listAssignmentSubmissions(instituteId: string, assignmentId: string) {
      return this.repo.listAssignmentSubmissions(instituteId, assignmentId);
  }

  async listMyAssignmentSubmissions(instituteId: string, assignmentId: string, studentId: string) {
      return this.repo.listMyAssignmentSubmissions(instituteId, assignmentId, studentId);
  }

  async getAssignmentSubmissionFeedback(instituteId: string, submissionId: string) {
      return this.repo.getAssignmentSubmissionFeedback(instituteId, submissionId);
  }

  async reviewAssignmentSubmission(instituteId: string, submissionId: string, reviewerUserId: string, data: ReviewAssignmentSubmissionInput) {
      return this.repo.reviewAssignmentSubmission(instituteId, submissionId, reviewerUserId, data);
  }

  async getAssignmentAnalytics(instituteId: string, filter: { batchId?: string, teacherId?: string, subject?: string }) {
      return this.repo.getAssignmentAnalytics(instituteId, filter);
  }

  // DOUBTS
  async askDoubt(instituteId: string, studentId: string, data: CreateDoubtInput) {
      return this.repo.createDoubt(instituteId, studentId, data);
  }

  async respondToDoubt(doubtId: string, instituteId: string, teacherId: string, data: RespondDoubtInput) {
      return this.repo.respondToDoubt(doubtId, instituteId, teacherId, data);
  }

  async listDoubts(instituteId: string, query: { batchId?: string, studentId?: string, status?: string, subject?: string }) {
      return this.repo.listDoubts(instituteId, {
          batch_id: query.batchId,
          student_id: query.studentId,
          status: query.status,
          subject: query.subject
      });
  }
}

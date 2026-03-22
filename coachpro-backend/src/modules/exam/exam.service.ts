import { ApiError } from '../../middleware/error.middleware';
import { ExamRepository } from './exam.repository';
import { CreateExamInput, SaveExamResultInput } from './exam.validator';

export class ExamService {
  private repo: ExamRepository;

  constructor() {
    this.repo = new ExamRepository();
  }

  async list(instituteId: string, status?: string) {
    const now = new Date();
    const exams = await this.repo.list(instituteId);

    return exams
      .map((exam) => {
        const computedStatus = exam.exam_date < now ? 'completed' : 'upcoming';
        return {
          id: exam.id,
          name: exam.title,
          subject: exam.subject,
          date: exam.exam_date,
          duration: exam.duration_min,
          totalMarks: exam.total_marks,
          batchId: exam.batches[0]?.batch_id ?? '',
          batchName: exam.batches[0]?.batch?.name ?? 'Batch',
          status: computedStatus,
        };
      })
      .filter((exam) => !status || exam.status === status);
  }

  async create(instituteId: string, userId: string, data: CreateExamInput) {
    return this.repo.create(instituteId, userId, data);
  }

  async setStatus(instituteId: string, examId: string, status: 'upcoming' | 'completed') {
    return this.repo.setStatus(instituteId, examId, status);
  }

  async remove(instituteId: string, examId: string) {
    return this.repo.remove(instituteId, examId);
  }

  async listResults(instituteId: string) {
    const results = await this.repo.listResults(instituteId);

    return results.map((result) => {
      const totalMarks = result.exam.total_marks;
      const score = Number(result.marks_obtained ?? 0);
      const grade = result.grade ?? '';
      return {
        id: result.id,
        studentName: result.student.name,
        examName: result.exam.title,
        subject: result.exam.subject,
        score,
        totalMarks,
        grade,
      };
    });
  }

  async saveResult(instituteId: string, data: SaveExamResultInput) {
    return this.repo.saveResult(instituteId, data);
  }
}

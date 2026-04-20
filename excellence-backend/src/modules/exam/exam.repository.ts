import { prisma } from '../../server';
import { CreateExamInput, SaveExamResultInput } from './exam.validator';

export class ExamRepository {
  async list(instituteId: string, batchIds?: string[]) {
    const where: any = { institute_id: instituteId };
    if ((batchIds ?? []).length > 0) {
      where.batches = {
        some: {
          batch_id: { in: batchIds },
        },
      };
    }

    return prisma.exam.findMany({
      where,
      include: {
        batches: {
          include: {
            batch: { select: { id: true, name: true } },
          },
        },
      },
      orderBy: { exam_date: 'asc' },
      take: 100,
    });
  }

  async create(instituteId: string, userId: string, data: CreateExamInput) {
    return prisma.exam.create({
      data: {
        institute_id: instituteId,
        created_by_id: userId,
        title: data.name,
        subject: data.subject,
        exam_date: new Date(data.date),
        duration_min: data.duration,
        total_marks: data.totalMarks,
        batches: data.batchId
          ? {
              create: [{ batch_id: data.batchId }],
            }
          : undefined,
      },
      include: {
        batches: {
          include: {
            batch: { select: { id: true, name: true } },
          },
        },
      },
    });
  }

  async setStatus(instituteId: string, examId: string, status: 'upcoming' | 'completed') {
    const now = new Date();
    const date = status === 'completed'
      ? new Date(now.getFullYear(), now.getMonth(), now.getDate() - 1)
      : new Date(now.getFullYear(), now.getMonth(), now.getDate() + 1);

    await prisma.exam.updateMany({
      where: { id: examId, institute_id: instituteId },
      data: { exam_date: date },
    });

    return { success: true };
  }

  async remove(instituteId: string, examId: string) {
    await prisma.examResult.deleteMany({ where: { exam_id: examId, institute_id: instituteId } });
    await prisma.examBatch.deleteMany({ where: { exam_id: examId } });
    await prisma.exam.deleteMany({ where: { id: examId, institute_id: instituteId } });
    return { success: true };
  }

  async listResults(instituteId: string, batchIds?: string[]) {
    const where: any = { institute_id: instituteId };
    if ((batchIds ?? []).length > 0) {
      where.exam = {
        batches: {
          some: {
            batch_id: { in: batchIds },
          },
        },
      };
    }

    return prisma.examResult.findMany({
      where,
      include: {
        student: { select: { id: true, name: true } },
        exam: { select: { id: true, title: true, subject: true, total_marks: true, exam_date: true } },
      },
      take: 100,
    });
  }

  async saveResult(instituteId: string, data: SaveExamResultInput) {
    const exam = await prisma.exam.findFirst({
      where: { id: data.examId, institute_id: instituteId },
      select: { total_marks: true }
    });

    if (!exam) {
      throw new Error('Exam not found');
    }

    const totalMarks = Number(data.maxMarks ?? exam.total_marks ?? 100);
    const score = Number(data.score);
    const percentage = totalMarks > 0 ? (score / totalMarks) * 100 : 0;

    let grade = 'F';
    if (percentage >= 90) grade = 'A+';
    else if (percentage >= 80) grade = 'A';
    else if (percentage >= 70) grade = 'B';
    else if (percentage >= 60) grade = 'C';
    else if (percentage >= 50) grade = 'D';

    return prisma.examResult.upsert({
      where: {
        exam_id_student_id: {
          exam_id: data.examId,
          student_id: data.studentId,
        },
      },
      create: {
        exam_id: data.examId,
        student_id: data.studentId,
        institute_id: instituteId,
        marks_obtained: score,
        is_absent: false,
        grade,
      },
      update: {
        marks_obtained: score,
        is_absent: false,
        grade,
      },
      include: {
        student: { select: { id: true, name: true } },
        exam: { select: { id: true, title: true, subject: true, total_marks: true } },
      }
    });
  }
}

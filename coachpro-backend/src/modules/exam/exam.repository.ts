import { prisma } from '../../server';
import { CreateExamInput } from './exam.validator';

export class ExamRepository {
  async list(instituteId: string) {
    return prisma.exam.findMany({
      where: { institute_id: instituteId },
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

  async listResults(instituteId: string) {
    return prisma.examResult.findMany({
      where: { institute_id: instituteId },
      include: {
        student: { select: { id: true, name: true } },
        exam: { select: { id: true, title: true, subject: true, total_marks: true, exam_date: true } },
      },
      take: 100,
    });
  }
}

import { Prisma } from '@prisma/client';
import { prisma } from '../../server';

export class LectureRepository {
  private static isMissingDurationColumn(error: unknown): boolean {
    const code = (error as any)?.code;
    const column = (error as any)?.meta?.column;
    return code === 'P2022' && typeof column === 'string' && column.includes('lectures.duration_minutes');
  }

  static async create(data: Prisma.LectureUncheckedCreateInput) {
    return prisma.lecture.create({
      data,
    });
  }

  static async listByBatch(
    batchId: string,
    instituteId: string,
    subject?: string,
  ): Promise<
    Array<{
      id: string;
      title: string | null;
      scheduled_at: Date | null;
      duration_minutes?: number | null;
      created_at: Date | null;
      teacher_id: string | null;
      batch_id: string;
      is_active: boolean | null;
      subject: string | null;
    }>
  > {
    try {
      return await prisma.lecture.findMany({
        where: {
          batch_id: batchId,
          institute_id: instituteId,
          is_active: true,
          ...(subject ? { subject } : {}),
        },
        select: {
          id: true,
          title: true,
          scheduled_at: true,
          duration_minutes: true,
          created_at: true,
          teacher_id: true,
          batch_id: true,
          is_active: true,
          subject: true,
        },
        orderBy: { created_at: 'desc' },
      });
    } catch (error) {
      if (!this.isMissingDurationColumn(error)) throw error;
      return prisma.lecture.findMany({
        where: {
          batch_id: batchId,
          institute_id: instituteId,
          is_active: true,
          ...(subject ? { subject } : {}),
        },
        select: {
          id: true,
          title: true,
          scheduled_at: true,
          created_at: true,
          teacher_id: true,
          batch_id: true,
          is_active: true,
          subject: true,
        },
        orderBy: { created_at: 'desc' },
      });
    }
  }

  static async findById(id: string, instituteId: string) {
    return prisma.lecture.findFirst({
      where: { id, institute_id: instituteId },
    });
  }

  static async update(id: string, instituteId: string, data: Prisma.LectureUncheckedUpdateInput) {
    return prisma.lecture.updateMany({
      where: { id, institute_id: instituteId },
      data,
    });
  }

  static async delete(id: string, instituteId: string) {
    return prisma.lecture.deleteMany({
      where: { id, institute_id: instituteId },
    });
  }
}

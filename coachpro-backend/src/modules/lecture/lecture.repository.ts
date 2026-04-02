import { Prisma } from '@prisma/client';
import { prisma } from '../../server';
import { isLegacyColumnError } from '../../utils/prisma-errors';

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
    batch_id: string,
    institute_id: string,
    subject?: string,
  ): Promise<any[]> {
    try {
      return await prisma.lecture.findMany({
        where: {
          batch_id,
          institute_id,
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
          link: true,
          lecture_type: true,
        },
        orderBy: { created_at: 'desc' },
      });
    } catch (error) {
      if (!isLegacyColumnError(error)) throw error;
      
      const query = `SELECT id::text, title, scheduled_at, duration_minutes, created_at, teacher_id::text, batch_id::text, is_active, subject, link, lecture_type 
                     FROM lectures 
                     WHERE batch_id::uuid = $1::uuid AND institute_id::uuid = $2::uuid AND is_active = true
                     ORDER BY created_at DESC`;
      return prisma.$queryRawUnsafe<any[]>(query, batch_id, institute_id);
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

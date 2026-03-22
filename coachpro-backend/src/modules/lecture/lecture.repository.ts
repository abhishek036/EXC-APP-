import { Prisma } from '@prisma/client';
import { prisma } from '../../server';

export class LectureRepository {
  static async create(data: Prisma.LectureUncheckedCreateInput) {
    return prisma.lecture.create({
      data,
    });
  }

  static async listByBatch(batchId: string, instituteId: string) {
    return prisma.lecture.findMany({
      where: {
        batch_id: batchId,
        institute_id: instituteId,
        is_active: true,
      },
      select: {
        id: true,
        title: true,
        description: true,
        class_room: true,
        link: true,
        scheduled_at: true,
        duration_minutes: true,
        created_at: true,
        teacher_id: true,
        batch_id: true,
        is_active: true,
      },
      orderBy: { created_at: 'desc' },
    });
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

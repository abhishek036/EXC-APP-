import { LectureRepository } from './lecture.repository';
import { Prisma } from '@prisma/client';
import { prisma } from '../../config/prisma';
import { ApiError } from '../../middleware/error.middleware';

export class LectureService {
  static async createLecture(instituteId: string, teacherUserId: string, data: any) {
    const teacher = await prisma.teacher.findFirst({
        where: { user_id: teacherUserId, institute_id: instituteId },
        select: { id: true },
    });
    if (!teacher) throw new ApiError('Teacher profile not found for this account', 404, 'NOT_FOUND');

    const lectureData: Prisma.LectureUncheckedCreateInput = {
      ...data,
      institute_id: instituteId,
      teacher_id: teacher.id,
    };
    return LectureRepository.create(lectureData);
  }

  static async listLectures(batchId: string, instituteId: string, subject?: string) {
    const lectures = await LectureRepository.listByBatch(batchId, instituteId, subject);
    return lectures.map((l: any) => ({
      ...l,
      teacher_name: l.teacher?.name || 'Teacher',
    }));
  }

  static async updateLecture(id: string, instituteId: string, data: any) {
    const lecture = await LectureRepository.findById(id, instituteId);
    if (!lecture) throw new Error('Lecture not found');

    return LectureRepository.update(id, instituteId, data);
  }

  static async deleteLecture(id: string, instituteId: string) {
    const lecture = await LectureRepository.findById(id, instituteId);
    if (!lecture) throw new Error('Lecture not found');

    return LectureRepository.delete(id, instituteId);
  }
}

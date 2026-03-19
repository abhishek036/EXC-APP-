import { LectureRepository } from './lecture.repository';
import { Prisma } from '@prisma/client';

export class LectureService {
  static async createLecture(instituteId: string, teacherId: string, data: any) {
    const lectureData: Prisma.LectureUncheckedCreateInput = {
      ...data,
      institute_id: instituteId,
      teacher_id: teacherId,
    };
    return LectureRepository.create(lectureData);
  }

  static async listLectures(batchId: string, instituteId: string) {
    return LectureRepository.listByBatch(batchId, instituteId);
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

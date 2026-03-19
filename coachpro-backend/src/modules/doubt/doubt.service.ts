import { DoubtRepository } from './doubt.repository';
import { Prisma } from '@prisma/client';

export class DoubtService {
  static async askDoubt(instituteId: string, studentId: string, data: any) {
    // We should ideally fetch the teacher associated with the batch
    const doubtData: Prisma.DoubtUncheckedCreateInput = {
      ...data,
      student_id: studentId,
      institute_id: instituteId,
      status: 'pending',
    };
    return DoubtRepository.create(doubtData);
  }

  static async listDoubts(userId: string, instituteId: string, role: string) {
    if (role === 'student') {
      return DoubtRepository.listForStudent(userId, instituteId);
    } else if (role === 'teacher') {
      // In a real app we might want to automatically assign doubts based on batch
      return DoubtRepository.listForTeacher(userId, instituteId);
    } else {
      // Admins see all pending
      return DoubtRepository.listAllPending(instituteId);
    }
  }

  static async answerDoubt(id: string, instituteId: string, teacherId: string, data: any) {
    const doubt = await DoubtRepository.findById(id, instituteId);
    if (!doubt) throw new Error('Doubt not found');

    const updateData: Prisma.DoubtUncheckedUpdateInput = {
      ...data,
      assigned_to_id: teacherId,
      status: 'resolved',
      resolved_at: new Date(),
    };

    return DoubtRepository.update(id, instituteId, updateData);
  }

  static async resolveDoubt(id: string, instituteId: string) {
    const doubt = await DoubtRepository.findById(id, instituteId);
    if (!doubt) throw new Error('Doubt not found');

    return DoubtRepository.update(id, instituteId, {
      status: 'resolved',
      resolved_at: new Date(),
    });
  }
}

import { DoubtRepository } from './doubt.repository';
import { Prisma } from '@prisma/client';
import { prisma } from '../../server';

export class DoubtService {
  static async askDoubt(instituteId: string, userId: string, data: any) {
    const student = await prisma.student.findFirst({
      where: { user_id: userId, institute_id: instituteId },
      select: { id: true },
    });
    if (!student) throw new Error('Student profile not found');

    // We should ideally fetch the teacher associated with the batch
    const doubtData: Prisma.DoubtUncheckedCreateInput = {
      ...data,
      student_id: student.id,
      institute_id: instituteId,
      status: 'pending',
    };
    return DoubtRepository.create(doubtData);
  }

  static async listDoubts(userId: string, instituteId: string, role: string, status?: string) {
    if (role === 'student') {
      const student = await prisma.student.findFirst({
        where: { user_id: userId, institute_id: instituteId },
        select: { id: true },
      });
      if (!student) return [];
      return DoubtRepository.listForStudent(student.id, instituteId);
    } else if (role === 'teacher') {
      const teacher = await prisma.teacher.findFirst({
        where: { user_id: userId, institute_id: instituteId },
        select: { id: true },
      });
      if (!teacher) return [];
      return DoubtRepository.listForTeacher(teacher.id, instituteId, status);
    } else {
      // Admins see all pending by default, or explicit status when requested
      return DoubtRepository.listAllPending(instituteId, status);
    }
  }

  static async answerDoubt(id: string, instituteId: string, userId: string, data: any) {
    const teacher = await prisma.teacher.findFirst({
      where: { user_id: userId, institute_id: instituteId },
      select: { id: true },
    });
    if (!teacher) throw new Error('Teacher profile not found');

    const doubt = await DoubtRepository.findById(id, instituteId);
    if (!doubt) throw new Error('Doubt not found');

    const updateData: Prisma.DoubtUncheckedUpdateInput = {
      ...data,
      assigned_to_id: teacher.id,
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

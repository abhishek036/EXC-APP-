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

    const result = await DoubtRepository.update(id, instituteId, updateData);

    // 4. Notify Student
    try {
      const fullDoubt = await prisma.doubt.findUnique({
        where: { id },
        include: { student: { select: { user_id: true } } }
      });
      if (fullDoubt?.student?.user_id) {
        await (async () => {
             const { NotificationService } = require('../notification/notification.service');
             await NotificationService.sendNotificationToUser(fullDoubt.student.user_id, {
               title: 'Doubt Answered',
               body: `A teacher has replied to your doubt: "${fullDoubt.question_text.substring(0, 50)}..."`,
               type: 'doubt',
               role_target: 'student',
               institute_id: instituteId,
               meta: {
                 route: '/student/doubts/history',
                 doubt_id: id
               }
             });
        })();
      }
    } catch (e) {
      console.error('[DoubtService] Push failed:', e);
    }

    return result;
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

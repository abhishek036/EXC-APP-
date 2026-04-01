import { DoubtRepository } from './doubt.repository';
import { Prisma } from '@prisma/client';
import { prisma } from '../../server';
import { ApiError } from '../../middleware/error.middleware';

export class DoubtService {
  static async askDoubt(instituteId: string, userId: string, data: any) {
    const student = await prisma.student.findFirst({
      where: { user_id: userId, institute_id: instituteId },
      select: { id: true },
    });
    if (!student) throw new ApiError('Student profile not found', 404, 'NOT_FOUND');

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
    if (!teacher) throw new ApiError('Teacher profile not found', 404, 'NOT_FOUND');

    const doubt = await DoubtRepository.findById(id, instituteId);
    if (!doubt) throw new ApiError('Doubt not found', 404, 'NOT_FOUND');

    // 4. Batch Authorization Check
    const batch = await prisma.batch.findUnique({
      where: { id: doubt.batch_id, institute_id: instituteId },
      include: { institute: { select: { settings: true } } }
    });

    if (batch) {
      const metaMap = (batch.institute.settings as any)?.batch_meta || {};
      const meta = metaMap[batch.id] || {};
      const assignedTeacherIds = Array.isArray(meta.teacher_ids) ? meta.teacher_ids : [];

      if (batch.teacher_id !== teacher.id && !assignedTeacherIds.includes(teacher.id)) {
        throw new ApiError('You are not authorized to answer this doubt', 403, 'FORBIDDEN');
      }
    }

    const updateData: Prisma.DoubtUncheckedUpdateInput = {
      ...data,
      assigned_to_id: teacher.id,
      status: 'resolved',
      resolved_at: new Date(),
    };

    const result = await DoubtRepository.update(id, instituteId, updateData);

    // 4. Notify Student
    try {
      const doubtWithStudent = await DoubtRepository.findById(id, instituteId);
      if (doubtWithStudent) {
        const student = await prisma.student.findUnique({
          where: { id: doubtWithStudent.student_id },
          select: { user_id: true }
        });
        
        if (student?.user_id) {
          const { NotificationService } = require('../notification/notification.service');
          await NotificationService.sendNotificationToUser(student.user_id, {
            title: 'Doubt Answered',
            body: `A teacher has replied to your doubt: "${(doubtWithStudent.question_text || 'doubt').substring(0, 50)}..."`,
            type: 'doubt',
            role_target: 'student',
            institute_id: instituteId,
            meta: {
              route: '/student/doubts/history',
              doubt_id: id
            }
          });
        }
      }
    } catch (e) {
      console.error('[DoubtService] Push failed:', e);
    }

    return result;
  }

  static async resolveDoubt(id: string, instituteId: string) {
    const doubt = await DoubtRepository.findById(id, instituteId);
    if (!doubt) throw new ApiError('Doubt not found', 404, 'NOT_FOUND');

    const result = await DoubtRepository.update(id, instituteId, {
      status: 'resolved',
      resolved_at: new Date(),
    });

    // Notify student
    try {
       const doubtWithStudent = await DoubtRepository.findById(id, instituteId);
       if (doubtWithStudent) {
         const student = await prisma.student.findUnique({
           where: { id: doubtWithStudent.student_id },
           select: { user_id: true }
         });

         if (student?.user_id) {
           const { NotificationService } = require('../notification/notification.service');
           await NotificationService.sendNotificationToUser(student.user_id, {
             title: 'Doubt Resolved',
             body: `Your doubt has been marked as resolved.`,
             type: 'doubt',
             role_target: 'student',
             institute_id: instituteId,
             meta: {
               route: '/student/doubts/history',
               doubt_id: id
             }
           });
         }
       }
    } catch (e) {
      console.error('[DoubtService] Resolve push failed:', e);
    }

    return result;
  }
}

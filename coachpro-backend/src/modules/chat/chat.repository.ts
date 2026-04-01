import { prisma } from '../../server';

export class ChatRepository {
  static async canAccessBatch(userId: string, role: string, instituteId: string, batchId: string): Promise<boolean> {
    const normalizedRole = (role || '').toLowerCase();

    if (normalizedRole === 'admin') {
      const batch = await prisma.batch.findFirst({
        where: { id: batchId, institute_id: instituteId, is_active: true },
        select: { id: true }
      });
      return Boolean(batch);
    }

    if (normalizedRole === 'teacher') {
      const teacher = await prisma.teacher.findFirst({
        where: { user_id: userId, institute_id: instituteId },
        select: { id: true }
      });
      if (!teacher) return false;

      const batch = await prisma.batch.findFirst({
        where: { id: batchId, institute_id: instituteId, teacher_id: teacher.id, is_active: true },
        select: { id: true }
      });
      return Boolean(batch);
    }

    if (normalizedRole === 'student') {
      const student = await prisma.student.findFirst({
        where: { user_id: userId, institute_id: instituteId },
        select: { id: true }
      });
      if (!student) return false;

      const membership = await prisma.studentBatch.findFirst({
        where: { student_id: student.id, batch_id: batchId, is_active: true },
        select: { id: true }
      });
      return Boolean(membership);
    }

    if (normalizedRole === 'parent') {
      const parent = await prisma.parent.findFirst({
        where: { user_id: userId, institute_id: instituteId },
        select: { id: true }
      });
      if (!parent) return false;

      const membership = await prisma.studentBatch.findFirst({
        where: {
          batch_id: batchId,
          is_active: true,
          student: {
            parent_students: {
              some: { parent_id: parent.id },
            },
          },
        },
        select: { id: true }
      });
      return Boolean(membership);
    }

    return false;
  }

  static async getHistory(batchId: string, instituteId: string, limit: number = 50, before?: string) {
    return prisma.chatMessage.findMany({
      where: {
        batch_id: batchId,
        institute_id: instituteId,
        ...(before ? { id: { lt: before } } : {}),
      },
      orderBy: { created_at: 'desc' },
      take: limit,
    });
  }

  static async sendMessage(data: {
    batchId: string;
    instituteId: string;
    senderId: string;
    senderName: string;
    senderRole: string;
    message?: string;
    imageUrl?: string;
  }) {
    return prisma.chatMessage.create({
      data: {
        batch_id: data.batchId,
        institute_id: data.instituteId,
        sender_id: data.senderId,
        sender_name: data.senderName,
        sender_role: data.senderRole,
        message: data.message,
        image_url: data.imageUrl,
      },
    });
  }

  static async deleteMessage(id: string, instituteId: string) {
    return prisma.chatMessage.deleteMany({
      where: { id, institute_id: instituteId },
    });
  }

  /**
   * "Chat rooms" are batches, so we return the batches that this user belongs to.
   * Students: batches they are enrolled in.
   * Teachers: batches they teach.
   * Admin: all batches.
   */
  static async getRoomsForStudent(userId: string, instituteId: string) {
    const student = await prisma.student.findFirst({
      where: { user_id: userId, institute_id: instituteId }
    });
    if (!student) return [];

    const batches = await prisma.studentBatch.findMany({
      where: { student_id: student.id, is_active: true },
      include: {
        batch: {
          select: {
            id: true,
            name: true,
            subject: true,
            _count: { select: { chat_messages: true } }
          }
        }
      }
    });

    return batches.map(sb => ({
      id: sb.batch.id,
      name: sb.batch.name,
      subject: sb.batch.subject,
      message_count: sb.batch._count.chat_messages,
      type: 'batch',
    }));
  }

  static async getRoomsForTeacher(userId: string, instituteId: string) {
    const teacher = await prisma.teacher.findFirst({
      where: { user_id: userId, institute_id: instituteId }
    });
    if (!teacher) return [];

    const batches = await prisma.batch.findMany({
      where: { teacher_id: teacher.id, institute_id: instituteId, is_active: true },
      select: {
        id: true,
        name: true,
        subject: true,
        _count: { select: { chat_messages: true, student_batches: { where: { is_active: true } } } }
      }
    });

    return batches.map(b => ({
      id: b.id,
      name: b.name,
      subject: b.subject,
      message_count: b._count.chat_messages,
      student_count: b._count.student_batches,
      type: 'batch',
    }));
  }

  static async getRoomsForAdmin(instituteId: string) {
    const batches = await prisma.batch.findMany({
      where: { institute_id: instituteId, is_active: true },
      select: {
        id: true,
        name: true,
        subject: true,
        _count: { select: { chat_messages: true, student_batches: { where: { is_active: true } } } }
      }
    });

    return batches.map(b => ({
      id: b.id,
      name: b.name,
      subject: b.subject,
      message_count: b._count.chat_messages,
      student_count: b._count.student_batches,
      type: 'batch',
    }));
  }

  static async getRoomsForParent(userId: string, instituteId: string) {
    const parent = await prisma.parent.findFirst({
      where: { user_id: userId, institute_id: instituteId }
    });
    if (!parent) return [];

    const batches = await prisma.studentBatch.findMany({
      where: {
        is_active: true,
        student: {
          parent_students: {
            some: { parent_id: parent.id }
          }
        }
      },
      include: {
        batch: {
          select: {
            id: true,
            name: true,
            subject: true,
            _count: { select: { chat_messages: true } }
          }
        }
      }
    });

    const unique = new Map<string, { id: string; name: string; subject: string | null; message_count: number; type: string }>();
    for (const sb of batches) {
      if (!unique.has(sb.batch.id)) {
        unique.set(sb.batch.id, {
          id: sb.batch.id,
          name: sb.batch.name,
          subject: sb.batch.subject,
          message_count: sb.batch._count.chat_messages,
          type: 'batch',
        });
      }
    }

    return Array.from(unique.values());
  }
}

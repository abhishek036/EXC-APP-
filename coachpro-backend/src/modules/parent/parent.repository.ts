import { prisma } from '../../server';
import { buildPhoneVariants, normalizeIndianPhone } from '../../utils/phone';

export class ParentRepository {
  async findParentByUserId(userId: string, instituteId: string) {
    return prisma.parent.findFirst({
      where: { user_id: userId, institute_id: instituteId },
      include: {
        user: {
          select: {
            id: true,
            status: true,
            is_active: true,
            phone: true,
          },
        },
      },
    });
  }

  async findParentByUserIdOrPhone(userId: string, instituteId: string, phone?: string | null) {
    const byUser = await this.findParentByUserId(userId, instituteId);
    if (byUser) return byUser;

    const normalizedPhone = normalizeIndianPhone(phone);
    if (!normalizedPhone) return null;

    return prisma.parent.findFirst({
      where: {
        institute_id: instituteId,
        phone: { in: buildPhoneVariants(normalizedPhone) },
      },
      include: {
        user: {
          select: {
            id: true,
            status: true,
            is_active: true,
            phone: true,
          },
        },
      },
    });
  }

  async getParentStudents(instituteId: string, parentId: string) {
    const links = await prisma.parentStudent.findMany({
      where: {
        parent_id: parentId,
        parent: { institute_id: instituteId },
      },
      include: {
        student: {
          include: {
            student_batches: {
              where: { is_active: true },
              include: { batch: { include: { teacher: { select: { name: true } } } } },
            },
          },
        },
      },
    });

    return links.map((entry) => entry.student);
  }

  async getChildren(userId: string, instituteId: string) {
     const parent = await this.findParentByUserId(userId, instituteId);
     if (!parent) return [];
     return this.getParentStudents(instituteId, parent.id);
  }

  async findParentByUserIdDetailed(userId: string, instituteId: string) {
    const parent = await this.findParentByUserId(userId, instituteId);
    if (!parent) return null;

    const students = await this.getParentStudents(instituteId, parent.id);
    return {
      ...parent,
      parent_students: students.map((student) => ({ student })),
    };
  }
}

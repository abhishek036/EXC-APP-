import { prisma } from '../../server';
import { ApiError } from '../../middleware/error.middleware';

export class ParentRepository {
  async findParentByUserId(userId: string, instituteId: string) {
    return prisma.parent.findFirst({
      where: { user_id: userId, institute_id: instituteId },
      include: {
        parent_students: {
          include: {
            student: {
              include: {
                student_batches: {
                  where: { is_active: true },
                  include: { batch: { include: { teacher: { select: { name: true } } } } }
                }
              }
            }
          }
        }
      }
    } as any);
  }

  async getChildren(userId: string, instituteId: string) {
     const parent = await prisma.parent.findFirst({
        where: { user_id: userId, institute_id: instituteId },
        include: {
           parent_students: {
              include: {
                 student: true
              }
           }
        }
     });
     if (!parent) return [];
     return parent.parent_students.map(ps => ps.student);
  }
}

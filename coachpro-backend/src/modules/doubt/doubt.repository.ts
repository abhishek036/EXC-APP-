import { Prisma } from '@prisma/client';
import { prisma } from '../../server';

export class DoubtRepository {
  static async create(data: Prisma.DoubtUncheckedCreateInput) {
    return prisma.doubt.create({
      data,
    });
  }

  static async listForStudent(studentId: string, instituteId: string) {
    return prisma.doubt.findMany({
      where: {
        student_id: studentId,
        institute_id: instituteId,
      },
      include: {
        batch: { select: { name: true } },
        assigned_to: { select: { name: true, photo_url: true } },
      },
      orderBy: { created_at: 'desc' },
    });
  }

  static async listForTeacher(teacherId: string, instituteId: string, status?: string) {
    return prisma.doubt.findMany({
      where: {
        assigned_to_id: teacherId,
        institute_id: instituteId,
        ...(status ? { status } : {}),
      },
      include: {
        batch: { select: { name: true } },
        student: { select: { name: true, photo_url: true } },
      },
      orderBy: [
        { status: 'asc' }, // 'pending' first (p vs r)
        { created_at: 'asc' },
      ],
    });
  }

  static async listAllPending(instituteId: string, status?: string) {
    return prisma.doubt.findMany({
      where: {
         institute_id: instituteId,
         ...(status ? { status } : { status: 'pending' }),
      },
      include: {
        batch: { select: { name: true, teacher_id: true } },
        student: { select: { name: true } }
      }
    });
  }

  static async findById(id: string, instituteId: string) {
    return prisma.doubt.findFirst({
      where: { id, institute_id: instituteId },
    });
  }

  static async update(id: string, instituteId: string, data: Prisma.DoubtUncheckedUpdateInput) {
    return prisma.doubt.updateMany({
      where: { id, institute_id: instituteId },
      data,
    });
  }
}

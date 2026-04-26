import { prisma } from '../../config/prisma';
import { CreateBatchInput, UpdateBatchInput } from './batch.validator';

export class BatchRepository {
  private normalizeBatchData(data: CreateBatchInput | UpdateBatchInput) {
    const normalized: Record<string, unknown> = { ...data };

    const toTimeValue = (value: unknown) => {
      if (typeof value !== 'string' || value.length === 0) return value;
      if (value.includes('T')) return new Date(value);
      return new Date(`1970-01-01T${value}.000Z`);
    };

    const toDateValue = (value: unknown) => {
      if (typeof value !== 'string' || value.length === 0) return value;
      return new Date(value);
    };

    if ('start_time' in normalized) {
      normalized['start_time'] = toTimeValue(normalized['start_time']);
    }
    if ('end_time' in normalized) {
      normalized['end_time'] = toTimeValue(normalized['end_time']);
    }
    if ('start_date' in normalized) {
      normalized['start_date'] = toDateValue(normalized['start_date']);
    }
    if ('end_date' in normalized) {
      normalized['end_date'] = toDateValue(normalized['end_date']);
    }

    return normalized;
  }

  async listBatches(instituteId: string, subject?: string, teacherId?: string, batchIds?: string[]) {
    const whereClause: any = { institute_id: instituteId };
    
    if (subject) whereClause.subject = { contains: subject, mode: 'insensitive' };
    if (teacherId) whereClause.teacher_id = teacherId;
    if ((batchIds ?? []).length > 0) whereClause.id = { in: batchIds };

    return prisma.batch.findMany({
      where: whereClause,
      include: {
        teacher: { select: { id: true, name: true } },
        _count: { select: { student_batches: { where: { is_active: true } } } }
      },
      orderBy: { created_at: 'desc' }
    });
  }

  async findBatchById(batchId: string, instituteId: string) {
    return prisma.batch.findFirst({
      where: { id: batchId, institute_id: instituteId },
      include: {
        teacher: { select: { id: true, name: true, photo_url: true } },
        student_batches: {
          where: { is_active: true },
          include: { student: { select: { id: true, name: true, photo_url: true, phone: true } } }
        }
      }
    });
  }

  async createBatch(instituteId: string, data: CreateBatchInput) {
    return prisma.batch.create({
      data: {
        ...this.normalizeBatchData(data),
        institute_id: instituteId,
      } as any
    });
  }

  async updateBatch(batchId: string, instituteId: string, data: UpdateBatchInput) {
    return prisma.batch.update({
      where: { id: batchId },
      // The architecture mandates everything respects institute_id isolation
      // Ensure we don't update if it doesn't belong to this institute (checked upstream)
      data: this.normalizeBatchData(data) as any
    });
  }

  async deleteBatch(batchId: string) {
    return prisma.$transaction(async (tx) => {
      await tx.feePayment.deleteMany({
        where: { fee_record: { batch_id: batchId } },
      });

      await tx.feeRecord.deleteMany({
        where: { batch_id: batchId },
      });

      await tx.attendanceRecord.deleteMany({
        where: { session: { batch_id: batchId } },
      });

      await tx.attendanceSession.deleteMany({
        where: { batch_id: batchId },
      });

      await tx.quizAttempt.deleteMany({
        where: { quiz: { batch_id: batchId } },
      });

      await tx.quizQuestion.deleteMany({
        where: { quiz: { batch_id: batchId } },
      });

      await tx.quiz.deleteMany({
        where: { batch_id: batchId },
      });

      await tx.studentSyllabusProgress.deleteMany({
        where: { topic: { batch_id: batchId } },
      });

      await tx.syllabusTopic.deleteMany({
        where: { batch_id: batchId },
      });

      await tx.examBatch.deleteMany({
        where: { batch_id: batchId },
      });

      await tx.note.deleteMany({
        where: { batch_id: batchId },
      });

      await tx.assignment.deleteMany({
        where: { batch_id: batchId },
      });

      await tx.doubt.deleteMany({
        where: { batch_id: batchId },
      });

      await tx.chatMessage.deleteMany({
        where: { batch_id: batchId },
      });

      await tx.lecture.deleteMany({
        where: { batch_id: batchId },
      });

      await tx.announcement.updateMany({
        where: { target_batch_id: batchId },
        data: { target_batch_id: null },
      });

      await tx.studentBatch.deleteMany({
        where: { batch_id: batchId },
      });

      await tx.feeStructure.deleteMany({
        where: { batch_id: batchId },
      });

      return tx.batch.delete({ where: { id: batchId } });
    });
  }

  async toggleStatus(batchId: string, isActive: boolean) {
    return prisma.batch.update({
      where: { id: batchId },
      data: { is_active: isActive }
    });
  }

  // Enrollment Logic
  async addStudentToBatch(studentId: string, batchId: string, instituteId: string) {
    return prisma.studentBatch.upsert({
      where: { student_id_batch_id: { student_id: studentId, batch_id: batchId } },
      update: { is_active: true, left_date: null }, // Re-activate if previously left
      create: { student_id: studentId, batch_id: batchId, institute_id: instituteId }
    });
  }

  async removeStudentFromBatch(studentId: string, batchId: string) {
    return prisma.studentBatch.update({
      where: { student_id_batch_id: { student_id: studentId, batch_id: batchId } },
      data: { is_active: false, left_date: new Date() }
    });
  }

  async addStudentsToBatch(studentIds: string[], batchId: string, instituteId: string) {
    const results = await Promise.all(
      studentIds.map((studentId) =>
        prisma.studentBatch.upsert({
          where: { student_id_batch_id: { student_id: studentId, batch_id: batchId } },
          update: { is_active: true, left_date: null },
          create: { student_id: studentId, batch_id: batchId, institute_id: instituteId },
        })
      )
    );

    return results;
  }
}

import { Prisma } from '@prisma/client';
import { prisma } from '../../server';

export class DoubtRepository {
  private static isLegacyDoubtSubjectColumnError(error: unknown): boolean {
    const code = (error as any)?.code;
    const column = String((error as any)?.meta?.column ?? '').toLowerCase();
    return code === 'P2022' && column.includes('doubts.subject');
  }

  private static mapDoubtRow(row: any) {
    return {
      id: row.id,
      batch_id: row.batch_id,
      student_id: row.student_id,
      institute_id: row.institute_id,
      assigned_to_id: row.assigned_to_id,
      question_text: row.question_text,
      question_img: row.question_img,
      answer_text: row.answer_text,
      answer_img: row.answer_img,
      status: row.status,
      created_at: row.created_at,
      resolved_at: row.resolved_at,
      batch: row.batch_name
        ? {
            name: row.batch_name,
            ...(row.batch_teacher_id !== undefined ? { teacher_id: row.batch_teacher_id } : {}),
          }
        : undefined,
      student: row.student_name
        ? {
            name: row.student_name,
            ...(row.student_photo_url !== undefined ? { photo_url: row.student_photo_url } : {}),
          }
        : undefined,
      assigned_to: row.assigned_teacher_name
        ? {
            name: row.assigned_teacher_name,
            ...(row.assigned_teacher_photo_url !== undefined ? { photo_url: row.assigned_teacher_photo_url } : {}),
          }
        : undefined,
    };
  }

  private static async createLegacy(data: Prisma.DoubtUncheckedCreateInput) {
    const rows = await prisma.$queryRawUnsafe<any[]>(
      `INSERT INTO doubts (
          batch_id,
          student_id,
          institute_id,
          assigned_to,
          question_text,
          question_img,
          answer_text,
          answer_img,
          status,
          resolved_at
       ) VALUES (
          $1::uuid,
          $2::uuid,
          $3::uuid,
          $4::uuid,
          $5,
          $6,
          $7,
          $8,
          $9,
          $10
       )
       RETURNING id::text, batch_id::text, student_id::text, institute_id::text, assigned_to::text as assigned_to_id,
                 question_text, question_img, answer_text, answer_img, status, created_at, resolved_at`,
      data.batch_id,
      data.student_id,
      data.institute_id,
      data.assigned_to_id ?? null,
      data.question_text,
      data.question_img ?? null,
      data.answer_text ?? null,
      data.answer_img ?? null,
      data.status ?? 'pending',
      data.resolved_at ?? null,
    );

    return this.mapDoubtRow(rows[0]);
  }

  private static async listForStudentLegacy(studentId: string, instituteId: string) {
    const rows = await prisma.$queryRawUnsafe<any[]>(
      `SELECT d.id::text,
              d.batch_id::text,
              d.student_id::text,
              d.institute_id::text,
              d.assigned_to::text as assigned_to_id,
              d.question_text,
              d.question_img,
              d.answer_text,
              d.answer_img,
              d.status,
              d.created_at,
              d.resolved_at,
              b.name as batch_name,
              t.name as assigned_teacher_name,
              t.photo_url as assigned_teacher_photo_url
       FROM doubts d
       LEFT JOIN batches b ON b.id = d.batch_id
       LEFT JOIN teachers t ON t.id = d.assigned_to
       WHERE d.student_id::text = $1::text
         AND d.institute_id::text = $2::text
       ORDER BY d.created_at DESC`,
      studentId,
      instituteId,
    );

    return rows.map((row) => this.mapDoubtRow(row));
  }

  private static async listForTeacherLegacy(teacherId: string, instituteId: string, status?: string) {
    const rows = await prisma.$queryRawUnsafe<any[]>(
      `SELECT d.id::text,
              d.batch_id::text,
              d.student_id::text,
              d.institute_id::text,
              d.assigned_to::text as assigned_to_id,
              d.question_text,
              d.question_img,
              d.answer_text,
              d.answer_img,
              d.status,
              d.created_at,
              d.resolved_at,
              b.name as batch_name,
              s.name as student_name,
              s.photo_url as student_photo_url
       FROM doubts d
       LEFT JOIN batches b ON b.id = d.batch_id
       LEFT JOIN students s ON s.id = d.student_id
       WHERE d.institute_id::text = $1::text
         AND ($2::text IS NULL OR d.status = $2)
         AND (
           d.assigned_to::text = $3::text
           OR b.teacher_id::text = $3::text
         )
       ORDER BY d.status ASC, d.created_at ASC`,
      instituteId,
      status ?? null,
      teacherId,
    );

    return rows.map((row) => this.mapDoubtRow(row));
  }

  private static async listAllPendingLegacy(instituteId: string, status?: string) {
    const rows = await prisma.$queryRawUnsafe<any[]>(
      `SELECT d.id::text,
              d.batch_id::text,
              d.student_id::text,
              d.institute_id::text,
              d.assigned_to::text as assigned_to_id,
              d.question_text,
              d.question_img,
              d.answer_text,
              d.answer_img,
              d.status,
              d.created_at,
              d.resolved_at,
              b.name as batch_name,
              b.teacher_id::text as batch_teacher_id,
              s.name as student_name
       FROM doubts d
       LEFT JOIN batches b ON b.id = d.batch_id
       LEFT JOIN students s ON s.id = d.student_id
       WHERE d.institute_id::text = $1::text
         AND d.status = COALESCE($2::text, 'pending')`,
      instituteId,
      status ?? null,
    );

    return rows.map((row) => this.mapDoubtRow(row));
  }

  static async create(data: Prisma.DoubtUncheckedCreateInput) {
    try {
      return await prisma.doubt.create({
        data,
      });
    } catch (error) {
      if (!this.isLegacyDoubtSubjectColumnError(error)) throw error;
      return this.createLegacy(data);
    }
  }

  static async listForStudent(studentId: string, instituteId: string) {
    try {
      return await prisma.doubt.findMany({
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
    } catch (error) {
      if (!this.isLegacyDoubtSubjectColumnError(error)) throw error;
      return this.listForStudentLegacy(studentId, instituteId);
    }
  }

  static async listForTeacher(teacherId: string, instituteId: string, status?: string) {
    try {
      return await prisma.doubt.findMany({
        where: {
          institute_id: instituteId,
          ...(status ? { status } : {}),
          OR: [
            { assigned_to_id: teacherId },
            { batch: { teacher_id: teacherId } }
          ]
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
    } catch (error) {
      if (!this.isLegacyDoubtSubjectColumnError(error)) throw error;
      return this.listForTeacherLegacy(teacherId, instituteId, status);
    }
  }

  static async listAllPending(instituteId: string, status?: string) {
    try {
      return await prisma.doubt.findMany({
        where: {
           institute_id: instituteId,
           ...(status ? { status } : { status: 'pending' }),
        },
        include: {
          batch: { select: { name: true, teacher_id: true } },
          student: { select: { name: true } }
        }
      });
    } catch (error) {
      if (!this.isLegacyDoubtSubjectColumnError(error)) throw error;
      return this.listAllPendingLegacy(instituteId, status);
    }
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

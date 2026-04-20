import { StudentRepository } from './student.repository';
import { CreateStudentInput, UpdateStudentInput } from './student.validator';
import { ApiError } from '../../middleware/error.middleware';
import { prisma } from '../../server';
import { normalizeIndianPhone } from '../../utils/phone';
import { resolveTeacherScope } from '../../utils/teacher-scope';

export class StudentService {
  private studentRepository: StudentRepository;

  constructor() {
    this.studentRepository = new StudentRepository();
  }

  private phoneVariants(phone: string): string[] {
    const cleaned = (phone || '').replace(/[\s\-()]/g, '');
    if (!cleaned) return [];

    const variants = new Set<string>([cleaned]);
    if (cleaned.startsWith('+91') && cleaned.length >= 13) {
      variants.add(cleaned.substring(3));
    }
    if (cleaned.startsWith('91') && cleaned.length === 12) {
      const ten = cleaned.substring(2);
      variants.add(ten);
      variants.add(`+91${ten}`);
    }
    if (/^\d{10}$/.test(cleaned)) {
      variants.add(`+91${cleaned}`);
      variants.add(`91${cleaned}`);
    }

    return Array.from(variants);
  }

  private canonicalPhone(phone?: string): string | undefined {
    if (!phone) return undefined;
    const cleaned = phone.replace(/[\s\-()]/g, '');
    if (cleaned.startsWith('+91') && cleaned.length >= 13) return cleaned.substring(3);
    if (cleaned.startsWith('91') && cleaned.length === 12) return cleaned.substring(2);
    return cleaned;
  }

  private async ensureBatchCapacity(instituteId: string, batchId: string, studentId?: string) {
    const { prisma } = require('../../server');

    const batch = await prisma.batch.findUnique({
      where: { id: batchId },
      select: { id: true, name: true, capacity: true, institute_id: true },
    });

    if (!batch || batch.institute_id !== instituteId) {
      throw new ApiError('Batch not found', 404, 'NOT_FOUND');
    }

    if (!batch.capacity) return;

    const existingMembership = studentId
      ? await prisma.studentBatch.findFirst({
          where: { student_id: studentId, batch_id: batchId, is_active: true },
          select: { id: true },
        })
      : null;

    if (existingMembership) return;

    const activeCount = await prisma.studentBatch.count({
      where: { batch_id: batchId, institute_id: instituteId, is_active: true },
    });

    if (activeCount >= batch.capacity) {
      throw new ApiError(`Batch "${batch.name}" is already full (Capacity: ${batch.capacity})`, 400, 'BATCH_FULL');
    }
  }

  async listStudents(
    instituteId: string,
    query: { name?: string; phone?: string; batchId?: string; isActive?: boolean; page?: number; perPage?: number },
    actor?: { role?: string; userId?: string },
  ) {
    const page = parseInt(query.page as any) || 1;
    const perPage = parseInt(query.perPage as any) || 20;
    const skip = (page - 1) * perPage;

    const normalizedRole = (actor?.role ?? '').trim().toLowerCase();
    let scopedBatchIds: string[] | undefined;

    if (normalizedRole === 'teacher') {
      if (!actor?.userId) {
        throw new ApiError('Unauthorized teacher access', 401, 'UNAUTHORIZED');
      }

      const teacherScope = await resolveTeacherScope(instituteId, actor.userId);

      if (query.batchId && !teacherScope.batchIds.includes(query.batchId)) {
        throw new ApiError('You can only access students from your assigned batches', 403, 'FORBIDDEN');
      }

      scopedBatchIds = query.batchId ? [query.batchId] : teacherScope.batchIds;

      if (scopedBatchIds.length === 0) {
        return {
          data: [],
          meta: {
            page,
            perPage,
            total: 0,
            totalPages: 0,
          },
        };
      }
    }

    const { students, total } = await this.studentRepository.listStudents(
        instituteId, 
        {
          name: query.name,
          phone: query.phone,
          batchId: query.batchId,
          batchIds: scopedBatchIds,
          isActive: query.isActive,
        }, 
        { skip, take: perPage }
    );
    
    return {
      data: students.map(s => ({
        ...s,
        parent_phone: (s as any).parent_students?.[0]?.parent?.phone ?? null,
        parent_status:
          (s as any).parent_students?.[0]?.parent?.user?.status === 'ACTIVE'
            ? 'Joined'
            : ((s as any).parent_students?.[0]?.parent ? 'Not Joined' : null),
        parent_relation: (s as any).parent_students?.[0]?.relation ?? null,
        parent_profile_id: (s as any).parent_students?.[0]?.parent?.id ?? null,
        active_batches_count: s._count.student_batches,
        attendancePercent: 0 // In a real app, calculate this or join from record counts
      })),
      meta: {
        page,
        perPage,
        total,
        totalPages: Math.ceil(total / perPage)
      }
    };
  }

  async getStudentDetails(studentId: string, instituteId: string, actor?: { role?: string; userId?: string }) {
    const student = await this.studentRepository.findStudentById(studentId, instituteId);
    if (!student) {
        throw new ApiError('Student not found', 404, 'NOT_FOUND');
    }

    const normalizedRole = (actor?.role ?? '').trim().toLowerCase();
    if (normalizedRole === 'teacher') {
      if (!actor?.userId) {
        throw new ApiError('Unauthorized teacher access', 401, 'UNAUTHORIZED');
      }

      const teacherScope = await resolveTeacherScope(instituteId, actor.userId);
      const studentBatchIds = (student as any).student_batches
        ?.map((entry: any) => String(entry?.batch_id || entry?.batch?.id || ''))
        .filter((value: string) => value.length > 0) || [];

      const hasAllowedBatch = studentBatchIds.some((batchId: string) =>
        teacherScope.batchIds.includes(batchId),
      );

      if (!hasAllowedBatch) {
        throw new ApiError('You can only access students from your assigned batches', 403, 'FORBIDDEN');
      }
    }
    
    // Format output
    const s = student as any;
    return {
       ...s,
       parent_phone: s.parent_students?.[0]?.parent?.phone ?? null,
       parent_status: s.parent_students?.[0]?.parent?.user?.status === 'ACTIVE' ? 'Joined' : (s.parent_students?.[0]?.parent ? 'Not Joined' : null),
       parent_relation: s.parent_students?.[0]?.relation ?? null,
       batches: s.student_batches?.map((sb: any) => sb.batch) || []
    }
  }

  private normalizeParentPhoneOrThrow(parentPhone?: string | null): string | undefined {
    if (parentPhone === undefined) return undefined;
    if (parentPhone === null) return '';

    const trimmed = String(parentPhone || '').trim();
    if (!trimmed) return '';

    const normalized = normalizeIndianPhone(trimmed);
    if (!normalized) {
      throw new ApiError('Invalid parent phone. Use +91XXXXXXXXXX or 10-digit number.', 400, 'INVALID_PARENT_PHONE');
    }

    return normalized;
  }

  async createStudent(instituteId: string, data: CreateStudentInput) {
    const canonicalPhone = this.canonicalPhone(data.phone);
    const normalizedParentPhone = this.normalizeParentPhoneOrThrow(data.parent_phone);
    const normalizedData: CreateStudentInput = {
      ...data,
      ...(canonicalPhone ? { phone: canonicalPhone } : {}),
      ...(normalizedParentPhone !== undefined ? { parent_phone: normalizedParentPhone } : {}),
    };

    // 1. Find existing student by phone variants; if found, reuse/update instead of creating duplicate.
    let existingStudent: any = null;
    if (normalizedData.phone) {
      const matches = await this.studentRepository.findStudentsByPhoneVariants(
        this.phoneVariants(normalizedData.phone),
        instituteId,
      );
      existingStudent =
        matches.find((s: any) => s.user_id) ||
        matches.find((s: any) => s.is_active !== false) ||
        matches[0] ||
        null;
    }

    // Use transaction to prevent race conditions on batch capacity
    return await prisma.$transaction(async (tx) => {
      // 2. Check batch capacity if batch_ids are provided (inside transaction)
      if (normalizedData.batch_ids && normalizedData.batch_ids.length > 0) {
        for (const batchId of normalizedData.batch_ids) {
          await this._ensureBatchCapacityWithTx(tx, instituteId, batchId, existingStudent?.id);
        }
      }

      if (existingStudent) {
        // Update basic details and parent relation on the existing record.
        await this.studentRepository.updateStudent(existingStudent.id, instituteId, {
          name: normalizedData.name,
          phone: normalizedData.phone,
          dob: normalizedData.dob,
          gender: normalizedData.gender,
          address: normalizedData.address,
          blood_group: normalizedData.blood_group,
          prev_institute: normalizedData.prev_institute,
          parent_name: normalizedData.parent_name,
          parent_phone: normalizedData.parent_phone,
          parent_relation: normalizedData.parent_relation,
          // Keep existing enrollments intact; create flow should not drop old batches.
          batch_ids: undefined,
        });

        // Non-destructive batch linking for create-on-existing flow.
        if (normalizedData.batch_ids && normalizedData.batch_ids.length > 0) {
          const uniqueBatchIds = Array.from(new Set(normalizedData.batch_ids.map((id: string) => id.trim())));
          for (const batchId of uniqueBatchIds) {
            await tx.studentBatch.upsert({
              where: { student_id_batch_id: { student_id: existingStudent.id, batch_id: batchId } },
              update: { is_active: true, left_date: null },
              create: { student_id: existingStudent.id, batch_id: batchId, institute_id: instituteId },
            });
          }
        }

        const updated = await this.studentRepository.findStudentById(existingStudent.id, instituteId);
        return updated || existingStudent;
      }

      // 3. Create student
      const createdStudent = await this.studentRepository.createStudentWithUserAndParent(instituteId, normalizedData);

      // 4. Update Lead status if lead_id is provided
      if (normalizedData.lead_id) {
        await tx.lead.update({
          where: { id: normalizedData.lead_id, institute_id: instituteId },
          data: { status: 'Converted' }
        }).catch(err => console.error('Failed to update lead status:', err));
      }

      return createdStudent;
    });
  }

  // Private helper with transaction support for capacity check
  private async _ensureBatchCapacityWithTx(tx: any, instituteId: string, batchId: string, studentId?: string) {
    const batch = await tx.batch.findUnique({
      where: { id: batchId },
      select: { id: true, name: true, capacity: true, institute_id: true },
    });

    if (!batch || batch.institute_id !== instituteId) {
      throw new ApiError('Batch not found', 404, 'NOT_FOUND');
    }

    if (!batch.capacity) return;

    const existingMembership = studentId
      ? await tx.studentBatch.findFirst({
          where: { student_id: studentId, batch_id: batchId, is_active: true },
          select: { id: true },
        })
      : null;

    if (existingMembership) return;

    const activeCount = await tx.studentBatch.count({
      where: { batch_id: batchId, institute_id: instituteId, is_active: true },
    });

    if (activeCount >= batch.capacity) {
      throw new ApiError(`Batch "${batch.name}" is already full (Capacity: ${batch.capacity})`, 400, 'BATCH_FULL');
    }
  }

  async updateStudent(studentId: string, instituteId: string, data: UpdateStudentInput) {
    const student = await this.studentRepository.findStudentById(studentId, instituteId);
    if (!student) throw new ApiError('Student not found', 404, 'NOT_FOUND');

    const incoming = (data ?? {}) as UpdateStudentInput;

    const normalizedPatch: UpdateStudentInput = {
      ...incoming,
      ...(Object.prototype.hasOwnProperty.call(incoming as Record<string, unknown>, 'parent_phone')
        ? { parent_phone: this.normalizeParentPhoneOrThrow((incoming as any).parent_phone) }
        : {}),
    };

    return this.studentRepository.updateStudent(studentId, instituteId, normalizedPatch);
  }

  async changeStatus(studentId: string, instituteId: string, isActive: boolean) {
    const student = await this.studentRepository.findStudentById(studentId, instituteId);
    if (!student) throw new ApiError('Student not found', 404, 'NOT_FOUND');

    return this.studentRepository.toggleStatus(studentId, isActive);
  }

  async importExcel(instituteId: string, fileBuffer: Buffer, batchId?: string) {
    const { parseExcel } = await import('../../utils/excel');
    const data = await parseExcel(fileBuffer);
    
    let processed = 0;
    let errors: string[] = [];

    for (const row of data as any[]) {
      try {
        const studentData: CreateStudentInput = {
          name: row.name || row.Name || row.student_name,
          phone: row.phone?.toString() || row.Phone?.toString() || row.phone_number?.toString(),
          gender: row.gender || row.Gender,
          batch_ids: batchId ? [batchId] : (row.batch_id ? [row.batch_id] : [])
        };

        if (row.parent_name || row.ParentName) {
            studentData.parent_name = row.parent_name || row.ParentName;
            studentData.parent_phone = row.parent_phone?.toString() || row.ParentPhone?.toString();
        }

        if (studentData.name && studentData.phone) {
            await this.createStudent(instituteId, studentData);
            processed++;
        }
      } catch (err: any) {
        errors.push(`Row ${processed + errors.length + 1}: ${err.message}`);
      }
    }

    return { 
      message: `Successfully imported ${processed} students`, 
      errors: errors.length > 0 ? errors : undefined 
    };
  }
}

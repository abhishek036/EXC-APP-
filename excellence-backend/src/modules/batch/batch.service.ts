import { BatchRepository } from './batch.repository';
import { CreateBatchInput, UpdateBatchInput, UpdateBatchMetaInput, MigrateBatchStudentsInput } from './batch.validator';
import { ApiError } from '../../middleware/error.middleware';
import { prisma } from '../../server';
import { resolveTeacherScope } from '../../utils/teacher-scope';
import { resolveBatchTeacherIds } from '../../utils/batch-teacher-assignment';

export class BatchService {
  private batchRepository: BatchRepository;

  constructor() {
    this.batchRepository = new BatchRepository();
  }

  private async getBatchMetaMap(instituteId: string): Promise<Record<string, any>> {
    const institute = await prisma.institute.findUnique({
      where: { id: instituteId },
      select: { settings: true },
    });

    const settings = (institute?.settings ?? {}) as Record<string, any>;
    const batchMeta = settings['batch_meta'];
    if (batchMeta && typeof batchMeta === 'object' && !Array.isArray(batchMeta)) {
      return { ...batchMeta };
    }

    return {};
  }

  private async saveBatchMetaMap(instituteId: string, batchMetaMap: Record<string, any>) {
    const institute = await prisma.institute.findUnique({
      where: { id: instituteId },
      select: { settings: true },
    });
    const settings = ((institute?.settings ?? {}) as Record<string, any>) || {};

    await prisma.institute.update({
      where: { id: instituteId },
      data: {
        settings: {
          ...settings,
          batch_meta: batchMetaMap,
        },
      },
    });
  }

  private async getStoredBatchMeta(instituteId: string, batchId: string): Promise<Record<string, any>> {
    const map = await this.getBatchMetaMap(instituteId);
    const value = map[batchId];
    if (value && typeof value === 'object' && !Array.isArray(value)) {
      return value;
    }
    return {};
  }

  private normalizeIdList(values: unknown[]): string[] {
    return Array.from(new Set(
      values
        .map((value) => String(value ?? '').trim())
        .filter((value) => value.length > 0),
    ));
  }

  private normalizeTeacherIds(data: { teacher_id?: string; teacher_ids?: string[] }): string[] {
    return this.normalizeIdList([data.teacher_id, ...(data.teacher_ids ?? [])]);
  }

  private async buildTeacherIdMap(instituteId: string, rawIds: string[]): Promise<Map<string, string>> {
    const normalizedRawIds = this.normalizeIdList(rawIds);
    const result = new Map<string, string>();
    if (normalizedRawIds.length === 0) return result;

    const teachers = await prisma.teacher.findMany({
      where: {
        institute_id: instituteId,
        OR: [
          { id: { in: normalizedRawIds } },
          { user_id: { in: normalizedRawIds } },
        ],
      },
      select: { id: true, user_id: true },
    });

    for (const teacher of teachers) {
      result.set(teacher.id, teacher.id);
      if (teacher.user_id) result.set(teacher.user_id, teacher.id);
    }

    return result;
  }

  private mapTeacherIds(rawIds: string[], idMap: Map<string, string>): string[] {
    const resolved = new Set<string>();
    for (const rawId of this.normalizeIdList(rawIds)) {
      const canonicalId = idMap.get(rawId);
      if (canonicalId) resolved.add(canonicalId);
    }
    return Array.from(resolved);
  }

  private async resolveTeacherProfileIds(
    instituteId: string,
    rawIds: string[],
    strict = false,
  ): Promise<string[]> {
    const normalizedRawIds = this.normalizeIdList(rawIds);
    if (normalizedRawIds.length === 0) return [];

    const idMap = await this.buildTeacherIdMap(instituteId, normalizedRawIds);
    const resolvedIds = this.mapTeacherIds(normalizedRawIds, idMap);

    if (strict && resolvedIds.length !== normalizedRawIds.length) {
      throw new ApiError('One or more selected teachers are invalid for this institute', 400, 'INVALID_TEACHER');
    }

    return resolvedIds;
  }

  private async resolveAssignedTeachers(instituteId: string, ids: string[]) {
    const resolvedIds = await this.resolveTeacherProfileIds(instituteId, ids);
    if (resolvedIds.length === 0) return [];

    const teachers = await prisma.teacher.findMany({
      where: {
        institute_id: instituteId,
        id: { in: resolvedIds },
      },
      select: {
        id: true,
        name: true,
        phone: true,
        email: true,
        photo_url: true,
      },
    });

    const teacherMap = new Map(teachers.map((teacher) => [teacher.id, teacher]));
    const isDefined = <T>(value: T | undefined): value is T => value !== undefined;
    return resolvedIds
      .map((id) => teacherMap.get(id))
      .filter(isDefined);
  }

  async listBatches(
    instituteId: string,
    query: { subject?: string; teacherId?: string },
    actor?: { role?: string; userId?: string },
  ) {
    const normalizedRole = (actor?.role ?? '').trim().toLowerCase();
    let teacherFilter = query.teacherId;
    let scopedBatchIds: string[] | undefined;

    if (normalizedRole === 'teacher') {
      if (!actor?.userId) {
        throw new ApiError('Unauthorized teacher access', 401, 'UNAUTHORIZED');
      }

      const teacherScope = await resolveTeacherScope(instituteId, actor.userId);
      if (teacherFilter && teacherFilter !== teacherScope.teacherId) {
        throw new ApiError('You can only access your own assigned batches', 403, 'FORBIDDEN');
      }

      teacherFilter = undefined;
      scopedBatchIds = teacherScope.batchIds;

      if (scopedBatchIds.length === 0) {
        return [];
      }
    }

    const batches = await this.batchRepository.listBatches(instituteId, query.subject, teacherFilter, scopedBatchIds);
    const batchMetaMap = await this.getBatchMetaMap(instituteId);

    const allTeacherIds = new Set<string>();
    for (const batch of batches) {
      const meta = (batchMetaMap[batch.id] ?? {}) as Record<string, any>;
      const ids = resolveBatchTeacherIds(meta, batch.teacher_id ?? undefined);
      for (const id of ids) {
        if (typeof id === 'string' && id.length > 0) allTeacherIds.add(id);
      }
    }

    const teacherIdMap = await this.buildTeacherIdMap(instituteId, Array.from(allTeacherIds));
    const canonicalTeacherIds = Array.from(new Set(Array.from(teacherIdMap.values())));
    const teachers = await this.resolveAssignedTeachers(instituteId, canonicalTeacherIds);
    const teacherMap = new Map(teachers.map((t) => [t.id, t]));

    return batches.map((b) => {
      const meta = (batchMetaMap[b.id] ?? {}) as Record<string, any>;
      const mergedRawTeacherIds = resolveBatchTeacherIds(meta, b.teacher_id ?? undefined);
      const mergedTeacherIds = this.mapTeacherIds(mergedRawTeacherIds, teacherIdMap);

      const assigned_teachers = mergedTeacherIds
        .map((id) => teacherMap.get(id))
        .filter(Boolean);
      const primaryTeacher = assigned_teachers[0] ?? null;

      return {
        ...b,
        teacher_id: mergedTeacherIds[0] ?? null,
        teacher: primaryTeacher,
        current_students: b._count.student_batches,
        description: typeof meta.description === 'string' ? meta.description : null,
        cover_image_url: typeof meta.cover_image_url === 'string' ? meta.cover_image_url : null,
        faqs: Array.isArray(meta.faqs) ? meta.faqs : [],
        subjects: Array.isArray(meta.subjects) ? meta.subjects : [],
        teacher_ids: mergedTeacherIds,
        assigned_teachers,
      };
    });
  }

  async getBatchDetails(batchId: string, instituteId: string, actor?: { role?: string; userId?: string }) {
    const normalizedRole = (actor?.role ?? '').trim().toLowerCase();
    if (normalizedRole === 'teacher') {
      if (!actor?.userId) {
        throw new ApiError('Unauthorized teacher access', 401, 'UNAUTHORIZED');
      }
      await this.ensureTeacherBatchAccess(instituteId, actor.userId, batchId);
    }

    const batch = await this.batchRepository.findBatchById(batchId, instituteId);
    if (!batch) {
        throw new ApiError('Batch not found', 404, 'NOT_FOUND');
    }
    
    // Flatten students output slightly for easier client consumption
    const students = batch.student_batches.map(sb => ({
       ...sb.student,
       joined_date: sb.joined_date
    }));

    const meta = await this.getStoredBatchMeta(instituteId, batchId);
    const mergedRawTeacherIds = resolveBatchTeacherIds(meta, batch.teacher_id ?? undefined);
    const mergedTeacherIds = await this.resolveTeacherProfileIds(instituteId, mergedRawTeacherIds);
    const assigned_teachers = await this.resolveAssignedTeachers(instituteId, mergedTeacherIds);
    const primaryTeacher = assigned_teachers[0] ?? null;

    return {
      ...batch,
      teacher_id: mergedTeacherIds[0] ?? null,
      teacher: primaryTeacher,
      student_batches: undefined,
      students,
      description: typeof meta.description === 'string' ? meta.description : null,
      cover_image_url: typeof meta.cover_image_url === 'string' ? meta.cover_image_url : null,
      faqs: Array.isArray(meta.faqs) ? meta.faqs : [],
      subjects: Array.isArray(meta.subjects) ? meta.subjects : [],
      teacher_ids: mergedTeacherIds,
      assigned_teachers,
    }
  }

  async createBatch(instituteId: string, data: CreateBatchInput) {
    const { teacher_ids, description, cover_image_url, faqs, subjects, ...batchData } = data;
    const resolvedTeacherIds = await this.resolveTeacherProfileIds(
      instituteId,
      this.normalizeTeacherIds({
        teacher_id: batchData.teacher_id,
        teacher_ids,
      }),
      true,
    );
    const primaryTeacher = resolvedTeacherIds[0];

    const normalizeDate = (value?: string) => {
      if (!value) return null;
      const parsed = new Date(value);
      return Number.isNaN(parsed.getTime()) ? null : parsed;
    };

    const normalizedName = batchData.name.trim();
    const normalizedSubject = batchData.subject?.trim() || null;
    const normalizedRoom = batchData.room?.trim() || null;
    const normalizedDaysOfWeek = Array.from(
      new Set((batchData.days_of_week ?? []).map((day) => Number(day))),
    ).sort((a, b) => a - b);
    const normalizedStartDate = normalizeDate(batchData.start_date);
    const normalizedEndDate = normalizeDate(batchData.end_date);

    // Guard against accidental duplicate submits from rapid taps/retries.
    // If an identical batch payload was created very recently, reuse it.
    const recentDuplicate = await prisma.batch.findFirst({
      where: {
        institute_id: instituteId,
        name: normalizedName,
        subject: normalizedSubject,
        room: normalizedRoom,
        teacher_id: primaryTeacher ?? null,
        days_of_week: { equals: normalizedDaysOfWeek },
        start_date: normalizedStartDate,
        end_date: normalizedEndDate,
        capacity: batchData.capacity ?? null,
        created_at: { gte: new Date(Date.now() - 60 * 1000) },
      },
      orderBy: { created_at: 'desc' },
      select: { id: true },
    });

    if (recentDuplicate) {
      return this.getBatchDetails(recentDuplicate.id, instituteId);
    }

    const created = await this.batchRepository.createBatch(instituteId, {
      ...batchData,
      name: normalizedName,
      subject: normalizedSubject ?? undefined,
      room: normalizedRoom ?? undefined,
      days_of_week: normalizedDaysOfWeek,
      teacher_id: primaryTeacher,
    });

    const normalizedTeacherIds = resolvedTeacherIds;

    if (normalizedTeacherIds.length > 0 || description || cover_image_url || (faqs?.length ?? 0) > 0 || (subjects?.length ?? 0) > 0) {
      await this.updateBatchMeta(created.id, instituteId, {
        teacher_ids: normalizedTeacherIds,
        description,
        cover_image_url,
        faqs,
        subjects,
      });
    }

    return this.getBatchDetails(created.id, instituteId);
  }

  async updateBatch(batchId: string, instituteId: string, data: UpdateBatchInput) {
    const batch = await this.batchRepository.findBatchById(batchId, instituteId);
    if (!batch) throw new ApiError('Batch not found', 404, 'NOT_FOUND');

    const {
      teacher_ids,
      description,
      cover_image_url,
      faqs,
      subjects,
      ...coreData
    } = data as UpdateBatchInput & UpdateBatchMetaInput;

    let normalizedTeacherIds: string[] | undefined;

    if (teacher_ids !== undefined) {
      normalizedTeacherIds = await this.resolveTeacherProfileIds(
        instituteId,
        this.normalizeTeacherIds({
          teacher_id: coreData.teacher_id,
          teacher_ids,
        }),
        true,
      );

      if (!coreData.teacher_id && normalizedTeacherIds.length > 0) {
        coreData.teacher_id = normalizedTeacherIds[0];
      }
    }

    if (coreData.teacher_id) {
      const [resolvedPrimaryTeacherId] = await this.resolveTeacherProfileIds(
        instituteId,
        [coreData.teacher_id],
        true,
      );
      coreData.teacher_id = resolvedPrimaryTeacherId;

      if (normalizedTeacherIds && resolvedPrimaryTeacherId && !normalizedTeacherIds.includes(resolvedPrimaryTeacherId)) {
        normalizedTeacherIds = [resolvedPrimaryTeacherId, ...normalizedTeacherIds];
      }
    }

    await this.batchRepository.updateBatch(batchId, instituteId, coreData);

    if (
      teacher_ids !== undefined ||
      description !== undefined ||
      cover_image_url !== undefined ||
      faqs !== undefined ||
      subjects !== undefined
    ) {
      const existingMeta = await this.getStoredBatchMeta(instituteId, batchId);
      const mergedTeacherIds = normalizedTeacherIds
        ?? await this.resolveTeacherProfileIds(
          instituteId,
          this.normalizeTeacherIds({
            teacher_id: coreData.teacher_id ?? batch.teacher_id ?? undefined,
            teacher_ids: Array.isArray(existingMeta.teacher_ids) ? existingMeta.teacher_ids : undefined,
          }),
        );
      await this.updateBatchMeta(batchId, instituteId, {
        teacher_ids: mergedTeacherIds,
        description,
        cover_image_url,
        faqs,
        subjects,
      });
    }

    return this.getBatchDetails(batchId, instituteId);
  }

  async deleteBatch(batchId: string, instituteId: string) {
    const batch = await this.batchRepository.findBatchById(batchId, instituteId);
    if (!batch) throw new ApiError('Batch not found', 404, 'NOT_FOUND');

    await this.batchRepository.deleteBatch(batchId);

    const map = await this.getBatchMetaMap(instituteId);
    if (map[batchId] !== undefined) {
      delete map[batchId];
      await this.saveBatchMetaMap(instituteId, map);
    }

    return { success: true };
  }

  async changeStatus(batchId: string, instituteId: string, isActive: boolean) {
    const batch = await this.batchRepository.findBatchById(batchId, instituteId);
    if (!batch) throw new ApiError('Batch not found', 404, 'NOT_FOUND');

    return this.batchRepository.toggleStatus(batchId, isActive);
  }

  async enrollStudents(batchId: string, instituteId: string, studentIds: string[]) {
    const batch = await this.batchRepository.findBatchById(batchId, instituteId);
    if (!batch) throw new ApiError('Batch not found or unauthorized', 404, 'NOT_FOUND');

    const currentCount = batch.student_batches.length;
    if (batch.capacity && currentCount + studentIds.length > batch.capacity) {
        throw new ApiError('Batch capacity exceeded', 400, 'CAPACITY_EXCEEDED');
    }

    const results = await prisma.$transaction(
        studentIds.map(sId => prisma.studentBatch.upsert({
            where: { student_id_batch_id: { student_id: sId, batch_id: batchId } },
            update: { is_active: true, left_date: null },
            create: { student_id: sId, batch_id: batchId, institute_id: instituteId }
        }))
    );

    return { enrolled_count: results.length };
  }

  async removeStudent(batchId: string, instituteId: string, studentId: string) {
    const batch = await this.batchRepository.findBatchById(batchId, instituteId);
    if (!batch) throw new ApiError('Batch not found', 404, 'NOT_FOUND');

    await this.batchRepository.removeStudentFromBatch(studentId, batchId);
    return { success: true };
  }

  async getBatchMeta(batchId: string, instituteId: string, actor?: { role?: string; userId?: string }) {
    const normalizedRole = (actor?.role ?? '').trim().toLowerCase();
    if (normalizedRole === 'teacher') {
      if (!actor?.userId) {
        throw new ApiError('Unauthorized teacher access', 401, 'UNAUTHORIZED');
      }
      await this.ensureTeacherBatchAccess(instituteId, actor.userId, batchId);
    }

    const batch = await this.batchRepository.findBatchById(batchId, instituteId);
    if (!batch) throw new ApiError('Batch not found', 404, 'NOT_FOUND');

    const meta = await this.getStoredBatchMeta(instituteId, batchId);
    const mergedRawTeacherIds = resolveBatchTeacherIds(meta, batch.teacher_id ?? undefined);
    const mergedTeacherIds = await this.resolveTeacherProfileIds(instituteId, mergedRawTeacherIds);
    const assigned_teachers = await this.resolveAssignedTeachers(instituteId, mergedTeacherIds);

    return {
      description: typeof meta.description === 'string' ? meta.description : null,
      cover_image_url: typeof meta.cover_image_url === 'string' ? meta.cover_image_url : null,
      faqs: Array.isArray(meta.faqs) ? meta.faqs : [],
      subjects: Array.isArray(meta.subjects) ? meta.subjects : [],
      teacher_ids: mergedTeacherIds,
      assigned_teachers,
    };
  }

  async ensureTeacherBatchAccess(instituteId: string, userId: string, batchId: string) {
    const teacherScope = await resolveTeacherScope(instituteId, userId);
    if (!teacherScope.batchIds.includes(batchId)) {
      throw new ApiError('You can only access your assigned batches', 403, 'FORBIDDEN');
    }
  }

  async updateBatchMeta(batchId: string, instituteId: string, data: UpdateBatchMetaInput) {
    const batch = await this.batchRepository.findBatchById(batchId, instituteId);
    if (!batch) throw new ApiError('Batch not found', 404, 'NOT_FOUND');

    const map = await this.getBatchMetaMap(instituteId);
    const existingMeta = (map[batchId] ?? {}) as Record<string, any>;

    const hasExplicitTeacherIds = data.teacher_ids !== undefined;
    const teacher_ids = data.teacher_ids
      ?? this.normalizeTeacherIds({
        teacher_id: batch.teacher_id ?? undefined,
        teacher_ids: Array.isArray(existingMeta.teacher_ids) ? existingMeta.teacher_ids : undefined,
      });
    const normalizedTeacherIds = await this.resolveTeacherProfileIds(
      instituteId,
      Array.isArray(teacher_ids) ? teacher_ids : [],
      hasExplicitTeacherIds,
    );
    const description = data.description ?? existingMeta.description ?? null;
    const cover_image_url = data.cover_image_url ?? existingMeta.cover_image_url ?? null;
    const faqs = data.faqs ?? existingMeta.faqs ?? [];
    const subjects = data.subjects ?? existingMeta.subjects ?? [];

    const primaryTeacherId = normalizedTeacherIds[0] ?? null;
    if (batch.teacher_id !== primaryTeacherId) {
      await prisma.batch.updateMany({
        where: {
          id: batchId,
          institute_id: instituteId,
        },
        data: {
          teacher_id: primaryTeacherId,
        },
      });
    }

    map[batchId] = {
      teacher_ids: normalizedTeacherIds,
      description,
      cover_image_url,
      faqs,
      subjects,
      updated_at: new Date().toISOString(),
    };

    await this.saveBatchMetaMap(instituteId, map);

    return this.getBatchMeta(batchId, instituteId);
  }

  async migrateStudents(batchId: string, instituteId: string, data: MigrateBatchStudentsInput) {
    const sourceBatch = await this.batchRepository.findBatchById(batchId, instituteId);
    if (!sourceBatch) throw new ApiError('Source batch not found', 404, 'NOT_FOUND');
    if (data.target_batch_id === batchId) throw new ApiError('Target batch must be different from source batch', 400, 'VALIDATION_ERROR');

    const targetBatch = await this.batchRepository.findBatchById(data.target_batch_id, instituteId);
    if (!targetBatch) throw new ApiError('Target batch not found', 404, 'NOT_FOUND');

    const sourceStudentIds = sourceBatch.student_batches.map((sb) => sb.student_id);
    if (sourceStudentIds.length === 0) {
      return { migrated_count: 0, source_batch_id: batchId, target_batch_id: data.target_batch_id };
    }

    const targetCurrentCount = targetBatch.student_batches.length;
    if (targetBatch.capacity && targetCurrentCount + sourceStudentIds.length > targetBatch.capacity) {
      throw new ApiError('Target batch capacity exceeded', 400, 'CAPACITY_EXCEEDED');
    }

    return await prisma.$transaction(async (tx) => {
      // 1. Add students to target batch
      await Promise.all(
        sourceStudentIds.map((sId) => tx.studentBatch.upsert({
          where: { student_id_batch_id: { student_id: sId, batch_id: data.target_batch_id } },
          update: { is_active: true, left_date: null },
          create: { student_id: sId, batch_id: data.target_batch_id, institute_id: instituteId },
        }))
      );

      // 2. Deactivate source batch entries if requested
      if (data.deactivate_source ?? true) {
        await tx.studentBatch.updateMany({
          where: {
            institute_id: instituteId,
            batch_id: batchId,
            student_id: { in: sourceStudentIds },
            is_active: true,
          },
          data: {
            is_active: false,
            left_date: new Date(),
          },
        });

        await tx.batch.update({
          where: { id: batchId },
          data: { is_active: false }
        });
      }

      // 3. Activate target batch if requested
      if (data.activate_target ?? true) {
        await tx.batch.update({
          where: { id: data.target_batch_id },
          data: { is_active: true }
        });
      }

      return {
        migrated_count: sourceStudentIds.length,
        source_batch_id: batchId,
        target_batch_id: data.target_batch_id,
        source_deactivated: data.deactivate_source ?? true,
      };
    });
  }
}

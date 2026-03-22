import { BatchRepository } from './batch.repository';
import { CreateBatchInput, UpdateBatchInput, UpdateBatchMetaInput, MigrateBatchStudentsInput } from './batch.validator';
import { ApiError } from '../../middleware/error.middleware';
import { prisma } from '../../server';

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

  private async resolveAssignedTeachers(instituteId: string, ids: string[]) {
    if (ids.length === 0) return [];

    return prisma.teacher.findMany({
      where: {
        institute_id: instituteId,
        id: { in: ids },
      },
      select: {
        id: true,
        name: true,
        phone: true,
        email: true,
        photo_url: true,
      },
      orderBy: { name: 'asc' },
    });
  }

  private normalizeTeacherIds(data: { teacher_id?: string; teacher_ids?: string[] }): string[] {
    const ids = new Set<string>();
    if (data.teacher_id) ids.add(data.teacher_id);
    for (const id of data.teacher_ids ?? []) {
      if (id) ids.add(id);
    }
    return Array.from(ids);
  }

  async listBatches(instituteId: string, query: { subject?: string, teacherId?: string }) {
    const batches = await this.batchRepository.listBatches(instituteId, query.subject, query.teacherId);
    const batchMetaMap = await this.getBatchMetaMap(instituteId);

    const allTeacherIds = new Set<string>();
    for (const batch of batches) {
      const meta = (batchMetaMap[batch.id] ?? {}) as Record<string, any>;
      const ids = Array.isArray(meta.teacher_ids) ? meta.teacher_ids : [];
      for (const id of ids) {
        if (typeof id === 'string' && id.length > 0) allTeacherIds.add(id);
      }
      if (batch.teacher_id) allTeacherIds.add(batch.teacher_id);
    }

    const teachers = await this.resolveAssignedTeachers(instituteId, Array.from(allTeacherIds));
    const teacherMap = new Map(teachers.map((t) => [t.id, t]));

    return batches.map((b) => {
      const meta = (batchMetaMap[b.id] ?? {}) as Record<string, any>;
      const rawIds = Array.isArray(meta.teacher_ids) ? meta.teacher_ids : [];
      const mergedIds = new Set<string>();
      if (b.teacher_id) mergedIds.add(b.teacher_id);
      for (const id of rawIds) {
        if (typeof id === 'string' && id.length > 0) mergedIds.add(id);
      }

      const assigned_teachers = Array.from(mergedIds)
        .map((id) => teacherMap.get(id))
        .filter(Boolean);

      return {
        ...b,
        current_students: b._count.student_batches,
        description: typeof meta.description === 'string' ? meta.description : null,
        cover_image_url: typeof meta.cover_image_url === 'string' ? meta.cover_image_url : null,
        faqs: Array.isArray(meta.faqs) ? meta.faqs : [],
        teacher_ids: Array.from(mergedIds),
        assigned_teachers,
      };
    });
  }

  async getBatchDetails(batchId: string, instituteId: string) {
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
    const mergedTeacherIds = this.normalizeTeacherIds({
      teacher_id: batch.teacher_id ?? undefined,
      teacher_ids: Array.isArray(meta.teacher_ids) ? meta.teacher_ids : undefined,
    });
    const assigned_teachers = await this.resolveAssignedTeachers(instituteId, mergedTeacherIds);

    return {
      ...batch,
      student_batches: undefined,
      students,
      description: typeof meta.description === 'string' ? meta.description : null,
      cover_image_url: typeof meta.cover_image_url === 'string' ? meta.cover_image_url : null,
      faqs: Array.isArray(meta.faqs) ? meta.faqs : [],
      teacher_ids: mergedTeacherIds,
      assigned_teachers,
    }
  }

  async createBatch(instituteId: string, data: CreateBatchInput) {
    const { teacher_ids, description, cover_image_url, faqs, ...batchData } = data;
    const primaryTeacher = batchData.teacher_id ?? teacher_ids?.[0];

    // Optional logic: Check if teacher exists and belongs to institute
    const created = await this.batchRepository.createBatch(instituteId, {
      ...batchData,
      teacher_id: primaryTeacher,
    });

    const normalizedTeacherIds = this.normalizeTeacherIds({
      teacher_id: primaryTeacher,
      teacher_ids,
    });

    if (normalizedTeacherIds.length > 0 || description || cover_image_url || (faqs?.length ?? 0) > 0) {
      await this.updateBatchMeta(created.id, instituteId, {
        teacher_ids: normalizedTeacherIds,
        description,
        cover_image_url,
        faqs,
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
      ...coreData
    } = data as UpdateBatchInput & UpdateBatchMetaInput;

    if (teacher_ids && teacher_ids.length > 0 && !coreData.teacher_id) {
      coreData.teacher_id = teacher_ids[0];
    }

    await this.batchRepository.updateBatch(batchId, instituteId, coreData);

    if (
      teacher_ids !== undefined ||
      description !== undefined ||
      cover_image_url !== undefined ||
      faqs !== undefined
    ) {
      const existingMeta = await this.getStoredBatchMeta(instituteId, batchId);
      const mergedTeacherIds = teacher_ids ?? this.normalizeTeacherIds({
        teacher_id: coreData.teacher_id ?? batch.teacher_id ?? undefined,
        teacher_ids: Array.isArray(existingMeta.teacher_ids) ? existingMeta.teacher_ids : undefined,
      });
      await this.updateBatchMeta(batchId, instituteId, {
        teacher_ids: mergedTeacherIds,
        description,
        cover_image_url,
        faqs,
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

    // To prevent exceeding capacity
    const currentCount = batch.student_batches.length;
    if (batch.capacity && currentCount + studentIds.length > batch.capacity) {
        throw new ApiError('Batch capacity exceeded', 400, 'CAPACITY_EXCEEDED');
    }

    // Upsert sequentially or concurrently
    const results = await Promise.all(
        studentIds.map(sId => this.batchRepository.addStudentToBatch(sId, batchId, instituteId))
    );

    return { enrolled_count: results.length };
  }

  async removeStudent(batchId: string, instituteId: string, studentId: string) {
    const batch = await this.batchRepository.findBatchById(batchId, instituteId);
    if (!batch) throw new ApiError('Batch not found', 404, 'NOT_FOUND');

    await this.batchRepository.removeStudentFromBatch(studentId, batchId);
    return { success: true };
  }

  async getBatchMeta(batchId: string, instituteId: string) {
    const batch = await this.batchRepository.findBatchById(batchId, instituteId);
    if (!batch) throw new ApiError('Batch not found', 404, 'NOT_FOUND');

    const meta = await this.getStoredBatchMeta(instituteId, batchId);
    const mergedTeacherIds = this.normalizeTeacherIds({
      teacher_id: batch.teacher_id ?? undefined,
      teacher_ids: Array.isArray(meta.teacher_ids) ? meta.teacher_ids : undefined,
    });
    const assigned_teachers = await this.resolveAssignedTeachers(instituteId, mergedTeacherIds);

    return {
      description: typeof meta.description === 'string' ? meta.description : null,
      cover_image_url: typeof meta.cover_image_url === 'string' ? meta.cover_image_url : null,
      faqs: Array.isArray(meta.faqs) ? meta.faqs : [],
      teacher_ids: mergedTeacherIds,
      assigned_teachers,
    };
  }

  async updateBatchMeta(batchId: string, instituteId: string, data: UpdateBatchMetaInput) {
    const batch = await this.batchRepository.findBatchById(batchId, instituteId);
    if (!batch) throw new ApiError('Batch not found', 404, 'NOT_FOUND');

    const map = await this.getBatchMetaMap(instituteId);
    const existingMeta = (map[batchId] ?? {}) as Record<string, any>;

    const teacher_ids = data.teacher_ids ?? existingMeta.teacher_ids ?? (batch.teacher_id ? [batch.teacher_id] : []);
    const normalizedTeacherIds = Array.from(new Set((teacher_ids ?? []).filter((id: unknown) => typeof id === 'string' && id.length > 0)));
    const description = data.description ?? existingMeta.description ?? null;
    const cover_image_url = data.cover_image_url ?? existingMeta.cover_image_url ?? null;
    const faqs = data.faqs ?? existingMeta.faqs ?? [];

    map[batchId] = {
      teacher_ids: normalizedTeacherIds,
      description,
      cover_image_url,
      faqs,
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

    await this.batchRepository.addStudentsToBatch(sourceStudentIds, data.target_batch_id, instituteId);

    if (data.deactivate_source ?? true) {
      await prisma.studentBatch.updateMany({
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

      await this.batchRepository.toggleStatus(batchId, false);
    }

    if (data.activate_target ?? true) {
      await this.batchRepository.toggleStatus(data.target_batch_id, true);
    }

    return {
      migrated_count: sourceStudentIds.length,
      source_batch_id: batchId,
      target_batch_id: data.target_batch_id,
      source_deactivated: data.deactivate_source ?? true,
    };
  }
}

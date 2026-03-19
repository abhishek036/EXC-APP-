import { BatchRepository } from './batch.repository';
import { CreateBatchInput, UpdateBatchInput } from './batch.validator';
import { ApiError } from '../../middleware/error.middleware';

export class BatchService {
  private batchRepository: BatchRepository;

  constructor() {
    this.batchRepository = new BatchRepository();
  }

  async listBatches(instituteId: string, query: { subject?: string, teacherId?: string }) {
    const batches = await this.batchRepository.listBatches(instituteId, query.subject, query.teacherId);
    return batches.map(b => ({
      ...b,
      current_students: b._count.student_batches
    }));
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

    return {
       ...batch,
       student_batches: undefined,
       students
    }
  }

  async createBatch(instituteId: string, data: CreateBatchInput) {
    // Optional logic: Check if teacher exists and belongs to institute
    return this.batchRepository.createBatch(instituteId, data);
  }

  async updateBatch(batchId: string, instituteId: string, data: UpdateBatchInput) {
    const batch = await this.batchRepository.findBatchById(batchId, instituteId);
    if (!batch) throw new ApiError('Batch not found', 404, 'NOT_FOUND');

    return this.batchRepository.updateBatch(batchId, instituteId, data);
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
}

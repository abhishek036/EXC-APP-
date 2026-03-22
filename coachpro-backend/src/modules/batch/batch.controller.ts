import { Request, Response, NextFunction } from 'express';
import { BatchService } from './batch.service';
import { sendResponse } from '../../utils/response';

export class BatchController {
  private batchService: BatchService;

  constructor() {
    this.batchService = new BatchService();
  }

  list = async (req: Request, res: Response, next: NextFunction) => {
    try {
      const { subject, teacherId } = req.query;
      const data = await this.batchService.listBatches(req.instituteId!, { 
          subject: subject as string, 
          teacherId: teacherId as string 
      });
      return sendResponse({ res, data, message: 'Batches fetched successfully' });
    } catch (error) { next(error); }
  };

  create = async (req: Request, res: Response, next: NextFunction) => {
    try {
      const data = await this.batchService.createBatch(req.instituteId!, req.body);
      return sendResponse({ res, data, statusCode: 201, message: 'Batch created successfully' });
    } catch (error) { next(error); }
  };

  getById = async (req: Request, res: Response, next: NextFunction) => {
    try {
      const data = await this.batchService.getBatchDetails(req.params.id, req.instituteId!);
      return sendResponse({ res, data, message: 'Batch details fetched successfully' });
    } catch (error) { next(error); }
  };

  update = async (req: Request, res: Response, next: NextFunction) => {
    try {
      const data = await this.batchService.updateBatch(req.params.id, req.instituteId!, req.body);
      return sendResponse({ res, data, message: 'Batch updated successfully' });
    } catch (error) { next(error); }
  };

  delete = async (req: Request, res: Response, next: NextFunction) => {
    try {
      const data = await this.batchService.deleteBatch(req.params.id, req.instituteId!);
      return sendResponse({ res, data, message: 'Batch deleted successfully' });
    } catch (error) { next(error); }
  };

  toggleStatus = async (req: Request, res: Response, next: NextFunction) => {
    try {
      const { is_active } = req.body;
      const data = await this.batchService.changeStatus(req.params.id, req.instituteId!, is_active);
      return sendResponse({ res, data, message: `Batch ${is_active ? 'activated' : 'deactivated'} successfully` });
    } catch (error) { next(error); }
  };

  getMeta = async (req: Request, res: Response, next: NextFunction) => {
    try {
      const data = await this.batchService.getBatchMeta(req.params.id, req.instituteId!);
      return sendResponse({ res, data, message: 'Batch metadata fetched successfully' });
    } catch (error) { next(error); }
  };

  updateMeta = async (req: Request, res: Response, next: NextFunction) => {
    try {
      const data = await this.batchService.updateBatchMeta(req.params.id, req.instituteId!, req.body);
      return sendResponse({ res, data, message: 'Batch metadata updated successfully' });
    } catch (error) { next(error); }
  };

  migrateStudents = async (req: Request, res: Response, next: NextFunction) => {
    try {
      const { target_batch_id, deactivate_source, activate_target } = req.body;
      const data = await this.batchService.migrateStudents(req.params.id, req.instituteId!, {
        target_batch_id,
        deactivate_source,
        activate_target,
      });
      return sendResponse({ res, data, message: 'Students migrated successfully' });
    } catch (error) { next(error); }
  };

  addStudents = async (req: Request, res: Response, next: NextFunction) => {
    try {
      const { studentIds } = req.body;
      const data = await this.batchService.enrollStudents(req.params.id, req.instituteId!, studentIds);
      return sendResponse({ res, data, message: 'Students enrolled successfully' });
    } catch (error) { next(error); }
  };

  removeStudent = async (req: Request, res: Response, next: NextFunction) => {
    try {
      await this.batchService.removeStudent(req.params.id, req.instituteId!, req.params.studentId);
      return sendResponse({ res, data: null, message: 'Student removed from batch successfully' });
    } catch (error) { next(error); }
  };

  getStudents = async (req: Request, res: Response, next: NextFunction) => {
      try {
          const { id } = req.params;
          const studentsInBatch = await import('../../server').then(m => m.prisma.studentBatch.findMany({
              where: {
                  batch_id: id,
                  institute_id: req.instituteId!,
                  is_active: true
              },
              include: {
                  student: {
                      select: {
                          id: true,
                          name: true,
                          phone: true,
                          photo_url: true,
                          student_code: true
                      }
                  }
              }
          }));

          const students = studentsInBatch.map(sb => sb.student);

          return sendResponse({ res, data: students, message: 'Students in batch fetched successfully' });
      } catch (error) { next(error); }
  };
}

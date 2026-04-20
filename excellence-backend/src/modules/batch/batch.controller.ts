import { Request, Response, NextFunction } from 'express';
import { BatchService } from './batch.service';
import { sendResponse } from '../../utils/response';

export class BatchController {
  private batchService: BatchService;

  constructor() {
    this.batchService = new BatchService();
  }

  private isTeacherRequest(req: Request): boolean {
    return (req.user?.role ?? '').trim().toLowerCase() === 'teacher';
  }

  private sanitizeStudentForTeacher(student: Record<string, unknown>): Record<string, unknown> {
    const sanitized: Record<string, unknown> = { ...student };
    delete sanitized.phone;
    delete sanitized.parent_phone;

    const parentStudents = sanitized.parent_students;
    if (Array.isArray(parentStudents)) {
      sanitized.parent_students = parentStudents.map((link) => {
        if (!link || typeof link !== 'object') return link;
        const linkObj: Record<string, unknown> = {
          ...(link as Record<string, unknown>),
        };
        const parent = linkObj.parent;
        if (parent && typeof parent === 'object') {
          const parentObj: Record<string, unknown> = {
            ...(parent as Record<string, unknown>),
          };
          delete parentObj.phone;
          linkObj.parent = parentObj;
        }
        return linkObj;
      });
    }

    return sanitized;
  }

  private sanitizeBatchDetailsForTeacher(payload: Record<string, unknown>): Record<string, unknown> {
    const sanitized: Record<string, unknown> = { ...payload };

    const students = sanitized.students;
    if (Array.isArray(students)) {
      sanitized.students = students.map((student) => {
        if (student && typeof student === 'object') {
          return this.sanitizeStudentForTeacher(student as Record<string, unknown>);
        }
        return student;
      });
    }

    const studentBatches = sanitized.student_batches;
    if (Array.isArray(studentBatches)) {
      sanitized.student_batches = studentBatches.map((row) => {
        if (!row || typeof row !== 'object') return row;
        const rowObj: Record<string, unknown> = {
          ...(row as Record<string, unknown>),
        };
        const student = rowObj.student;
        if (student && typeof student === 'object') {
          rowObj.student = this.sanitizeStudentForTeacher(
            student as Record<string, unknown>,
          );
        }
        return rowObj;
      });
    }

    return sanitized;
  }

  list = async (req: Request, res: Response, next: NextFunction) => {
    try {
      const { subject, teacherId } = req.query;
      const data = await this.batchService.listBatches(req.instituteId!, { 
          subject: subject as string, 
          teacherId: teacherId as string 
      }, {
        role: req.user?.role,
        userId: req.user?.userId,
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
      const data = await this.batchService.getBatchDetails(req.params.id, req.instituteId!, {
        role: req.user?.role,
        userId: req.user?.userId,
      });
      const safeData = this.isTeacherRequest(req) && data && typeof data === 'object'
        ? this.sanitizeBatchDetailsForTeacher(data as Record<string, unknown>)
        : data;
      return sendResponse({ res, data: safeData, message: 'Batch details fetched successfully' });
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
      const data = await this.batchService.getBatchMeta(req.params.id, req.instituteId!, {
        role: req.user?.role,
        userId: req.user?.userId,
      });
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
        const isTeacher = this.isTeacherRequest(req);
          if (isTeacher) {
            await this.batchService.ensureTeacherBatchAccess(req.instituteId!, req.user!.userId, id);
          }
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
                          photo_url: true,
                student_code: true,
                ...(isTeacher ? {} : { phone: true }),
                      }
                  }
              }
          }));

        const students = studentsInBatch.map(sb => {
        if (!isTeacher) return sb.student;
        return this.sanitizeStudentForTeacher(
          sb.student as unknown as Record<string, unknown>,
        );
        });

          return sendResponse({ res, data: students, message: 'Students in batch fetched successfully' });
      } catch (error) { next(error); }
  };
}

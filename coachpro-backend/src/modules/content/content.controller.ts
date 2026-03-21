import { Request, Response, NextFunction } from 'express';
import { ContentService } from './content.service';
import { sendResponse } from '../../utils/response';

export class ContentController {
  private service: ContentService;

  constructor() {
    this.service = new ContentService();
  }

  // NOTES
  createNote = async (req: Request, res: Response, next: NextFunction) => {
    try {
      const data = await this.service.createNote(req.instituteId!, req.user!.userId, req.body);
      return sendResponse({ res, data, message: 'Note uploaded successfully', statusCode: 201 });
    } catch (e) { next(e); }
  }

  listNotes = async (req: Request, res: Response, next: NextFunction) => {
    try {
      const data = await this.service.listNotes(req.instituteId!, req.query.batchId as string);
      return sendResponse({ res, data, message: 'Notes fetched successfully' });
    } catch (e) { next(e); }
  }

  // ASSIGNMENTS
  createAssignment = async (req: Request, res: Response, next: NextFunction) => {
    try {
      const data = await this.service.createAssignment(req.instituteId!, req.user!.userId, req.body);
      return sendResponse({ res, data, message: 'Assignment uploaded successfully', statusCode: 201 });
    } catch (e) { next(e); }
  }

  listAssignments = async (req: Request, res: Response, next: NextFunction) => {
    try {
      const filter = {
        batchId: req.query.batchId as string,
        teacherId: req.query.teacherId as string
      };
      const data = await this.service.listAssignments(req.instituteId!, filter);
      return sendResponse({ res, data, message: 'Assignments fetched successfully' });
    } catch (e) { next(e); }
  }

  // DOUBTS
  askDoubt = async (req: Request, res: Response, next: NextFunction) => {
    try {
      // Typically student_id is req.user.userId, but checking logic depends on the specific user schema implementation
      const data = await this.service.askDoubt(req.instituteId!, req.user!.userId, req.body);
      return sendResponse({ res, data, message: 'Doubt submitted successfully', statusCode: 201 });
    } catch (e) { next(e); }
  }

  respondDoubt = async (req: Request, res: Response, next: NextFunction) => {
    try {
      const data = await this.service.respondToDoubt(req.params.doubtId, req.instituteId!, req.user!.userId, req.body);
      return sendResponse({ res, data, message: 'Doubt answer submitted successfully' });
    } catch (e) { next(e); }
  }

  listDoubts = async (req: Request, res: Response, next: NextFunction) => {
    try {
      const data = await this.service.listDoubts(req.instituteId!, {
          batchId: req.query.batchId as string,
          studentId: req.query.studentId as string,
          status: req.query.status as string
      });
      return sendResponse({ res, data, message: 'Doubts fetched successfully' });
    } catch (e) { next(e); }
  }
}

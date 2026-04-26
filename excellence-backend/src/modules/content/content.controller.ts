import { Request, Response, NextFunction } from 'express';
import { ContentService } from './content.service';
import { sendResponse } from '../../utils/response';
import { prisma } from '../../config/prisma';
import { emitBatchSync, emitInstituteDashboardSync } from '../../config/socket';
import { ApiError } from '../../middleware/error.middleware';
import { createHmac, timingSafeEqual } from 'crypto';
import { UploadController } from '../upload/upload.controller';
import { resolveBatchTeacherIds } from '../../utils/batch-teacher-assignment';

export class ContentController {
  private service: ContentService;
  private uploadController: UploadController;

  constructor() {
    this.service = new ContentService();
    this.uploadController = new UploadController();
  }

  private async resolveTeacherId(instituteId: string, userId: string): Promise<string | null> {
    const teacher = await prisma.teacher.findFirst({
      where: { institute_id: instituteId, user_id: userId },
      select: { id: true },
    });
    return teacher?.id ?? null;
  }

  private isPrismaSchemaDriftError(error: any): boolean {
    const code = String(error?.code || '').trim();
    return code === 'P2021' || code === 'P2022';
  }

  private phoneVariants(phone: string | null | undefined): string[] {
    const clean = String(phone ?? '').replace(/[\s\-()]/g, '');
    if (!clean) return [];
    const set = new Set<string>([clean]);
    if (clean.startsWith('+91') && clean.length >= 13) set.add(clean.substring(3));
    if (clean.startsWith('91') && clean.length === 12) {
      const ten = clean.substring(2);
      set.add(ten);
      set.add(`+91${ten}`);
    }
    if (/^\d{10}$/.test(clean)) {
      set.add(`+91${clean}`);
      set.add(`91${clean}`);
    }
    return Array.from(set);
  }

  private async resolveStudentProfile(instituteId: string, userId: string): Promise<{ id: string; name: string | null; batch_ids: string[] } | null> {
    const user = await prisma.user.findUnique({
      where: { id: userId },
      select: { phone: true },
    });
    const phones = this.phoneVariants(user?.phone);

    const orFilters: Array<Record<string, any>> = [{ user_id: userId }];
    if (phones.length > 0) {
      orFilters.push({
        AND: [
          { phone: { in: phones } },
          { OR: [{ user_id: null }, { user_id: userId }] },
        ],
      });
    }

    const candidates = await prisma.student.findMany({
      where: {
        institute_id: instituteId,
        // Do not hard-filter by is_active here; some legacy student rows are incorrectly false
        // but still represent the authenticated user profile.
        OR: orFilters,
      },
      include: {
        student_batches: {
          where: { OR: [{ is_active: true }, { is_active: null }] },
          select: { id: true, batch_id: true },
        },
      },
      orderBy: { created_at: 'desc' },
    });

    const ranked = [...candidates].sort((a, b) => {
      const aLinked = a.user_id === userId ? 1 : 0;
      const bLinked = b.user_id === userId ? 1 : 0;
      if (bLinked != aLinked) return bLinked - aLinked;

      const aBatchCount = a.student_batches?.length || 0;
      const bBatchCount = b.student_batches?.length || 0;
      if (bBatchCount != aBatchCount) return bBatchCount - aBatchCount;

      const aUnlinked = !a.user_id ? 1 : 0;
      const bUnlinked = !b.user_id ? 1 : 0;
      if (bUnlinked != aUnlinked) return bUnlinked - aUnlinked;

      const aCreated = new Date(a.created_at as any).getTime() || 0;
      const bCreated = new Date(b.created_at as any).getTime() || 0;
      return bCreated - aCreated;
    });

    const best = ranked[0] || null;

    if (!best) return null;

    if (!best.user_id) {
      await prisma.student.updateMany({
        where: { id: best.id, institute_id: instituteId, user_id: null },
        data: { user_id: userId },
      });
    }

    return {
      id: best.id,
      name: best.name ?? null,
      batch_ids: (best.student_batches ?? []).map((item: any) => String(item.batch_id)).filter(Boolean),
    };
  }

  private assignmentProgressStatus(assignment: any, submission: any, feedback: any): 'not_started' | 'in_progress' | 'submitted' | 'late_submission' | 'evaluated' {
    if (!submission) return 'not_started';
    if (submission.is_draft || submission.status === 'in_progress') return 'in_progress';
    if (feedback || submission.status === 'evaluated') return 'evaluated';
    if (submission.is_late || submission.status === 'late_submission') return 'late_submission';
    return 'submitted';
  }

  private progressLabel(status: 'not_started' | 'in_progress' | 'submitted' | 'late_submission' | 'evaluated'): string {
    const map: Record<string, string> = {
      not_started: 'Not Started',
      in_progress: 'In Progress',
      submitted: 'Submitted',
      late_submission: 'Late Submission',
      evaluated: 'Evaluated',
    };
    return map[status] ?? 'Not Started';
  }

  private async ensureTeacherCanAccessAssignment(instituteId: string, userId: string, assignmentId: string) {
    const teacherId = await this.resolveTeacherId(instituteId, userId);
    if (!teacherId) {
      throw new ApiError('Teacher profile not found', 403, 'FORBIDDEN');
    }

    const assignment = await prisma.assignment.findFirst({
      where: {
        id: assignmentId,
        institute_id: instituteId,
        OR: [
          { teacher_id: teacherId },
          { batch: { teacher_id: teacherId } },
        ],
      },
      select: { id: true, batch_id: true, title: true, teacher_id: true },
    });

    if (!assignment) {
      throw new ApiError('You are not authorized to access this assignment', 403, 'FORBIDDEN');
    }

    return assignment;
  }

  private async ensureStudentCanAccessAssignment(instituteId: string, student: { id: string; batch_ids: string[] }, assignmentId: string) {
    const assignment = await prisma.assignment.findFirst({
      where: { id: assignmentId, institute_id: instituteId },
      select: { id: true, batch_id: true, title: true, teacher_id: true },
    });

    if (!assignment) {
      throw new ApiError('Assignment not found', 404, 'NOT_FOUND');
    }

    if (student.batch_ids.length > 0 && !student.batch_ids.includes(String(assignment.batch_id))) {
      throw new ApiError('You are not authorized to access this assignment', 403, 'FORBIDDEN');
    }

    return assignment;
  }

  private noteAccessTokenSecret(): string {
    return process.env.JWT_SECRET || process.env.NOTE_ACCESS_SECRET || 'excellence-note-access-secret';
  }

  private createNoteAccessToken(payload: {
    instituteId: string;
    noteId: string;
    fileId: string;
    action: 'view' | 'download';
    userId?: string;
    role?: string;
    studentId?: string | null;
    expiresInSeconds?: number;
  }): { token: string; expiresAt: string; expiresInSeconds: number } {
    const expiresInSeconds = payload.expiresInSeconds ?? 5 * 60;
    const exp = Date.now() + expiresInSeconds * 1000;
    const body = {
      i: payload.instituteId,
      u: payload.userId ?? null,
      r: payload.role ?? null,
      s: payload.studentId ?? null,
      n: payload.noteId,
      f: payload.fileId,
      a: payload.action,
      e: exp,
    };

    const encoded = Buffer.from(JSON.stringify(body)).toString('base64url');
    const signature = createHmac('sha256', this.noteAccessTokenSecret()).update(encoded).digest('base64url');

    return {
      token: `${encoded}.${signature}`,
      expiresAt: new Date(exp).toISOString(),
      expiresInSeconds,
    };
  }

  private verifyNoteAccessToken(token: string): {
    i: string;
    u?: string | null;
    r?: string | null;
    s?: string | null;
    n: string;
    f: string;
    a: 'view' | 'download';
    e: number;
  } {
    const [encoded, signature] = String(token || '').split('.');
    if (!encoded || !signature) {
      throw new ApiError('Invalid note access token', 403, 'FORBIDDEN');
    }

    const expectedSignature = createHmac('sha256', this.noteAccessTokenSecret()).update(encoded).digest('base64url');
    const left = Buffer.from(signature);
    const right = Buffer.from(expectedSignature);
    if (left.length !== right.length || !timingSafeEqual(left, right)) {
      throw new ApiError('Invalid note access token signature', 403, 'FORBIDDEN');
    }

    let payload: any;
    try {
      payload = JSON.parse(Buffer.from(encoded, 'base64url').toString('utf8'));
    } catch {
      throw new ApiError('Invalid note access token payload', 403, 'FORBIDDEN');
    }

    if (!payload?.e || Number(payload.e) < Date.now()) {
      throw new ApiError('Note access token expired', 403, 'TOKEN_EXPIRED');
    }

    return payload as {
      i: string;
      u?: string | null;
      r?: string | null;
      s?: string | null;
      n: string;
      f: string;
      a: 'view' | 'download';
      e: number;
    };
  }

  private requestIp(req: Request): string | null {
    const forwarded = req.headers['x-forwarded-for'];
    if (typeof forwarded === 'string' && forwarded.trim()) {
      return forwarded.split(',')[0].trim();
    }
    if (Array.isArray(forwarded) && forwarded.length > 0) {
      return String(forwarded[0]);
    }
    return req.ip || null;
  }

  private resolveAction(value: unknown): 'view' | 'download' {
    return String(value || '').toLowerCase() === 'download' ? 'download' : 'view';
  }

  private async ensureStudentCanAccessNote(instituteId: string, student: { id: string; batch_ids: string[] }, noteId: string) {
    const note = await this.service.getNoteById(instituteId, noteId);
    if (!note || (note as any)?.is_deleted) {
      throw new ApiError('Note not found', 404, 'NOT_FOUND');
    }

    if (student.batch_ids.length > 0 && !student.batch_ids.includes(String((note as any).batch_id))) {
      throw new ApiError('You are not authorized to access this note', 403, 'FORBIDDEN');
    }

    return note;
  }

  private async ensureTeacherCanAccessNote(instituteId: string, userId: string, noteId: string) {
    const teacherId = await this.resolveTeacherId(instituteId, userId);
    if (!teacherId) {
      throw new ApiError('Teacher profile not found', 403, 'FORBIDDEN');
    }

    const note = await prisma.note.findFirst({
      where: {
        id: noteId,
        institute_id: instituteId,
        is_deleted: false,
        OR: [
          { teacher_id: teacherId },
          { batch: { teacher_id: teacherId } },
        ],
      },
      select: { id: true, batch_id: true, teacher_id: true },
    });

    if (!note) {
      throw new ApiError('You are not authorized to access this note', 403, 'FORBIDDEN');
    }

    return note;
  }

  private async authorizeNoteFileAccess(req: Request, noteId: string, fileId: string) {
    const instituteId = req.instituteId!;
    const role = req.user?.role;

    const noteFile = await this.service.getNoteFile(instituteId, noteId, fileId);
    if (!noteFile) {
      throw new ApiError('Note file not found', 404, 'NOT_FOUND');
    }

    let studentId: string | null = null;

    if (role === 'student') {
      const student = await this.resolveStudentProfile(instituteId, req.user!.userId);
      if (!student) {
        throw new ApiError('Student profile not found', 404, 'NOT_FOUND');
      }
      await this.ensureStudentCanAccessNote(instituteId, student, noteId);
      studentId = student.id;
    }

    if (role === 'teacher') {
      await this.ensureTeacherCanAccessNote(instituteId, req.user!.userId, noteId);
    }

    return { noteFile, studentId };
  }

  private sanitizeNoteForStudent(note: any) {
    const isDirectVideo = (file: any): boolean => {
      const fileType = String(file?.file_type ?? '').toLowerCase();
      if (fileType != 'video') return false;

      const rawUrl = String(file?.file_url ?? '').trim();
      if (!rawUrl) return false;

      const storageProvider = String(file?.storage_provider ?? '').toLowerCase();
      if (storageProvider == 'external') return true;

      return rawUrl.startsWith('http://') || rawUrl.startsWith('https://');
    };

    const hasId = (value: any) => value != null && String(value).trim().length > 0;
    const parseYoutubeVisibility = (storageProvider: any): 'public' | 'unlisted' | null => {
      const raw = String(storageProvider ?? '').trim().toLowerCase();
      if (raw == 'youtube_public') return 'public';
      if (raw == 'youtube_unlisted') return 'unlisted';
      return null;
    };
    const noteFiles = Array.isArray(note?.note_files)
      ? note.note_files.map((file: any) => ({
        ...file,
        file_url: isDirectVideo(file)
          ? (file?.file_url ?? null)
          : (hasId(file?.id) ? null : (file?.file_url ?? null)),
      }))
      : [];

    const primary = note?.primary_file
      ? {
        ...note.primary_file,
        file_url: isDirectVideo(note?.primary_file)
          ? (note?.primary_file?.file_url ?? null)
          : (hasId(note?.primary_file?.id) ? null : (note?.primary_file?.file_url ?? null)),
      }
      : (noteFiles.isNotEmpty ? noteFiles[0] : null);

    const secureFileAvailable = hasId(primary?.id) || noteFiles.some((item: any) => hasId(item?.id));
    const exposeTopLevelDirectVideo = isDirectVideo(note);
    const youtubeVisibility =
      parseYoutubeVisibility(primary?.storage_provider)
      ?? parseYoutubeVisibility(note?.primary_file?.storage_provider)
      ?? parseYoutubeVisibility(note?.storage_provider)
      ?? null;

    return {
      ...note,
      file_url: exposeTopLevelDirectVideo
        ? (note?.file_url ?? null)
        : (secureFileAvailable ? null : (note?.file_url ?? null)),
      youtube_visibility: youtubeVisibility,
      note_files: noteFiles,
      primary_file: primary,
    };
  }

  // NOTES
  createNote = async (req: Request, res: Response, next: NextFunction) => {
    try {
      const teacherId = await this.resolveTeacherId(req.instituteId!, req.user!.userId);
      const data = await this.service.createNote(req.instituteId!, teacherId, req.body);
      
      // Notify students
      const { NotificationService } = await import('../notification/notification.service');
      const students = await prisma.student.findMany({
        where: { student_batches: { some: { batch_id: req.body.batch_id } }, is_active: true },
        select: { user_id: true }
      });

      for (const student of students) {
        if (student.user_id) {
          await NotificationService.sendNotificationToUser(student.user_id, {
            title: 'New Study Material',
            body: `New study material "${req.body.title}" has been uploaded to your batch.`,
            type: 'material',
            institute_id: req.instituteId!,
            meta: {
              route: '/student/materials',
              note_id: (data as any)?.id
            }
          });
        }
      }

      return sendResponse({ res, data, message: 'Note uploaded successfully', statusCode: 201 });
    } catch (e) { next(e); }
  }

  listNotes = async (req: Request, res: Response, next: NextFunction) => {
    try {
      const filter = {
        batchId: req.query.batchId as string,
        subject: req.query.subject as string,
        chapterTitle: req.query.chapterTitle as string,
        includeDeleted: String(req.query.includeDeleted || '').toLowerCase() === 'true',
      };

      const notes = await this.service.listNotes(req.instituteId!, filter);

      if (req.user?.role === 'student') {
        const student = await this.resolveStudentProfile(req.instituteId!, req.user!.userId);
        if (!student) {
          const safeBatchId = String(filter.batchId || '').trim();
          const visible = (notes as any[]).filter((note: any) => {
            if (!safeBatchId) return false;
            return String(note?.batch_id || '') === safeBatchId;
          });

          const enriched = visible.map((note: any) => ({
            ...this.sanitizeNoteForStudent(note),
            is_bookmarked: false,
          }));

          return sendResponse({ res, data: enriched, message: 'Notes fetched successfully' });
        }

        const visible = (notes as any[]).filter((note: any) => {
          if (!note?.batch_id) return false;
          if (student.batch_ids.length === 0) return true;
          return student.batch_ids.includes(String(note.batch_id));
        });

        const bookmarks = await this.service.listStudentBookmarksMap(
          req.instituteId!,
          student.id,
          visible.map((item) => String(item.id)).filter(Boolean),
        );

        const enriched = visible.map((note: any) => ({
          ...this.sanitizeNoteForStudent(note),
          is_bookmarked: bookmarks.has(String(note.id)),
        }));

        return sendResponse({ res, data: enriched, message: 'Notes fetched successfully' });
      }

      if (req.user?.role === 'teacher') {
        const teacherId = await this.resolveTeacherId(req.instituteId!, req.user!.userId);
        if (!teacherId) {
          throw new ApiError('Teacher profile not found', 403, 'FORBIDDEN');
        }

        const visible = (notes as any[]).filter((note: any) => {
          const owner = note?.teacher_id && String(note.teacher_id) === String(teacherId);
          return owner || !note?.teacher_id;
        });

        return sendResponse({ res, data: visible, message: 'Notes fetched successfully' });
      }

      return sendResponse({ res, data: notes, message: 'Notes fetched successfully' });
    } catch (e) { next(e); }
  }

  bookmarkNote = async (req: Request, res: Response, next: NextFunction) => {
    try {
      const student = await this.resolveStudentProfile(req.instituteId!, req.user!.userId);
      if (!student) {
        throw new ApiError('Student profile not found', 404, 'NOT_FOUND');
      }

      await this.ensureStudentCanAccessNote(req.instituteId!, student, req.params.noteId);
      const data = await this.service.bookmarkNote(req.instituteId!, req.params.noteId, student.id);
      return sendResponse({ res, data, message: 'Note bookmarked successfully', statusCode: 201 });
    } catch (e) { next(e); }
  }

  unbookmarkNote = async (req: Request, res: Response, next: NextFunction) => {
    try {
      const student = await this.resolveStudentProfile(req.instituteId!, req.user!.userId);
      if (!student) {
        throw new ApiError('Student profile not found', 404, 'NOT_FOUND');
      }

      await this.ensureStudentCanAccessNote(req.instituteId!, student, req.params.noteId);
      const data = await this.service.unbookmarkNote(req.instituteId!, req.params.noteId, student.id);
      return sendResponse({ res, data, message: 'Note bookmark removed successfully' });
    } catch (e) { next(e); }
  }

  listBookmarkedNotes = async (req: Request, res: Response, next: NextFunction) => {
    try {
      const student = await this.resolveStudentProfile(req.instituteId!, req.user!.userId);
      if (!student) {
        throw new ApiError('Student profile not found', 404, 'NOT_FOUND');
      }

      const data = await this.service.listBookmarkedNotes(req.instituteId!, student.id, {
        batchId: req.query.batchId as string,
        subject: req.query.subject as string,
      });

      const visible = (data as any[]).filter((note: any) => {
        if (!note?.batch_id) return false;
        if (student.batch_ids.length === 0) return true;
        return student.batch_ids.includes(String(note.batch_id));
      });

      return sendResponse({
        res,
        data: visible.map((item: any) => this.sanitizeNoteForStudent(item)),
        message: 'Bookmarked notes fetched successfully',
      });
    } catch (e) { next(e); }
  }

  noteFileAccess = async (req: Request, res: Response, next: NextFunction) => {
    try {
      const action = this.resolveAction(req.query.action);
      const { noteFile, studentId } = await this.authorizeNoteFileAccess(req, req.params.noteId, req.params.fileId);

      const tokenPack = this.createNoteAccessToken({
        instituteId: req.instituteId!,
        userId: req.user!.userId,
        role: req.user?.role,
        studentId,
        noteId: req.params.noteId,
        fileId: req.params.fileId,
        action,
      });

      const streamPath = `/api/v1/content/notes/${encodeURIComponent(req.params.noteId)}/files/${encodeURIComponent(req.params.fileId)}/stream`;
      const query = `action=${encodeURIComponent(action)}&token=${encodeURIComponent(tokenPack.token)}`;
      const baseUrl = `${req.protocol}://${req.get('host')}`;

      return sendResponse({
        res,
        data: {
          note_id: req.params.noteId,
          note_file_id: req.params.fileId,
          action,
          file_name: (noteFile as any).file_name,
          mime_type: (noteFile as any).mime_type,
          access_url: `${baseUrl}${streamPath}?${query}`,
          expires_at: tokenPack.expiresAt,
          expires_in_seconds: tokenPack.expiresInSeconds,
        },
        message: 'Note file access generated successfully',
      });
    } catch (e) { next(e); }
  }

  streamNoteFile = async (req: Request, res: Response, next: NextFunction) => {
    try {
      const action = this.resolveAction(req.query.action);
      const token = String(req.query.token || '');
      if (!token) {
        throw new ApiError('Access token is required', 403, 'FORBIDDEN');
      }

      const tokenPayload = this.verifyNoteAccessToken(token);
      if (
        String(tokenPayload.n) !== String(req.params.noteId)
        || String(tokenPayload.f) !== String(req.params.fileId)
        || String(tokenPayload.a) !== action
      ) {
        throw new ApiError('Note access token mismatch', 403, 'FORBIDDEN');
      }

      const instituteId = String(tokenPayload.i || '').trim();
      if (!instituteId) {
        throw new ApiError('Invalid note access token institute', 403, 'FORBIDDEN');
      }

      const noteFile = await this.service.getNoteFile(instituteId, req.params.noteId, req.params.fileId);
      if (!noteFile) {
        throw new ApiError('Note file not found', 404, 'NOT_FOUND');
      }

      const userAgentRaw = req.headers['user-agent'];
      const userAgent = Array.isArray(userAgentRaw)
        ? userAgentRaw.join(' ')
        : userAgentRaw ?? null;

      await this.service.logNoteAccess({
        instituteId,
        noteId: req.params.noteId,
        noteFileId: req.params.fileId,
        studentId: tokenPayload.s ?? null,
        action,
        ipAddress: this.requestIp(req),
        userAgent,
      });

      const targetUrl = String((noteFile as any).file_url || '').trim();
      if (!targetUrl) {
        throw new ApiError('File URL missing for this note', 404, 'NOT_FOUND');
      }

      const uploadMarkerV1 = '/api/v1/upload/file/';
      const uploadMarkerLegacy = '/api/upload/file/';
      const markerIndexV1 = targetUrl.indexOf(uploadMarkerV1);
      const markerIndexLegacy = targetUrl.indexOf(uploadMarkerLegacy);
      
      const markerIndex = markerIndexV1 >= 0 ? markerIndexV1 : markerIndexLegacy;
      const uploadMarker = markerIndexV1 >= 0 ? uploadMarkerV1 : uploadMarkerLegacy;

      if (markerIndex >= 0) {
        const key = decodeURIComponent(targetUrl.substring(markerIndex + uploadMarker.length).split('?')[0]);
        const proxyReq = req as any;
        proxyReq.params = {
          ...req.params,
          key,
        };
        proxyReq.query = {
          ...(req.query as any),
          disposition: action === 'download' ? 'attachment' : 'inline',
        };

        await this.uploadController.downloadFile(proxyReq as Request, res);
        return;
      }

      const append = targetUrl.includes('?') ? '&' : '?';
      if (action === 'download') {
        return res.redirect(302, `${targetUrl}${append}disposition=attachment`);
      }

      return res.redirect(302, targetUrl);
    } catch (e) { next(e); }
  }

  noteAnalytics = async (req: Request, res: Response, next: NextFunction) => {
    try {
      const filter: { batchId?: string; subject?: string; chapterTitle?: string; teacherId?: string } = {
        batchId: req.query.batchId as string,
        subject: req.query.subject as string,
        chapterTitle: req.query.chapterTitle as string,
      };

      if (req.user?.role === 'teacher') {
        const teacherId = await this.resolveTeacherId(req.instituteId!, req.user!.userId);
        if (!teacherId) {
          throw new ApiError('Teacher profile not found', 403, 'FORBIDDEN');
        }
        filter.teacherId = teacherId;
      }

      const data = await this.service.getNotesAnalytics(req.instituteId!, filter);
      return sendResponse({ res, data, message: 'Notes analytics fetched successfully' });
    } catch (e) { next(e); }
  }

  updateNote = async (req: Request, res: Response, next: NextFunction) => {
    try {
      if (req.user?.role === 'teacher') {
        await this.ensureTeacherCanAccessNote(req.instituteId!, req.user!.userId, req.params.noteId);
      }

      const data = await this.service.updateNote(req.instituteId!, req.params.noteId, req.body);
      const batchId = (data as any)?.batch_id;
      if (batchId) {
        emitBatchSync(req.instituteId!, batchId, 'note_updated', {
          note_id: req.params.noteId,
        });
      }

      return sendResponse({ res, data, message: 'Note updated successfully' });
    } catch (e) { next(e); }
  }

  deleteNote = async (req: Request, res: Response, next: NextFunction) => {
    try {
      if (req.user?.role === 'teacher') {
        await this.ensureTeacherCanAccessNote(req.instituteId!, req.user!.userId, req.params.noteId);
      }

      const data = await this.service.softDeleteNote(req.instituteId!, req.params.noteId);
      return sendResponse({ res, data, message: 'Note deleted successfully' });
    } catch (e) { next(e); }
  }

  // ASSIGNMENTS
  createAssignment = async (req: Request, res: Response, next: NextFunction) => {
    try {
      const teacherId = await this.resolveTeacherId(req.instituteId!, req.user!.userId);
      const data = await this.service.createAssignment(req.instituteId!, teacherId, req.body);
      emitBatchSync(req.instituteId!, req.body.batch_id, 'assignment_created', {
        assignment_id: (data as any)?.id,
      });

      // Notify students
      const { NotificationService } = await import('../notification/notification.service');
      const students = await prisma.student.findMany({
        where: { student_batches: { some: { batch_id: req.body.batch_id } }, is_active: true },
        select: { user_id: true }
      });

      for (const student of students) {
        if (student.user_id) {
          await NotificationService.sendNotificationToUser(student.user_id, {
            title: 'New Assignment',
            body: `You have a new assignment: "${req.body.title}". Check details and submit before deadline.`,
            type: 'material',
            institute_id: req.instituteId!,
            meta: {
              route: '/student/assignments',
              assignment_id: (data as any)?.id
            }
          });
        }
      }

      return sendResponse({ res, data, message: 'Assignment uploaded successfully', statusCode: 201 });
    } catch (e) { next(e); }
  }

  listAssignments = async (req: Request, res: Response, next: NextFunction) => {
    try {
      const filter = {
        batchId: req.query.batchId as string,
        teacherId: req.query.teacherId as string,
        subject: req.query.subject as string
      };
      const baseAssignments = await this.service.listAssignments(req.instituteId!, filter);

      if (req.user?.role === 'student' && Array.isArray(baseAssignments)) {
        const student = await this.resolveStudentProfile(req.instituteId!, req.user!.userId);
        if (!student) {
          const safeBatchId = String(filter.batchId || '').trim();
          const visible = baseAssignments.filter((assignment: any) => {
            if (!safeBatchId) return false;
            return String(assignment?.batch_id || '') === safeBatchId;
          });

          const enriched = visible.map((assignment: any) => ({
            ...assignment,
            my_submission: null,
            my_feedback: null,
            progress_status: 'not_started',
            progress_label: this.progressLabel('not_started'),
          }));

          return sendResponse({ res, data: enriched, message: 'Assignments fetched successfully' });
        }

        const studentAssignments = baseAssignments.filter((assignment: any) => {
          if (!assignment?.batch_id) return false;
          if (student.batch_ids.length === 0) return true;
          return student.batch_ids.includes(String(assignment.batch_id));
        });

        const assignmentIds = studentAssignments.map((a: any) => String(a.id)).filter(Boolean);
        if (assignmentIds.length === 0) {
          return sendResponse({ res, data: [], message: 'Assignments fetched successfully' });
        }

        let submissions: any[] = [];
        try {
          submissions = await prisma.assignmentSubmission.findMany({
            where: {
              institute_id: req.instituteId!,
              student_id: student.id,
              assignment_id: { in: assignmentIds },
              is_latest: true,
            },
            select: {
              id: true,
              assignment_id: true,
              file_url: true,
              file_name: true,
              file_mime_type: true,
              file_size_kb: true,
              submission_text: true,
              status: true,
              is_draft: true,
              is_late: true,
              attempt_no: true,
              submitted_at: true,
              reviewed_at: true,
              marks_obtained: true,
              remarks: true,
            },
          });
        } catch (error) {
          if (!this.isPrismaSchemaDriftError(error)) {
            throw error;
          }
          submissions = [];
        }

        const submissionIds = submissions.map((item) => item.id);
        const feedbacks = submissionIds.length > 0
          ? await prisma.assignmentFeedback.findMany({
            where: {
              institute_id: req.instituteId!,
              assignment_submission_id: { in: submissionIds },
              is_latest: true,
            },
            orderBy: { revision_no: 'desc' },
          })
          : [];

        const byAssignment = new Map<string, any>();
        for (const item of submissions) byAssignment.set(String(item.assignment_id), item);

        const bySubmission = new Map<string, any>();
        for (const fb of feedbacks) {
          if (!bySubmission.has(String(fb.assignment_submission_id))) {
            bySubmission.set(String(fb.assignment_submission_id), fb);
          }
        }

        const enriched = studentAssignments.map((assignment: any) => {
          const submission = byAssignment.get(String(assignment.id)) ?? null;
          const feedback = submission ? bySubmission.get(String(submission.id)) ?? null : null;
          const progressStatus = this.assignmentProgressStatus(assignment, submission, feedback);
          return {
            ...assignment,
            my_submission: submission,
            my_feedback: feedback,
            progress_status: progressStatus,
            progress_label: this.progressLabel(progressStatus),
          };
        });

        return sendResponse({ res, data: enriched, message: 'Assignments fetched successfully' });
      }

      return sendResponse({ res, data: baseAssignments, message: 'Assignments fetched successfully' });
    } catch (e) { next(e); }
  }

  updateAssignment = async (req: Request, res: Response, next: NextFunction) => {
    try {
      let assignmentMeta: { id: string; batch_id: string; title: string; teacher_id: string | null } | null = null;
      if (req.user?.role === 'teacher') {
        assignmentMeta = await this.ensureTeacherCanAccessAssignment(
          req.instituteId!,
          req.user!.userId,
          req.params.assignmentId,
        );
      }

      const data = await this.service.updateAssignment(
        req.instituteId!,
        req.params.assignmentId,
        req.body,
      );

      const batchId = (data as any)?.batch_id ?? assignmentMeta?.batch_id;
      if (batchId) {
        emitBatchSync(req.instituteId!, batchId, 'assignment_updated', {
          assignment_id: req.params.assignmentId,
        });
      }

      return sendResponse({ res, data, message: 'Assignment updated successfully' });
    } catch (e) { next(e); }
  }

  deleteAssignment = async (req: Request, res: Response, next: NextFunction) => {
    try {
      let assignmentMeta: { id: string; batch_id: string; title: string; teacher_id: string | null } | null = null;
      if (req.user?.role === 'teacher') {
        assignmentMeta = await this.ensureTeacherCanAccessAssignment(
          req.instituteId!,
          req.user!.userId,
          req.params.assignmentId,
        );
      }

      const data = await this.service.deleteAssignment(
        req.instituteId!,
        req.params.assignmentId,
      );

      const batchId = assignmentMeta?.batch_id;
      if (batchId) {
        emitBatchSync(req.instituteId!, batchId, 'assignment_deleted', {
          assignment_id: req.params.assignmentId,
        });
      }

      return sendResponse({ res, data, message: 'Assignment deleted successfully' });
    } catch (e) { next(e); }
  }

  saveAssignmentDraft = async (req: Request, res: Response, next: NextFunction) => {
    try {
      const student = await this.resolveStudentProfile(req.instituteId!, req.user!.userId);
      if (!student) {
        throw new ApiError('Student profile not found', 404, 'NOT_FOUND');
      }

      await this.ensureStudentCanAccessAssignment(req.instituteId!, student, req.params.assignmentId);

      const data = await this.service.saveAssignmentDraft(
        req.instituteId!,
        req.params.assignmentId,
        student.id,
        req.body,
      );

      return sendResponse({ res, data, message: 'Assignment draft saved successfully', statusCode: 201 });
    } catch (e) { next(e); }
  }

  submitAssignment = async (req: Request, res: Response, next: NextFunction) => {
    try {
      const student = await this.resolveStudentProfile(req.instituteId!, req.user!.userId);
      if (!student) {
        throw new ApiError('Student profile not found', 404, 'NOT_FOUND');
      }

      const assignment = await this.ensureStudentCanAccessAssignment(req.instituteId!, student, req.params.assignmentId);

      const data = await this.service.submitAssignment(
        req.instituteId!,
        req.params.assignmentId,
        student.id,
        req.body,
      );

      if (assignment?.batch_id) {
        emitBatchSync(req.instituteId!, assignment.batch_id, 'assignment_submitted', {
          assignment_id: req.params.assignmentId,
          student_id: student.id,
        });

        // Notify teacher about submission
        try {
          const { NotificationService } = await import('../notification/notification.service');
          if (assignment.teacher_id) {
            const teacher = await prisma.teacher.findUnique({
              where: { id: assignment.teacher_id },
              select: { user_id: true }
            });
            if (teacher?.user_id) {
              await NotificationService.sendNotificationToUser(teacher.user_id, {
                title: 'Assignment Submitted',
                body: `${student.name || 'A student'} submitted "${assignment.title || 'an assignment'}" for review.`,
                type: 'material',
                institute_id: req.instituteId!,
                meta: {
                  route: '/teacher/assignments',
                  assignment_id: req.params.assignmentId,
                  student_id: student.id
                }
              });
            }
          }
        } catch (err) {
          console.error('[ContentController] Failed to send teacher assignment notification:', err);
        }
      }

      return sendResponse({ res, data, message: 'Assignment submitted successfully', statusCode: 201 });
    } catch (e) { next(e); }
  }

  listMyAssignmentSubmissions = async (req: Request, res: Response, next: NextFunction) => {
    try {
      const student = await this.resolveStudentProfile(req.instituteId!, req.user!.userId);
      if (!student) {
        throw new ApiError('Student profile not found', 404, 'NOT_FOUND');
      }

      await this.ensureStudentCanAccessAssignment(req.instituteId!, student, req.params.assignmentId);

      const data = await this.service.listMyAssignmentSubmissions(
        req.instituteId!,
        req.params.assignmentId,
        student.id,
      );

      return sendResponse({ res, data, message: 'My assignment submissions fetched successfully' });
    } catch (e) { next(e); }
  }

  listAssignmentSubmissions = async (req: Request, res: Response, next: NextFunction) => {
    try {
      if (req.user?.role === 'teacher') {
        await this.ensureTeacherCanAccessAssignment(req.instituteId!, req.user!.userId, req.params.assignmentId);
      }

      const data = await this.service.listAssignmentSubmissions(req.instituteId!, req.params.assignmentId);
      return sendResponse({ res, data, message: 'Assignment submissions fetched successfully' });
    } catch (e) { next(e); }
  }

  getAssignmentSubmissionFeedback = async (req: Request, res: Response, next: NextFunction) => {
    try {
      const submission = await prisma.assignmentSubmission.findFirst({
        where: { id: req.params.submissionId, institute_id: req.instituteId! },
        include: {
          assignment: { select: { id: true, batch_id: true, teacher_id: true } },
        },
      });

      if (!submission) {
        throw new ApiError('Assignment submission not found', 404, 'NOT_FOUND');
      }

      if (req.user?.role === 'student') {
        const student = await this.resolveStudentProfile(req.instituteId!, req.user!.userId);
        if (!student || submission.student_id !== student.id) {
          throw new ApiError('You are not authorized to access this feedback', 403, 'FORBIDDEN');
        }
      }

      if (req.user?.role === 'teacher') {
        await this.ensureTeacherCanAccessAssignment(req.instituteId!, req.user!.userId, submission.assignment_id);
      }

      const data = await this.service.getAssignmentSubmissionFeedback(req.instituteId!, req.params.submissionId);
      return sendResponse({ res, data, message: 'Assignment feedback history fetched successfully' });
    } catch (e) { next(e); }
  }

  reviewAssignmentSubmission = async (req: Request, res: Response, next: NextFunction) => {
    try {
      if (req.user?.role === 'teacher') {
        const submission = await prisma.assignmentSubmission.findFirst({
          where: { id: req.params.submissionId, institute_id: req.instituteId! },
          select: { assignment_id: true },
        });

        if (!submission) {
          throw new ApiError('Assignment submission not found', 404, 'NOT_FOUND');
        }

        await this.ensureTeacherCanAccessAssignment(req.instituteId!, req.user!.userId, submission.assignment_id);
      }

      const data = await this.service.reviewAssignmentSubmission(
        req.instituteId!,
        req.params.submissionId,
        req.user!.userId,
        req.body,
      );

      const submission = await prisma.assignmentSubmission.findFirst({
        where: { id: req.params.submissionId, institute_id: req.instituteId! },
        include: { assignment: { select: { id: true, batch_id: true } } },
      });
      if (submission?.assignment?.batch_id) {
        emitBatchSync(req.instituteId!, submission.assignment.batch_id, 'assignment_reviewed', {
          assignment_id: submission.assignment.id,
          submission_id: req.params.submissionId,
        });
        
        // Notify student
        const { NotificationService } = await import('../notification/notification.service');
        const student = await prisma.student.findFirst({
           where: { id: submission.student_id },
           select: { user_id: true }
        });
        
        if (student?.user_id) {
           await NotificationService.sendNotificationToUser(student.user_id, {
              title: 'Assignment Reviewed',
              body: `Your submission has been reviewed.`,
              type: 'material',
              institute_id: req.instituteId!,
              meta: {
                 route: '/student/assignments',
                 assignment_id: submission.assignment.id
              }
           });
        }
      }

      return sendResponse({ res, data, message: 'Assignment submission reviewed successfully' });
    } catch (e) { next(e); }
  }

  assignmentAnalytics = async (req: Request, res: Response, next: NextFunction) => {
    try {
      const filter = {
        batchId: req.query.batchId as string,
        teacherId: req.query.teacherId as string,
        subject: req.query.subject as string,
      };

      if (req.user?.role === 'teacher') {
        const teacherId = await this.resolveTeacherId(req.instituteId!, req.user!.userId);
        if (!teacherId) {
          throw new ApiError('Teacher profile not found', 403, 'FORBIDDEN');
        }
        filter.teacherId = teacherId;
      }

      const data = await this.service.getAssignmentAnalytics(req.instituteId!, filter);
      return sendResponse({ res, data, message: 'Assignment analytics fetched successfully' });
    } catch (e) { next(e); }
  }

  // DOUBTS
  askDoubt = async (req: Request, res: Response, next: NextFunction) => {
    try {
      // Typically student_id is req.user.userId, but checking logic depends on the specific user schema implementation
      const data = await this.service.askDoubt(req.instituteId!, req.user!.userId, req.body);
      if (req.body.batch_id) {
        emitBatchSync(req.instituteId!, req.body.batch_id, 'doubt_created', {
          doubt_id: (data as any)?.id,
        });

        // Notify teacher about new doubt
        try {
          const { NotificationService } = await import('../notification/notification.service');
          const batch = await prisma.batch.findUnique({
            where: { id: req.body.batch_id },
            select: { teacher_id: true, name: true, institute: { select: { settings: true } } }
          });
          if (batch) {
            const metaMap = (batch.institute.settings as any)?.batch_meta || {};
            const batchMeta = metaMap[req.body.batch_id] || {};
            const teacherIds = resolveBatchTeacherIds(batchMeta, batch.teacher_id);
            const teachers = teacherIds.length > 0
              ? await prisma.teacher.findMany({
                where: {
                  institute_id: req.instituteId!,
                  OR: [
                    { id: { in: teacherIds } },
                    { user_id: { in: teacherIds } },
                  ],
                },
                select: { user_id: true },
              })
              : [];

            for (const teacher of teachers) {
              if (!teacher.user_id) continue;
              await NotificationService.sendNotificationToUser(teacher.user_id, {
                title: 'New Doubt from Student',
                body: `A student has a new doubt in "${batch.name || 'your batch'}": "${((req.body.question_text || 'doubt') as string).substring(0, 50)}..."`,
                type: 'doubt',
                institute_id: req.instituteId!,
                meta: {
                  route: '/teacher/doubts',
                  doubt_id: (data as any)?.id,
                  batch_id: req.body.batch_id
                }
              });
            }
          }
        } catch (err) {
          console.error('[ContentController] Failed to send doubt notification to teacher:', err);
        }
      } else {
        emitInstituteDashboardSync(req.instituteId!, 'doubt_created');
      }
      return sendResponse({ res, data, message: 'Doubt submitted successfully', statusCode: 201 });
    } catch (e) { next(e); }
  }

  respondDoubt = async (req: Request, res: Response, next: NextFunction) => {
    try {
      const data = await this.service.respondToDoubt(req.params.doubtId, req.instituteId!, req.user!.userId, req.body);
      const doubt = await prisma.doubt.findFirst({
        where: { id: req.params.doubtId, institute_id: req.instituteId! },
        select: { batch_id: true },
      });
      if (doubt?.batch_id) {
        emitBatchSync(req.instituteId!, doubt.batch_id, 'doubt_responded', {
          doubt_id: req.params.doubtId,
        });
      } else {
        emitInstituteDashboardSync(req.instituteId!, 'doubt_responded', { doubt_id: req.params.doubtId });
      }

      // Notify student
      const actualDoubt = await prisma.doubt.findUnique({
        where: { id: req.params.doubtId },
        select: { student_id: true }
      });
      
      const { NotificationService } = await import('../notification/notification.service');
      const student = await prisma.student.findFirst({
        where: { id: actualDoubt?.student_id },
        select: { user_id: true }
      });

      if (student?.user_id) {
        await NotificationService.sendNotificationToUser(student.user_id, {
          title: 'Doubt Resolved',
          body: 'Your doubt has been answered. Click to view solution.',
          type: 'doubt',
          institute_id: req.instituteId!,
          meta: {
            route: '/student/doubts',
            doubt_id: req.params.doubtId
          }
        });
      }

      return sendResponse({ res, data, message: 'Doubt answer submitted successfully' });
    } catch (e) { next(e); }
  }

  listDoubts = async (req: Request, res: Response, next: NextFunction) => {
    try {
      const data = await this.service.listDoubts(req.instituteId!, {
          batchId: req.query.batchId as string,
          studentId: req.query.studentId as string,
          status: req.query.status as string,
          subject: req.query.subject as string
      });
      return sendResponse({ res, data, message: 'Doubts fetched successfully' });
    } catch (e) { next(e); }
  }
}


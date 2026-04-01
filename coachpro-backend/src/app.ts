import express, { Express, Request, Response, NextFunction } from 'express';
import cors from 'cors';
import helmet from 'helmet';
import rateLimit from 'express-rate-limit';
import morgan from 'morgan';
import { errorHandler, ApiError } from './middleware/error.middleware';

import authRoutes from './modules/auth/auth.routes';
import batchRoutes from './modules/batch/batch.routes';
import studentRoutes from './modules/student/student.routes';
import teacherRoutes from './modules/teacher/teacher.routes';
import instituteRoutes from './modules/institute/institute.routes';
import feeRoutes from './modules/fee/fee.routes';
import attendanceRoutes from './modules/attendance/attendance.routes';
import contentRoutes from './modules/content/content.routes';
import announcementRoutes from './modules/announcement/announcement.routes';
import examRoutes from './modules/exam/exam.routes';
import leadRoutes from './modules/lead/lead.routes';
import staffRoutes from './modules/staff/staff.routes';
import quizRoutes from './modules/quiz/quiz.routes';
import lectureRoutes from './modules/lecture/lecture.routes';
import doubtRoutes from './modules/doubt/doubt.routes';
import chatRoutes from './modules/chat/chat.routes';
import analyticsRoutes from './modules/analytics/analytics.routes';
import usersRoutes from './modules/users/users.routes';
import parentRoutes from './modules/parent/parent.routes';
import payrollRoutes from './modules/payroll/payroll.routes';
import certificateRoutes from './modules/certificate/certificate.routes';
import timetableRoutes from './modules/timetable/timetable.routes';
import auditLogRoutes from './modules/audit-log/audit-log.routes';
import whatsappRoutes from './modules/whatsapp/whatsapp.routes';
import appUpdateRoutes from './modules/app-update/app-update.routes';
import notificationRoutes from './modules/notification/notification.routes';
import { emitBatchSync, emitInstituteDashboardSync } from './config/socket';
import { AuditAction, Logger } from './utils/logger';

const app: Express = express();
app.set('trust proxy', true); // Trust proxy chain (Azure/App Gateway/CDN)

// Security Middleware
app.use(helmet({
  crossOriginResourcePolicy: { policy: 'cross-origin' },
  // Enable a conservative CSP in production; disable in development
  contentSecurityPolicy: process.env.NODE_ENV === 'production' ? undefined : false,
}));
const allowedOrigins = (process.env.ALLOWED_ORIGINS || '').split(',').map(o => o.trim()).filter(Boolean);

app.use(cors({
  origin: function(origin, callback) {
    // Allow mobile apps (no origin) or whitelisted domains
    if (!origin || allowedOrigins.length === 0 || allowedOrigins.includes('*') || allowedOrigins.includes(origin)) {
      callback(null, true);
    } else {
      callback(new ApiError(`Origin ${origin} not allowed by CORS`, 403, 'FORBIDDEN'));
    }
  },
  credentials: true,
  methods: ['GET', 'POST', 'PUT', 'PATCH', 'DELETE', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Authorization', 'Accept', 'Origin', 'X-Requested-With'],
}));

// Rate limiter for sensitive endpoints (OTP / login) — 10 requests per minute per IP
const authLimiter = rateLimit({
  windowMs: 1 * 60 * 1000, // 1 minute
  max: 10,
  standardHeaders: true,
  legacyHeaders: false,
  validate: false,
  keyGenerator: (req) => {
    const raw = String(req.ip || req.socket.remoteAddress || 'unknown').replace(/^::ffff:/, '');
    // Some proxies can pass IPv4 with port (e.g. 10.224.173.29:65509)
    if (raw.includes('.') && raw.includes(':')) {
      return raw.substring(0, raw.lastIndexOf(':'));
    }
    return raw;
  },
});

// Parsing & Logging Middleware
app.use(express.json());
app.use(express.urlencoded({ extended: true }));
app.use(morgan('dev'));

const mutatingMethods = new Set(['POST', 'PUT', 'PATCH', 'DELETE']);

const inferAuditAction = (method: string): AuditAction => {
  switch (method) {
    case 'POST':
      return AuditAction.CREATE;
    case 'PUT':
    case 'PATCH':
      return AuditAction.UPDATE;
    case 'DELETE':
      return AuditAction.DELETE;
    default:
      return AuditAction.UPDATE;
  }
};

const shouldSkipAutoAudit = (path: string): boolean => {
  const ignoredPrefixes = [
    '/api/auth',
    '/api/notifications/register-token',
  ];

  if (ignoredPrefixes.some((prefix) => path.startsWith(prefix))) return true;
  if (path.includes('/read-all') || path.endsWith('/read')) return true;
  return false;
};

const tryExtractBatchId = (req: Request): string | undefined => {
  const bodyBatch = (req.body?.batch_id ?? req.body?.batchId)?.toString();
  if (bodyBatch && bodyBatch.trim().length > 0) return bodyBatch.trim();

  const paramBatch = (req.params?.batchId ?? req.params?.id)?.toString();
  if (paramBatch && paramBatch.trim().length > 0 && req.originalUrl.includes('/batches')) return paramBatch.trim();

  const queryBatch = (req.query?.batchId ?? req.query?.batch_id)?.toString();
  if (queryBatch && queryBatch.trim().length > 0) return queryBatch.trim();

  return undefined;
};

app.use((req: Request, res: Response, next: NextFunction) => {
  const startedAt = Date.now();

  res.on('finish', () => {
    try {
      if (!mutatingMethods.has(req.method.toUpperCase())) return;
      if (res.statusCode >= 400) return;
      if (shouldSkipAutoAudit(req.originalUrl)) return;

      const anyReq = req as any;
      const instituteId = anyReq?.instituteId || anyReq?.user?.instituteId;
      if (!instituteId) return;

      const actorId = anyReq?.user?.userId;
      const entityType = req.baseUrl.replace('/api/', '') || req.path.split('/').filter(Boolean)[0] || 'system';
      const entityId = (req.params?.id || req.params?.studentId || req.params?.teacherId || req.params?.batchId || '').toString() || undefined;
      const action = inferAuditAction(req.method.toUpperCase());

      void Logger.log({
        actorId,
        instituteId,
        action,
        entityType,
        entityId,
        newValue: {
          method: req.method,
          path: req.originalUrl,
          status: res.statusCode,
          duration_ms: Date.now() - startedAt,
        },
      });

      const reason = `${entityType}_${req.method.toLowerCase()}`;
      emitInstituteDashboardSync(instituteId, reason, {
        path: req.originalUrl,
        actor_id: actorId,
      });

      const batchId = tryExtractBatchId(req);
      if (batchId) {
        emitBatchSync(instituteId, batchId, reason, {
          path: req.originalUrl,
          actor_id: actorId,
        });
      }
    } catch {
      // Ignore sync/audit middleware failures to avoid impacting API responses.
    }
  });

  next();
});

// Basic Healthcheck Route
app.get('/health', (req: Request, res: Response) => {
  res.status(200).json({ success: true, message: 'CoachPro API is running smoothly' });
});

app.get('/api', (req: Request, res: Response) => {
  res.status(200).json({ success: true, message: 'CoachPro Backend API is LIVE' });
});

// Import and use routes here:
import youtubeRoutes from './modules/youtube/youtube.routes';

import uploadRoutes from './modules/upload/upload.routes';

app.use('/api/auth', authLimiter, authRoutes);
app.use('/api/batches', batchRoutes);
app.use('/api/students', studentRoutes);
app.use('/api/teachers', teacherRoutes);
app.use('/api/institutes', instituteRoutes);
app.use('/api/fees', feeRoutes);
app.use('/api/attendance', attendanceRoutes);
app.use('/api/content', contentRoutes);
app.use('/api/announcements', announcementRoutes);
app.use('/api/exams', examRoutes);
app.use('/api/leads', leadRoutes);
app.use('/api/staff', staffRoutes);
app.use('/api/quizzes', quizRoutes);
app.use('/api/lectures', lectureRoutes);
app.use('/api/doubts', doubtRoutes);
app.use('/api/chat', chatRoutes);
app.use('/api/analytics', analyticsRoutes);
app.use('/api/users', usersRoutes);
app.use('/api/parents', parentRoutes);
app.use('/api/payroll', payrollRoutes);
app.use('/api/certificates', certificateRoutes);
app.use('/api/timetable', timetableRoutes);
app.use('/api/audit-logs', auditLogRoutes);
app.use('/api/whatsapp', whatsappRoutes);
app.use('/api/app-update', appUpdateRoutes);
app.use('/api/notifications', notificationRoutes);
app.use('/api/youtube', youtubeRoutes);
app.use('/api/upload', uploadRoutes);

// 404 Catcher
app.all('*', (req: Request, res: Response, next: NextFunction) => {
    res.status(404).json({ success: false, error: { code: 'NOT_FOUND', message: `Can't find ${req.originalUrl} on this server` } });
});

// Global Error Handler
app.use(errorHandler);

export default app;

import express, { Express, Request, Response, NextFunction } from 'express';
import cors from 'cors';
import helmet from 'helmet';
import rateLimit from 'express-rate-limit';
import morgan from 'morgan';
import { randomUUID } from 'crypto';
import { errorHandler, ApiError } from './middleware/error.middleware';
import { xssMiddleware } from './middleware/xss.middleware';

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
import { buildCorsPolicy, isOriginAllowed } from './utils/cors';

const app: Express = express();
const trustProxyHops = Number.parseInt(process.env.TRUST_PROXY_HOPS || '1', 10);
app.set('trust proxy', Number.isFinite(trustProxyHops) ? trustProxyHops : 1);
app.disable('x-powered-by');

const isProduction = process.env.NODE_ENV === 'production';
const corsPolicy = buildCorsPolicy(process.env.NODE_ENV, process.env.ALLOWED_ORIGINS || '');
const mutatingMethods = new Set(['POST', 'PUT', 'PATCH', 'DELETE']);

if (corsPolicy.allowTrustedDevOrigins) {
  console.info(
    '[SECURITY] ALLOWED_ORIGINS is empty. CORS will allow localhost/private-network browser origins in development only.',
  );
} else if (isProduction && corsPolicy.allowedOrigins.length === 0 && !corsPolicy.hasWildcardOrigin) {
  console.warn('[SECURITY] ALLOWED_ORIGINS is empty in production. Browser origins are blocked by CORS.');
}

const normalizeAddress = (ipRaw: string): string => {
  const value = String(ipRaw || '').replace(/^::ffff:/, '').trim();
  if (!value) return 'unknown';

  // Strip ports from values like "10.224.173.29:65509".
  if (value.includes('.') && value.includes(':')) {
    return value.substring(0, value.lastIndexOf(':'));
  }

  return value;
};

const shouldTrustForwardedFor = (process.env.TRUST_FORWARDED_FOR || '').toLowerCase() === 'true';
const extractClientIp = (req: Request): string => {
  const socketIp = normalizeAddress(req.socket.remoteAddress || '');
  if (!shouldTrustForwardedFor) return socketIp;

  const forwarded = String(req.headers['x-forwarded-for'] || '')
    .split(',')
    .map((part) => part.trim())
    .filter(Boolean)[0];

  return normalizeAddress(forwarded || socketIp);
};

const defaultRateLimitHandler = (req: Request, res: Response) => {
  res.status(429).json({
    success: false,
    error: {
      code: 'RATE_LIMITED',
      message: 'Too many requests. Please try again later.',
      ref: req.requestId,
    },
  });
};

app.use((req: Request, res: Response, next: NextFunction) => {
  const incomingRequestId = String(req.headers['x-request-id'] || '').trim();
  const requestId = incomingRequestId || randomUUID();
  req.requestId = requestId;
  res.setHeader('X-Request-Id', requestId);
  next();
});

const globalApiLimiter = rateLimit({
  windowMs: 60 * 1000,
  max: Number.parseInt(process.env.GLOBAL_API_RATE_LIMIT || (isProduction ? '100' : '1000'), 10),
  standardHeaders: true,
  legacyHeaders: false,
  validate: false,
  keyGenerator: extractClientIp,
  skip: (req: Request) => {
    const path = String(req.path || '').trim();
    return path === '/notifications/register-token';
  },
  handler: defaultRateLimitHandler,
});

const loginLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: Number.parseInt(process.env.LOGIN_RATE_LIMIT || '5', 10),
  standardHeaders: true,
  legacyHeaders: false,
  validate: false,
  skipSuccessfulRequests: true,
  keyGenerator: extractClientIp,
  handler: defaultRateLimitHandler,
});

const refreshLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: Number.parseInt(process.env.REFRESH_RATE_LIMIT || '30', 10),
  standardHeaders: true,
  legacyHeaders: false,
  validate: false,
  keyGenerator: extractClientIp,
  handler: defaultRateLimitHandler,
});

const otpSendLimiter = rateLimit({
  windowMs: 60 * 60 * 1000,
  max: Number.parseInt(process.env.OTP_SEND_RATE_LIMIT || '5', 10),
  standardHeaders: true,
  legacyHeaders: false,
  validate: false,
  keyGenerator: (req: Request) => {
    const phone = String(req.body?.phone || '').replace(/\D/g, '').slice(-15) || 'unknown-phone';
    return `${extractClientIp(req)}:${phone}`;
  },
  handler: defaultRateLimitHandler,
});

const otpVerifyLimiter = rateLimit({
  windowMs: 10 * 60 * 1000,
  max: Number.parseInt(process.env.OTP_VERIFY_RATE_LIMIT || '10', 10),
  standardHeaders: true,
  legacyHeaders: false,
  validate: false,
  keyGenerator: (req: Request) => {
    const phone = String(req.body?.phone || '').replace(/\D/g, '').slice(-15) || 'unknown-phone';
    return `${extractClientIp(req)}:${phone}`;
  },
  handler: defaultRateLimitHandler,
});

// Security Middleware
app.use(helmet({
  crossOriginResourcePolicy: { policy: 'cross-origin' },
  contentSecurityPolicy: isProduction
    ? {
        directives: {
          defaultSrc: ["'self'"],
          scriptSrc: ["'self'"],
          styleSrc: ["'self'", "'unsafe-inline'"],
          imgSrc: ["'self'", 'data:', 'https:'],
          connectSrc: ["'self'", 'https:', 'wss:'],
          objectSrc: ["'none'"],
          frameAncestors: ["'none'"],
          baseUri: ["'self'"],
          formAction: ["'self'"],
        },
      }
    : false,
  frameguard: { action: 'deny' },
  referrerPolicy: { policy: 'strict-origin-when-cross-origin' },
  hsts: isProduction
    ? {
        maxAge: 31536000,
        includeSubDomains: true,
        preload: true,
      }
    : false,
  xssFilter: true,
}));

// Parsing & Logging Middleware
app.use(express.json({
  limit: process.env.MAX_JSON_BODY_SIZE || '1mb',
  strict: true,
  verify: (req, _res, buf) => {
    (req as any).rawBody = buf.toString('utf8');
  },
}));
app.use(express.urlencoded({
  extended: true,
  limit: process.env.MAX_JSON_BODY_SIZE || '1mb',
}));
app.use(xssMiddleware);
app.use(morgan(isProduction ? 'combined' : 'dev'));

app.use((req: Request, _res: Response, next: NextFunction) => {
  if (!mutatingMethods.has(req.method.toUpperCase())) return next();
  if (req.path.startsWith('/api/v1/upload') || req.path.startsWith('/api/upload')) return next();

  const contentType = String(req.headers['content-type'] || '').toLowerCase();
  const isAllowedType =
    contentType.includes('application/json') ||
    contentType.includes('application/x-www-form-urlencoded') ||
    contentType.includes('multipart/form-data');

  if (!isAllowedType) {
    return next(new ApiError('Unsupported content type for this endpoint', 415, 'UNSUPPORTED_MEDIA_TYPE'));
  }

  return next();
});

app.use((req, res, next) => {
  if (req.headers['access-control-request-private-network']) {
    res.setHeader('Access-Control-Allow-Private-Network', 'true');
  }
  next();
});

app.use(cors({
  origin: function(origin, callback) {
    // Allow mobile apps (no origin) plus allowed browser origins from policy.
    if (isOriginAllowed(origin, corsPolicy)) {
      callback(null, true);
    } else {
      callback(new ApiError(`Origin ${origin} not allowed by CORS`, 403, 'FORBIDDEN'));
    }
  },
  credentials: true,
  methods: ['GET', 'POST', 'PUT', 'PATCH', 'DELETE', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Authorization', 'Accept', 'Origin', 'X-Requested-With', 'X-Request-Id'],
}));

app.use('/api/v1', globalApiLimiter);
app.use('/api/v1/auth/login', loginLimiter);
app.use('/api/v1/auth/refresh', refreshLimiter);
app.use('/api/v1/auth/otp/send', otpSendLimiter);
app.use('/api/v1/auth/otp/verify', otpVerifyLimiter);
// Backward-compatible auth rate limits for clients still using /api/* (without /v1).
app.use('/api/auth/login', loginLimiter);
app.use('/api/auth/refresh', refreshLimiter);
app.use('/api/auth/otp/send', otpSendLimiter);
app.use('/api/auth/otp/verify', otpVerifyLimiter);

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
    '/api/v1/auth',
    '/api/auth',
    '/api/v1/notifications/register-token',
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
      const entityType = req.baseUrl.replace('/api/v1/', '').replace('/api/', '') || req.path.split('/').filter(Boolean)[0] || 'system';
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
  res.status(200).json({ success: true, message: 'Excellence API is running smoothly' });
});

app.get('/api/v1', (req: Request, res: Response) => {
  res.status(200).json({ success: true, message: 'Excellence Backend API v1 is LIVE' });
});

app.get('/api', (req: Request, res: Response) => {
  res.status(200).json({ success: true, message: 'Excellence Backend API is LIVE. Please use /api/v1 endpoints.' });
});

// Client Config Route
app.get('/api/v1/config/client', (req: Request, res: Response) => {
  res.status(200).json({
    success: true,
    data: {
      firebase: {
        web: {
          apiKey: process.env.FIREBASE_API_KEY_WEB,
          appId: process.env.FIREBASE_APP_ID_WEB,
          messagingSenderId: process.env.FIREBASE_MESSAGING_SENDER_ID,
          projectId: process.env.FIREBASE_PROJECT_ID,
          authDomain: process.env.FIREBASE_AUTH_DOMAIN,
          storageBucket: process.env.FIREBASE_STORAGE_BUCKET,
          measurementId: process.env.FIREBASE_MEASUREMENT_ID,
        },
        android: {
          apiKey: process.env.FIREBASE_API_KEY_ANDROID,
          appId: process.env.FIREBASE_APP_ID_ANDROID,
          messagingSenderId: process.env.FIREBASE_MESSAGING_SENDER_ID,
          projectId: process.env.FIREBASE_PROJECT_ID,
          storageBucket: process.env.FIREBASE_STORAGE_BUCKET,
        },
        ios: {
          apiKey: process.env.FIREBASE_API_KEY_IOS,
          appId: process.env.FIREBASE_APP_ID_IOS,
          messagingSenderId: process.env.FIREBASE_MESSAGING_SENDER_ID,
          projectId: process.env.FIREBASE_PROJECT_ID,
          storageBucket: process.env.FIREBASE_STORAGE_BUCKET,
          iosClientId: process.env.FIREBASE_IOS_CLIENT_ID,
          iosBundleId: process.env.FIREBASE_IOS_BUNDLE_ID,
        },
        macos: {
          apiKey: process.env.FIREBASE_API_KEY_MACOS,
          appId: process.env.FIREBASE_APP_ID_MACOS,
          messagingSenderId: process.env.FIREBASE_MESSAGING_SENDER_ID,
          projectId: process.env.FIREBASE_PROJECT_ID,
          storageBucket: process.env.FIREBASE_STORAGE_BUCKET,
          iosClientId: process.env.FIREBASE_MACOS_CLIENT_ID,
          iosBundleId: process.env.FIREBASE_MACOS_BUNDLE_ID,
        }
      }
    }
  });
});

// Import and use routes here:
import youtubeRoutes from './modules/youtube/youtube.routes';

import uploadRoutes from './modules/upload/upload.routes';

const API_V1 = '/api/v1';
const API_LEGACY = '/api';

app.use(`${API_V1}/auth`, authRoutes);
app.use(`${API_V1}/batches`, batchRoutes);
app.use(`${API_V1}/students`, studentRoutes);
app.use(`${API_V1}/teachers`, teacherRoutes);
app.use(`${API_V1}/institutes`, instituteRoutes);
app.use(`${API_V1}/fees`, feeRoutes);
app.use(`${API_V1}/attendance`, attendanceRoutes);
app.use(`${API_V1}/content`, contentRoutes);
app.use(`${API_V1}/announcements`, announcementRoutes);
app.use(`${API_V1}/exams`, examRoutes);
app.use(`${API_V1}/leads`, leadRoutes);
app.use(`${API_V1}/staff`, staffRoutes);
app.use(`${API_V1}/quizzes`, quizRoutes);
app.use(`${API_V1}/lectures`, lectureRoutes);
app.use(`${API_V1}/doubts`, doubtRoutes);
app.use(`${API_V1}/chat`, chatRoutes);
app.use(`${API_V1}/analytics`, analyticsRoutes);
app.use(`${API_V1}/users`, usersRoutes);
app.use(`${API_V1}/parents`, parentRoutes);
app.use(`${API_V1}/payroll`, payrollRoutes);
app.use(`${API_V1}/certificates`, certificateRoutes);
app.use(`${API_V1}/timetable`, timetableRoutes);
app.use(`${API_V1}/audit-logs`, auditLogRoutes);
app.use(`${API_V1}/whatsapp`, whatsappRoutes);
app.use(`${API_V1}/app-update`, appUpdateRoutes);
app.use(`${API_V1}/notifications`, notificationRoutes);
app.use(`${API_V1}/youtube`, youtubeRoutes);
app.use(`${API_V1}/upload`, uploadRoutes);

// Backward-compatible mounts for clients still calling /api/*.
app.use(`${API_LEGACY}/auth`, authRoutes);
app.use(`${API_LEGACY}/app-update`, appUpdateRoutes);

// 404 Catcher
app.all('*', (req: Request, res: Response, _next: NextFunction) => {
    res.status(404).json({ success: false, error: { code: 'NOT_FOUND', message: `Can't find ${req.originalUrl} on this server` } });
});

// Global Error Handler
app.use(errorHandler);

export default app;


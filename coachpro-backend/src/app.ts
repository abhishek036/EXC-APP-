import express, { Express, Request, Response, NextFunction } from 'express';
import cors from 'cors';
import helmet from 'helmet';
import rateLimit from 'express-rate-limit';
import morgan from 'morgan';
import { errorHandler } from './middleware/error.middleware';

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

const app: Express = express();
app.set('trust proxy', true); // Trust proxy chain (Azure/App Gateway/CDN)

// Security Middleware
app.use(helmet({
  crossOriginResourcePolicy: { policy: 'cross-origin' },
  // Enable a conservative CSP in production; disable in development
  contentSecurityPolicy: process.env.NODE_ENV === 'production' ? undefined : false,
}));
// Allow all origins — mobile apps (Flutter/React Native) don't send an Origin header,
// and there is no browser-based UI to protect. All auth is JWT-based.
app.use(cors({
  origin: function(origin, callback) {
    callback(null, true);
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

// Basic Healthcheck Route
app.get('/health', (req: Request, res: Response) => {
  res.status(200).json({ success: true, message: 'CoachPro API is running smoothly' });
});

app.get('/api', (req: Request, res: Response) => {
  res.status(200).json({ success: true, message: 'CoachPro Backend API is LIVE' });
});

// Import and use routes here:
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

// 404 Catcher
app.all('*', (req: Request, res: Response, next: NextFunction) => {
    res.status(404).json({ success: false, error: { code: 'NOT_FOUND', message: `Can't find ${req.originalUrl} on this server` } });
});

// Global Error Handler
app.use(errorHandler);

export default app;

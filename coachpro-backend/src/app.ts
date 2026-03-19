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

const app: Express = express();

// Security Middleware
const allowedOrigin = process.env.CORS_ORIGIN || 'http://localhost:8080';
app.use(helmet({
  crossOriginResourcePolicy: { policy: 'cross-origin' },
  // Enable a conservative CSP in production; disable in development
  contentSecurityPolicy: process.env.NODE_ENV === 'production' ? undefined : false,
}));
app.use(cors({
  origin: (origin, callback) => {
    // Allow server-to-server or same-origin requests when origin is undefined (e.g., Postman, mobile clients)
    if (!origin) return callback(null, true);
    if (origin === allowedOrigin) return callback(null, true);
    return callback(new Error('CORS not allowed by policy'));
  },
  credentials: true,
}));

// Rate limiter for sensitive endpoints (OTP / login) — 10 requests per minute per IP
const authLimiter = rateLimit({
  windowMs: 1 * 60 * 1000, // 1 minute
  max: 10,
  standardHeaders: true,
  legacyHeaders: false,
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

// 404 Catcher
app.all('*', (req: Request, res: Response, next: NextFunction) => {
    res.status(404).json({ success: false, error: { code: 'NOT_FOUND', message: `Can't find ${req.originalUrl} on this server` } });
});

// Global Error Handler
app.use(errorHandler);

export default app;

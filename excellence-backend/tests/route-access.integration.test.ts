import express from 'express';
import request from 'supertest';
import { describe, expect, jest, test } from '@jest/globals';

jest.mock('../src/middleware/auth.middleware', () => {
  const authenticateJWT = (req: any, _res: any, next: any) => {
    const role = req.headers['x-role'];
    req.user = {
      userId: 'u-1',
      role: role || 'guest',
      instituteId: 'inst-1',
      phone: '9999999999',
    };
    req.instituteId = 'inst-1';
    next();
  };

  const requireRole = (rolesOrFirst: string | string[], ...rest: string[]) => {
    const roles: string[] = Array.isArray(rolesOrFirst)
      ? rolesOrFirst
      : [rolesOrFirst, ...rest];
    const allowed = roles.map((r) => r.toLowerCase());

    return (req: any, res: any, next: any) => {
      const role = String(req.user?.role || '').toLowerCase();
      if (!allowed.includes(role)) {
        return res.status(403).json({ success: false, error: 'FORBIDDEN' });
      }
      next();
    };
  };

  return { authenticateJWT, requireRole };
});

jest.mock('../src/middleware/tenant.middleware', () => ({
  tenantMiddleware: (_req: any, _res: any, next: any) => next(),
}));

jest.mock('../src/middleware/validate.middleware', () => ({
  validate: () => (_req: any, _res: any, next: any) => next(),
}));

jest.mock('../src/modules/attendance/attendance.controller', () => {
  return {
    AttendanceController: class {
      getStats = (_req: any, res: any) => res.status(200).json({ ok: true });
      mark = (_req: any, res: any) => res.status(200).json({ ok: true });
      getBatch = (_req: any, res: any) => res.status(200).json({ ok: true });
      getStudent = (_req: any, res: any) => res.status(200).json({ ok: true });
      reportIssue = (_req: any, res: any) => res.status(200).json({ ok: true });
    },
  };
});

jest.mock('../src/modules/timetable/timetable.controller', () => {
  return {
    TimetableController: class {
      schedule = (_req: any, res: any) => res.status(200).json({ ok: true });
      getByBatch = (_req: any, res: any) => res.status(200).json({ ok: true });
      getMySchedule = (_req: any, res: any) => res.status(200).json({ ok: true });
      getByTeacher = (_req: any, res: any) => res.status(200).json({ ok: true });
      createMySchedule = (_req: any, res: any) => res.status(200).json({ ok: true });
      updateMySchedule = (_req: any, res: any) => res.status(200).json({ ok: true });
      clearMyPastSchedules = (_req: any, res: any) => res.status(200).json({ ok: true });
      deleteMySchedule = (_req: any, res: any) => res.status(200).json({ ok: true });
    },
  };
});

jest.mock('../src/modules/fee/fee.controller', () => {
  return {
    FeeController: class {
      defineStructure = (_req: any, res: any) => res.status(200).json({ ok: true });
      getStructure = (_req: any, res: any) => res.status(200).json({ ok: true });
      generateMonthly = (_req: any, res: any) => res.status(200).json({ ok: true });
      getRecords = (_req: any, res: any) => res.status(200).json({ ok: true });
      recordPayment = (_req: any, res: any) => res.status(200).json({ ok: true });
      adjustFeeRecord = (_req: any, res: any) => res.status(200).json({ ok: true });
      submitPaymentProof = (_req: any, res: any) => res.status(200).json({ ok: true });
      getMyPaymentProofs = (_req: any, res: any) => res.status(200).json({ ok: true });
      getPaymentsForReview = (_req: any, res: any) => res.status(200).json({ ok: true });
      approvePaymentProof = (_req: any, res: any) => res.status(200).json({ ok: true });
      rejectPaymentProof = (_req: any, res: any) => res.status(200).json({ ok: true });
    },
  };
});

jest.mock('../src/modules/chat/chat.controller', () => ({
  ChatController: {
    getRooms: (_req: any, res: any) => res.status(200).json({ ok: true }),
    getHistory: (_req: any, res: any) => res.status(200).json({ ok: true }),
    sendMessage: (_req: any, res: any) => res.status(200).json({ ok: true }),
    deleteMessage: (_req: any, res: any) => res.status(200).json({ ok: true }),
  },
}));

jest.mock('../src/modules/lecture/lecture.controller', () => ({
  LectureController: {
    listLectures: (_req: any, res: any) => res.status(200).json({ ok: true }),
    createLecture: (_req: any, res: any) => res.status(200).json({ ok: true }),
    updateLecture: (_req: any, res: any) => res.status(200).json({ ok: true }),
    deleteLecture: (_req: any, res: any) => res.status(200).json({ ok: true }),
  },
}));

import attendanceRoutes from '../src/modules/attendance/attendance.routes';
import timetableRoutes from '../src/modules/timetable/timetable.routes';
import feeRoutes from '../src/modules/fee/fee.routes';
import chatRoutes from '../src/modules/chat/chat.routes';
import lectureRoutes from '../src/modules/lecture/lecture.routes';

const appWith = (basePath: string, router: express.Router) => {
  const app = express();
  app.use(express.json());
  app.use(basePath, router);
  return app;
};

describe('route access integration', () => {
  test('attendance student report allows parent and blocks guest', async () => {
    const app = appWith('/attendance', attendanceRoutes);

    const ok = await request(app)
      .get('/attendance/student/stu-1')
      .set('x-role', 'parent');
    expect(ok.status).toBe(200);

    const blocked = await request(app)
      .get('/attendance/student/stu-1')
      .set('x-role', 'guest');
    expect(blocked.status).toBe(403);
  });

  test('fee payment route is admin-only', async () => {
    const app = appWith('/fees', feeRoutes);

    const blockedStudent = await request(app)
      .post('/fees/pay')
      .set('x-role', 'student')
      .send({ fee_record_id: 'f1', amount_paid: 10, payment_method: 'upi' });
    expect(blockedStudent.status).toBe(403);

    const okAdmin = await request(app)
      .post('/fees/pay')
      .set('x-role', 'admin')
      .send({ fee_record_id: 'f1', amount_paid: 10, payment_method: 'upi' });
    expect(okAdmin.status).toBe(200);
  });

  test('fee adjustment route is admin-only', async () => {
    const app = appWith('/fees', feeRoutes);

    const blockedTeacher = await request(app)
      .post('/fees/adjust')
      .set('x-role', 'teacher')
      .send({ fee_record_id: 'f1', delta_amount: 10, reason: 'manual correction' });
    expect(blockedTeacher.status).toBe(403);

    const okAdmin = await request(app)
      .post('/fees/adjust')
      .set('x-role', 'admin')
      .send({ fee_record_id: 'f1', delta_amount: 10, reason: 'manual correction' });
    expect(okAdmin.status).toBe(200);
  });

  test('chat allows parent role on rooms/history/messages', async () => {
    const app = appWith('/chat', chatRoutes);

    const rooms = await request(app).get('/chat/rooms').set('x-role', 'parent');
    expect(rooms.status).toBe(200);

    const history = await request(app)
      .get('/chat/batch/b-1/history')
      .set('x-role', 'parent');
    expect(history.status).toBe(200);

    const send = await request(app)
      .post('/chat/batch/b-1/messages')
      .set('x-role', 'parent')
      .send({ text: 'hello' });
    expect(send.status).toBe(200);
  });

  test('lecture batch listing allows parent role', async () => {
    const app = appWith('/lectures', lectureRoutes);

    const ok = await request(app)
      .get('/lectures/batch/b-1')
      .set('x-role', 'parent');
    expect(ok.status).toBe(200);
  });

  test('timetable schedule is admin/teacher-only and parent can read', async () => {
    const app = appWith('/timetable', timetableRoutes);

    const readBatchAsParent = await request(app)
      .get('/timetable/batch/b-1')
      .set('x-role', 'parent');
    expect(readBatchAsParent.status).toBe(200);

    const readTeacherAsParent = await request(app)
      .get('/timetable/teacher/t-1')
      .set('x-role', 'parent');
    expect(readTeacherAsParent.status).toBe(200);

    const blockedStudent = await request(app)
      .post('/timetable/schedule')
      .set('x-role', 'student')
      .send({});
    expect(blockedStudent.status).toBe(403);

    const okTeacher = await request(app)
      .post('/timetable/schedule')
      .set('x-role', 'teacher')
      .send({});
    expect(okTeacher.status).toBe(200);
  });
});

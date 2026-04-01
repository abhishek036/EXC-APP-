import fs from 'fs';
import path from 'path';

const backendRoot = path.resolve(__dirname, '..');

const read = (relativePath: string) =>
  fs.readFileSync(path.join(backendRoot, relativePath), 'utf8');

describe('security regression contracts', () => {
  test('auth middleware does not allow SUPER_USER bypass', () => {
    const content = read('src/middleware/auth.middleware.ts');
    expect(content).not.toContain("userRole === 'super_user'");
    expect(content).not.toContain("userRole === 'super user'");
  });

  test('fees pay endpoint is admin-only', () => {
    const content = read('src/modules/fee/fee.routes.ts');
    expect(content).toContain("router.post('/pay', requireRole('admin')");
  });

  test('attendance student endpoint has explicit role middleware', () => {
    const content = read('src/modules/attendance/attendance.routes.ts');
    expect(content).toContain("router.get('/student/:studentId', requireRole('admin', 'teacher', 'student', 'parent'), controller.getStudent);");
  });

  test('chat routes include parent role and rooms are role-protected', () => {
    const content = read('src/modules/chat/chat.routes.ts');
    expect(content).toContain("router.get('/rooms', requireRole('admin', 'teacher', 'student', 'parent'), ChatController.getRooms);");
    expect(content).toContain("router.get('/batch/:batchId/history', requireRole('admin', 'teacher', 'student', 'parent'), ChatController.getHistory);");
    expect(content).toContain("router.post('/batch/:batchId/messages', requireRole('admin', 'teacher', 'student', 'parent'), ChatController.sendMessage);");
  });

  test('timetable routes include parent access and schedule endpoint enabled', () => {
    const content = read('src/modules/timetable/timetable.routes.ts');
    expect(content).toContain("router.get('/batch/:batchId', requireRole('admin', 'teacher', 'student', 'parent'), controller.getByBatch);");
    expect(content).toContain("router.get('/teacher/:teacherId', requireRole('admin', 'teacher', 'student', 'parent'), controller.getByTeacher);");
    expect(content).toContain("router.post('/schedule', requireRole('admin', 'teacher'), controller.schedule);");
  });

  test('lecture routes include parent role for batch listing', () => {
    const content = read('src/modules/lecture/lecture.routes.ts');
    expect(content).toContain("router.get('/batch/:batchId', requireRole('admin', 'teacher', 'student', 'parent'), LectureController.listLectures);");
  });
});

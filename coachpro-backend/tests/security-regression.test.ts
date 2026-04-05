import fs from 'fs';
import path from 'path';

const backendRoot = path.resolve(__dirname, '..');

const read = (relativePath: string) =>
  fs.readFileSync(path.join(backendRoot, relativePath), 'utf8');

describe('security regression contracts', () => {
  test('app security middleware disables x-powered-by and applies layered rate limiting', () => {
    const content = read('src/app.ts');
    expect(content).toContain("app.disable('x-powered-by')");
    expect(content).toContain("app.use('/api', globalApiLimiter);");
    expect(content).toContain("app.use('/api/auth/login', loginLimiter);");
    expect(content).toContain("app.use('/api/auth/otp/send', otpSendLimiter);");
  });

  test('app enforces content type validation for mutating requests', () => {
    const content = read('src/app.ts');
    expect(content).toContain('Unsupported content type for this endpoint');
    expect(content).toContain("contentType.includes('application/json')");
    expect(content).toContain("contentType.includes('multipart/form-data')");
  });

  test('JWT verification pins algorithms and uses clock tolerance', () => {
    const content = read('src/middleware/auth.middleware.ts');
    expect(content).toContain("const JWT_VERIFY_ALGORITHMS: jwt.Algorithm[] = ['HS256']");
    expect(content).toContain('clockTolerance');
  });

  test('token generation uses explicit HS256 and bounded expirations', () => {
    const content = read('src/utils/otp.ts');
    expect(content).toContain("algorithm: 'HS256'");
    expect(content).toContain('normalizeRefreshExpiry');
    expect(content).toContain('ACCESS_TOKEN_FALLBACK = \'30m\'');
  });

  test('auth validators enforce numeric OTP and strong password policy', () => {
    const content = read('src/modules/auth/auth.validator.ts');
    expect(content).toContain('const strongPasswordSchema');
    expect(content).toContain('Password must include at least one uppercase letter');
    expect(content).toContain('OTP must be exactly 6 numeric digits');
  });

  test('whatsapp webhook validates signed payloads', () => {
    const content = read('src/modules/whatsapp/whatsapp.controller.ts');
    expect(content).toContain('x-hub-signature-256');
    expect(content).toContain('INVALID_SIGNATURE');
    expect(content).toContain('crypto.createHmac');
  });

  test('upload middleware blocks dangerous extensions', () => {
    const content = read('src/middleware/upload.ts');
    expect(content).toContain('const blockedExtensions = new Set([');
    expect(content).toContain("if (blockedExtensions.has(ext)) {");
  });

  test('socket connections require auth and enforce batch access checks', () => {
    const content = read('src/config/socket.ts');
    expect(content).toContain('io.use((socket, next) => {');
    expect(content).toContain('UNAUTHORIZED_SOCKET');
    expect(content).toContain('const canJoin = await canAccessBatch(payload, batchId);');
  });

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

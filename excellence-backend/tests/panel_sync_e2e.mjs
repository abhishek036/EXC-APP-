import jwt from 'jsonwebtoken';
import { PrismaClient } from '@prisma/client';

const prisma = new PrismaClient();
const BASE_URL = process.env.BASE_URL || 'http://127.0.0.1:3000/api';

function assert(condition, message) {
  if (!condition) {
    throw new Error(message);
  }
}

function dateKeyFromIso(iso) {
  const d = new Date(iso);
  const y = d.getUTCFullYear();
  const m = String(d.getUTCMonth() + 1).padStart(2, '0');
  const day = String(d.getUTCDate()).padStart(2, '0');
  return `${y}-${m}-${day}`;
}

async function api(method, path, token, body) {
  const headers = { Accept: 'application/json' };
  if (token) headers.Authorization = `Bearer ${token}`;
  if (body) headers['Content-Type'] = 'application/json';

  const res = await fetch(`${BASE_URL}${path}`, {
    method,
    headers,
    body: body ? JSON.stringify(body) : undefined,
  });

  let json = null;
  try {
    json = await res.json();
  } catch {
    json = null;
  }

  return {
    status: res.status,
    ok: res.ok,
    json,
    data: json?.data,
    message: json?.message,
  };
}

function makeToken(user, instituteId) {
  const secret = process.env.JWT_SECRET;
  assert(secret && secret.length >= 16, 'JWT_SECRET missing or too short in environment');

  return jwt.sign(
    {
      userId: user.id,
      role: String(user.role).toLowerCase(),
      instituteId,
      phone: user.phone || '0000000000',
    },
    secret,
    { expiresIn: '2h' },
  );
}

async function getContext() {
  const teacher = await prisma.teacher.findFirst({
    where: {
      is_active: true,
      user: { is_active: true, role: 'teacher' },
    },
    include: { user: true },
  });
  assert(teacher, 'No active teacher with user account found');

  const student = await prisma.student.findFirst({
    where: {
      institute_id: teacher.institute_id,
      is_active: true,
      user: { is_active: true, role: 'student' },
    },
    include: { user: true },
  });
  assert(student, 'No active student in teacher institute found');

  const admin = await prisma.user.findFirst({
    where: {
      institute_id: teacher.institute_id,
      role: 'admin',
      is_active: true,
    },
  });
  assert(admin, 'No active admin in teacher institute found');

  let batch = await prisma.batch.findFirst({
    where: {
      institute_id: teacher.institute_id,
      teacher_id: teacher.id,
      is_active: true,
    },
  });

  assert(batch, 'No active batch assigned to teacher found');

  await prisma.studentBatch.upsert({
    where: {
      student_id_batch_id: {
        student_id: student.id,
        batch_id: batch.id,
      },
    },
    update: {
      is_active: true,
      left_date: null,
    },
    create: {
      student_id: student.id,
      batch_id: batch.id,
      institute_id: teacher.institute_id,
      is_active: true,
    },
  });

  return { teacher, student, admin, batch };
}

async function run() {
  console.log('=== Panel Sync E2E (Teacher <-> Student <-> Batch) ===');
  console.log(`Target: ${BASE_URL}`);

  const { teacher, student, admin, batch } = await getContext();
  const instituteId = teacher.institute_id;

  const teacherToken = makeToken(teacher.user, instituteId);
  const studentToken = makeToken(student.user, instituteId);
  const adminToken = makeToken(admin, instituteId);

  const now = new Date();
  const scheduledAt = new Date(now.getTime() + 45 * 60 * 1000).toISOString();
  const scheduleDateKey = dateKeyFromIso(scheduledAt);
  const title = `SYNC E2E ${Date.now()}`;
  const attendanceSubject = `sync-e2e-${Date.now()}`;
  const sessionDate = new Date().toISOString().slice(0, 10);

  // 1) Baseline teacher/student panel reachability.
  const teacherMe = await api('GET', '/teachers/me', teacherToken);
  assert(teacherMe.status === 200, `Teacher panel /me failed: ${teacherMe.status}`);

  const studentMe = await api('GET', '/students/me', studentToken);
  assert(studentMe.status === 200, `Student panel /me failed: ${studentMe.status}`);

  // 2) Batch membership visible in both panels.
  const teacherBatches = await api('GET', '/teachers/me/batches', teacherToken);
  assert(teacherBatches.status === 200, `Teacher batches failed: ${teacherBatches.status}`);
  assert(
    Array.isArray(teacherBatches.data) && teacherBatches.data.some((b) => b.id === batch.id),
    'Teacher panel does not show target batch',
  );

  const studentBatches = await api('GET', '/students/me/batches', studentToken);
  assert(studentBatches.status === 200, `Student batches failed: ${studentBatches.status}`);
  assert(
    Array.isArray(studentBatches.data) && studentBatches.data.some((sb) => sb.id === batch.id || sb.batch?.id === batch.id),
    'Student panel does not show target batch membership',
  );

  // 3) Teacher creates timetable entry.
  const createSchedule = await api('POST', '/timetable/teacher/me', teacherToken, {
    batch_id: batch.id,
    title,
    scheduled_at: scheduledAt,
    duration_minutes: 60,
  });
  assert([200, 201].includes(createSchedule.status), `Create schedule failed: ${createSchedule.status}`);
  assert(createSchedule.data && createSchedule.data.id, 'Schedule create returned no lecture id');
  const lectureId = createSchedule.data.id;

  // 4) Teacher sees lecture in own schedule.
  const teacherSchedule = await api('GET', '/timetable/teacher/me', teacherToken);
  assert(teacherSchedule.status === 200, `Teacher schedule read failed: ${teacherSchedule.status}`);
  assert(
    Array.isArray(teacherSchedule.data) && teacherSchedule.data.some((l) => l.id === lectureId),
    'Teacher schedule missing created lecture',
  );

  // 5) Student sees same lecture via student panel schedule.
  const studentSchedule = await api('GET', `/students/me/schedule/today?date=${scheduleDateKey}`, studentToken);
  assert(studentSchedule.status === 200, `Student schedule read failed: ${studentSchedule.status}`);
  assert(
    Array.isArray(studentSchedule.data) && studentSchedule.data.some((l) => l.id === lectureId),
    'Student schedule missing teacher-created lecture (sync failure)',
  );

  // 6) Student sees same lecture via batch timetable endpoint.
  const batchTimetableAsStudent = await api('GET', `/timetable/batch/${batch.id}`, studentToken);
  assert(batchTimetableAsStudent.status === 200, `Student batch timetable failed: ${batchTimetableAsStudent.status}`);
  assert(
    Array.isArray(batchTimetableAsStudent.data) && batchTimetableAsStudent.data.some((l) => l.id === lectureId),
    'Batch timetable missing created lecture for student',
  );

  // 7) Teacher marks attendance for the same batch/student.
  const markAttendance = await api('POST', '/attendance/mark', teacherToken, {
    batch_id: batch.id,
    session_date: sessionDate,
    subject: attendanceSubject,
    notify_parents: false,
    records: [
      {
        student_id: student.id,
        status: 'present',
        note: 'panel sync e2e',
      },
    ],
  });
  assert(markAttendance.status === 200, `Attendance mark failed: ${markAttendance.status}`);

  // 8) Teacher view of student attendance includes the new session.
  const teacherStudentAttendance = await api(
    'GET',
    `/attendance/student/${student.id}?batchId=${batch.id}&subject=${attendanceSubject}`,
    teacherToken,
  );
  assert(
    teacherStudentAttendance.status === 200,
    `Teacher student-attendance report failed: ${teacherStudentAttendance.status}`,
  );
  assert(
    (teacherStudentAttendance.data?.total_sessions || 0) >= 1,
    'Teacher attendance report did not include newly marked session',
  );

  // 9) Student panel attendance endpoint reflects teacher-marked record.
  const studentAttendance = await api(
    'GET',
    `/students/me/attendance?batchId=${batch.id}&subject=${attendanceSubject}`,
    studentToken,
  );
  assert(studentAttendance.status === 200, `Student attendance read failed: ${studentAttendance.status}`);
  assert(
    (studentAttendance.data?.summary?.total || 0) >= 1,
    'Student attendance panel did not reflect teacher-marked session (sync failure)',
  );

  // 10) Batch-level attendance aggregation endpoint responds for same subject/month.
  const today = new Date();
  const month = today.getMonth() + 1;
  const year = today.getFullYear();
  const batchAttendance = await api(
    'GET',
    `/attendance/batch/${batch.id}?month=${month}&year=${year}&subject=${attendanceSubject}`,
    teacherToken,
  );
  assert(batchAttendance.status === 200, `Batch attendance view failed: ${batchAttendance.status}`);

  // Cleanup lecture so repeated runs stay clean.
  const cleanup = await api('DELETE', `/timetable/teacher/me/${lectureId}`, teacherToken);
  assert(cleanup.status === 200, `Cleanup lecture failed: ${cleanup.status}`);

  console.log('PASS: Authenticated teacher/student/batch sync checks succeeded.');
  console.log('PASS: Timetable + attendance propagation verified across both panels and batch APIs.');
  console.log('PASS: Core interconnection check is green for local production-readiness gating.');
  await prisma.$disconnect();
}

run().catch(async (error) => {
  console.error('FAIL:', error.message || error);
  await prisma.$disconnect();
  process.exit(1);
});

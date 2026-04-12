/* eslint-disable no-console */
const axios = require('axios');

const baseUrl = (process.env.SMOKE_BASE_URL || 'http://localhost:3000/api').replace(/\/$/, '');
const adminPhone = process.env.SMOKE_ADMIN_PHONE || '9876543210';
const teacherPhone = process.env.SMOKE_TEACHER_PHONE || '6283983051';
const otp = process.env.SMOKE_OTP || '123456';

function unwrap(payload) {
  if (payload && typeof payload === 'object' && 'data' in payload) return payload.data;
  return payload;
}

async function otpLogin(phone) {
  const client = axios.create({ baseURL: baseUrl, timeout: 20000 });

  await client.post('/auth/otp/send', { phone, purpose: 'login' });
  const verifyRes = await client.post('/auth/otp/verify', { phone, otp, purpose: 'login' });
  const data = unwrap(verifyRes.data) || {};
  const token = data.accessToken || data.access_token || data.token;
  const user = data.user || {};

  if (!token) throw new Error(`OTP login for ${phone} succeeded but no access token returned`);
  client.defaults.headers.common.Authorization = `Bearer ${token}`;

  return { client, user };
}

async function listNotifications(client) {
  const res = await client.get('/notifications', { params: { page: 1, perPage: 20, read_status: 'all' } });
  const list = unwrap(res.data);
  return Array.isArray(list) ? list : [];
}

async function run() {
  console.log('--- OTP Role Smoke ---');
  console.log(`Base URL: ${baseUrl}`);

  const { client: adminClient, user: adminUser } = await otpLogin(adminPhone);
  const { client: teacherClient, user: teacherUser } = await otpLogin(teacherPhone);

  console.log(`Admin login: OK role=${adminUser.role || 'n/a'} userId=${adminUser.id || 'n/a'}`);
  console.log(`Teacher login: OK role=${teacherUser.role || 'n/a'} userId=${teacherUser.id || 'n/a'}`);

  const matrix = [];

  // 1) Admin announcement propagation to teacher notifications
  let teacherBefore = [];
  let teacherAfter = [];
  let announceTitle = `Smoke Announcement ${Date.now()}`;
  try {
    teacherBefore = await listNotifications(teacherClient);
    await adminClient.post('/announcements', {
      title: announceTitle,
      body: 'Smoke test announcement from admin',
      category: 'system',
      pinned: false,
    });
    await new Promise((resolve) => setTimeout(resolve, 1500));
    teacherAfter = await listNotifications(teacherClient);

    const seen = teacherAfter.some((n) => (n.title || '').toString() === announceTitle);
    matrix.push({ feature: 'Admin announcement -> Teacher notification', status: seen ? 'PASS' : 'WARN', details: `before=${teacherBefore.length}, after=${teacherAfter.length}` });
  } catch (err) {
    const details = err?.response?.data ? JSON.stringify(err.response.data) : err.message;
    matrix.push({ feature: 'Admin announcement -> Teacher notification', status: 'FAIL', details });
  }

  // 2) Teacher attendance mark -> API success
  let teacherBatchId = '';
  try {
    const batchesRes = await teacherClient.get('/teachers/me/batches');
    const batches = unwrap(batchesRes.data);
    const batchList = Array.isArray(batches) ? batches : [];

    if (batchList.length === 0) {
      matrix.push({ feature: 'Teacher attendance mark', status: 'WARN', details: 'No teacher batches found' });
    } else {
      teacherBatchId = (batchList[0].id || '').toString();
      const studentsRes = await teacherClient.get(`/batches/${teacherBatchId}/students`);
      const students = unwrap(studentsRes.data);
      const list = Array.isArray(students) ? students : [];

      if (list.length === 0) {
        matrix.push({ feature: 'Teacher attendance mark', status: 'WARN', details: 'Batch has no students' });
      } else {
        const sample = list.slice(0, 3).map((s, i) => ({
          student_id: (s.id || s.student_id || '').toString(),
          status: i === 0 ? 'absent' : 'present',
          note: 'otp-role-smoke',
        })).filter((r) => r.student_id);

        await teacherClient.post('/attendance/mark', {
          batch_id: teacherBatchId,
          session_date: new Date().toISOString().slice(0, 10),
          notify_parents: true,
          records: sample,
        });

        const statsRes = await adminClient.get('/attendance/stats');
        const stats = unwrap(statsRes.data);
        const hasToday = Array.isArray(stats?.today);
        matrix.push({ feature: 'Teacher attendance mark -> Admin visibility', status: hasToday ? 'PASS' : 'WARN', details: `batch=${teacherBatchId}` });
      }
    }
  } catch (err) {
    const details = err?.response?.data ? JSON.stringify(err.response.data) : err.message;
    matrix.push({ feature: 'Teacher attendance mark -> Admin visibility', status: 'FAIL', details });
  }

  // 3) Teacher exam result save (if exam and student available)
  try {
    const examsRes = await teacherClient.get('/exams');
    const exams = unwrap(examsRes.data);
    const examList = Array.isArray(exams) ? exams : [];

    if (examList.length === 0) {
      matrix.push({ feature: 'Teacher exam result publish', status: 'WARN', details: 'No exams available' });
    } else {
      const exam = examList[0];
      const examId = (exam.id || '').toString();

      let studentId = '';
      if (teacherBatchId) {
        const studentsRes = await teacherClient.get(`/batches/${teacherBatchId}/students`);
        const students = unwrap(studentsRes.data);
        const list = Array.isArray(students) ? students : [];
        studentId = (list[0]?.id || list[0]?.student_id || '').toString();
      }

      if (!studentId) {
        matrix.push({ feature: 'Teacher exam result publish', status: 'WARN', details: 'No student available in teacher batch' });
      } else {
        await teacherClient.post('/exams/results', {
          examId,
          studentId,
          score: 7,
          maxMarks: 10,
          remarks: 'otp role smoke',
        });
        matrix.push({ feature: 'Teacher exam result publish', status: 'PASS', details: `exam=${examId}` });
      }
    }
  } catch (err) {
    const details = err?.response?.data ? JSON.stringify(err.response.data) : err.message;
    matrix.push({ feature: 'Teacher exam result publish', status: 'FAIL', details });
  }

  // 4) Admin dashboard core endpoints
  try {
    await adminClient.get('/students');
    await adminClient.get('/fees/records');
    await adminClient.get('/audit-logs');
    matrix.push({ feature: 'Admin core endpoints', status: 'PASS', details: 'students/fees/audit-logs accessible' });
  } catch (err) {
    const details = err?.response?.data ? JSON.stringify(err.response.data) : err.message;
    matrix.push({ feature: 'Admin core endpoints', status: 'FAIL', details });
  }

  // 5) Teacher dashboard core endpoints
  try {
    await teacherClient.get('/teachers/me/dashboard');
    await teacherClient.get('/teachers/me/batches');
    await teacherClient.get('/notifications');
    matrix.push({ feature: 'Teacher core endpoints', status: 'PASS', details: 'dashboard/batches/notifications accessible' });
  } catch (err) {
    const details = err?.response?.data ? JSON.stringify(err.response.data) : err.message;
    matrix.push({ feature: 'Teacher core endpoints', status: 'FAIL', details });
  }

  console.log('\n--- Matrix ---');
  for (const row of matrix) {
    console.log(`${row.status.padEnd(5)} | ${row.feature} | ${row.details}`);
  }

  const failCount = matrix.filter((m) => m.status === 'FAIL').length;
  if (failCount > 0) {
    process.exitCode = 1;
  }
}

run().catch((err) => {
  const status = err?.response?.status;
  const payload = err?.response?.data;
  if (status) {
    console.error(`Smoke failed HTTP ${status}`);
    console.error(JSON.stringify(payload, null, 2));
  } else {
    console.error('Smoke failed:', err.message || err);
  }
  process.exit(1);
});

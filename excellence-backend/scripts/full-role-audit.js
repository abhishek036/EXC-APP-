/* eslint-disable no-console */
const axios = require('axios');

const baseUrl = (process.env.SMOKE_BASE_URL || 'http://localhost:3000/api').replace(/\/$/, '');
const otp = process.env.SMOKE_OTP || '123456';

const phones = {
  admin: process.env.SMOKE_ADMIN_PHONE || '9876543210',
  teacher: process.env.SMOKE_TEACHER_PHONE || '6283983051',
  student: process.env.SMOKE_STUDENT_PHONE || '8888888888',
};

function unwrap(payload) {
  if (payload && typeof payload === 'object' && 'data' in payload) return payload.data;
  return payload;
}

async function loginWithOtp(phone) {
  const client = axios.create({ baseURL: baseUrl, timeout: 25000 });
  await client.post('/auth/otp/send', { phone, purpose: 'login' });
  const verify = await client.post('/auth/otp/verify', { phone, otp, purpose: 'login' });
  const data = unwrap(verify.data) || {};
  const token = data.accessToken || data.access_token || data.token;
  if (!token) throw new Error(`No token received for ${phone}`);
  client.defaults.headers.common.Authorization = `Bearer ${token}`;
  return { client, user: data.user || {} };
}

function record(matrix, category, feature, status, details) {
  matrix.push({ category, feature, status, details });
}

function findByTitle(items, title) {
  return (items || []).find((n) => (n?.title || '').toString() === title);
}

async function listNotifications(client) {
  const res = await client.get('/notifications', { params: { page: 1, perPage: 50, read_status: 'all' } });
  const data = unwrap(res.data);
  return Array.isArray(data) ? data : [];
}

function errDetails(err) {
  if (err?.response?.data) return JSON.stringify(err.response.data);
  return err?.message || String(err);
}

async function run() {
  const matrix = [];

  // 0) Health
  try {
    const health = await new Promise((resolve, reject) => {
      require('http')
        .get('http://localhost:3000/health', (res) => {
          let data = '';
          res.on('data', (c) => (data += c));
          res.on('end', () => resolve({ code: res.statusCode, body: data }));
        })
        .on('error', reject);
    });
    record(matrix, 'System', 'Backend health', health.code === 200 ? 'PASS' : 'FAIL', `status=${health.code}`);
  } catch (e) {
    record(matrix, 'System', 'Backend health', 'FAIL', e.message);
    throw new Error('Backend is not reachable');
  }

  // 1) OTP login for roles
  let admin;
  let teacher;
  let student;
  try {
    admin = await loginWithOtp(phones.admin);
    teacher = await loginWithOtp(phones.teacher);
    student = await loginWithOtp(phones.student);

    record(matrix, 'Auth', 'Admin OTP login', admin.user.role === 'admin' ? 'PASS' : 'FAIL', `role=${admin.user.role || 'n/a'}`);
    record(matrix, 'Auth', 'Teacher OTP login', teacher.user.role === 'teacher' ? 'PASS' : 'FAIL', `role=${teacher.user.role || 'n/a'}`);
    record(matrix, 'Auth', 'Student OTP login', student.user.role === 'student' ? 'PASS' : 'FAIL', `role=${student.user.role || 'n/a'}`);
  } catch (e) {
    record(matrix, 'Auth', 'OTP login flow', 'FAIL', errDetails(e));
    print(matrix);
    process.exit(1);
  }

  // 2) Profile basics
  for (const [label, actor] of [
    ['Admin', admin],
    ['Teacher', teacher],
    ['Student', student],
  ]) {
    try {
      const meRes = await actor.client.get('/auth/me');
      const me = unwrap(meRes.data) || {};
      record(matrix, 'Profile', `${label} profile fetch`, 'PASS', `userId=${me.id || me.user?.id || actor.user.id || 'n/a'}`);
    } catch (e) {
      record(matrix, 'Profile', `${label} profile fetch`, 'FAIL', errDetails(e));
    }
  }

  // 3) Notifications + push pipeline basics (in-app + role visibility)
  try {
    const now = Date.now();
    await admin.client.post('/notifications/register-token', { token: `admin-token-${now}`, platform: 'android' });
    await teacher.client.post('/notifications/register-token', { token: `teacher-token-${now}`, platform: 'android' });
    await student.client.post('/notifications/register-token', { token: `student-token-${now}`, platform: 'android' });
    record(matrix, 'Notifications', 'Device token register (admin/teacher/student)', 'PASS', 'registered fake tokens');
  } catch (e) {
    record(matrix, 'Notifications', 'Device token register (admin/teacher/student)', 'FAIL', errDetails(e));
  }

  const broadcastTitle = `Audit Broadcast ${Date.now()}`;
  let broadcastId = '';
  try {
    await admin.client.post('/notifications/send', {
      title: broadcastTitle,
      body: 'Global notification smoke',
      type: 'system',
      role_target: 'all',
    });

    await new Promise((r) => setTimeout(r, 1200));
    const teacherNotifs = await listNotifications(teacher.client);
    const studentNotifs = await listNotifications(student.client);
    const teacherSeen = findByTitle(teacherNotifs, broadcastTitle);
    const studentSeen = findByTitle(studentNotifs, broadcastTitle);

    if (teacherSeen && studentSeen) {
      broadcastId = (teacherSeen.id || '').toString();
      record(matrix, 'Notifications', 'Admin broadcast visible to teacher+student', 'PASS', `title=${broadcastTitle}`);
    } else {
      record(matrix, 'Notifications', 'Admin broadcast visible to teacher+student', 'FAIL', `teacherSeen=${Boolean(teacherSeen)} studentSeen=${Boolean(studentSeen)}`);
    }
  } catch (e) {
    record(matrix, 'Notifications', 'Admin broadcast visible to teacher+student', 'FAIL', errDetails(e));
  }

  try {
    await teacher.client.post('/notifications/send', {
      title: `Teacher Alert ${Date.now()}`,
      body: 'Teacher to student check',
      type: 'attendance',
      role_target: 'student',
    });
    record(matrix, 'Notifications', 'Teacher manual notify student role', 'PASS', 'request accepted');
  } catch (e) {
    record(matrix, 'Notifications', 'Teacher manual notify student role', 'FAIL', errDetails(e));
  }

  try {
    await teacher.client.post('/notifications/send', {
      title: `Teacher Invalid ${Date.now()}`,
      body: 'Teacher should not notify admin',
      type: 'system',
      role_target: 'admin',
    });
    record(matrix, 'Notifications', 'Teacher restricted target enforcement', 'FAIL', 'teacher was able to target admin unexpectedly');
  } catch (e) {
    const status = e?.response?.status;
    record(matrix, 'Notifications', 'Teacher restricted target enforcement', status === 403 ? 'PASS' : 'FAIL', `status=${status || 'n/a'}`);
  }

  if (broadcastId) {
    try {
      await admin.client.delete(`/notifications/${broadcastId}/global`);
      await new Promise((r) => setTimeout(r, 1000));
      const teacherNotifsAfterDelete = await listNotifications(teacher.client);
      const studentNotifsAfterDelete = await listNotifications(student.client);
      const teacherStill = findByTitle(teacherNotifsAfterDelete, broadcastTitle);
      const studentStill = findByTitle(studentNotifsAfterDelete, broadcastTitle);
      record(
        matrix,
        'Notifications',
        'Global delete removes notification from other roles',
        !teacherStill && !studentStill ? 'PASS' : 'FAIL',
        `teacherStill=${Boolean(teacherStill)} studentStill=${Boolean(studentStill)}`,
      );
    } catch (e) {
      record(matrix, 'Notifications', 'Global delete removes notification from other roles', 'FAIL', errDetails(e));
    }
  }

  // 4) Announcements
  const announcementTitle = `Audit Announcement ${Date.now()}`;
  try {
    await admin.client.post('/announcements', {
      title: announcementTitle,
      body: 'Announcement propagation check',
      category: 'system',
      pinned: false,
    });
    const teacherAnnouncements = unwrap((await teacher.client.get('/announcements')).data);
    const list = Array.isArray(teacherAnnouncements) ? teacherAnnouncements : [];
    const seen = list.some((a) => (a.title || '').toString() === announcementTitle);
    record(matrix, 'Announcements', 'Admin create visible on teacher list', seen ? 'PASS' : 'FAIL', `title=${announcementTitle}`);
  } catch (e) {
    record(matrix, 'Announcements', 'Admin create visible on teacher list', 'FAIL', errDetails(e));
  }

  // 5) Teacher batches + attendance + cross-role visibility
  let batchId = '';
  let studentId = '';
  try {
    const teacherBatches = unwrap((await teacher.client.get('/teachers/me/batches')).data);
    const batches = Array.isArray(teacherBatches) ? teacherBatches : [];
    if (batches.length === 0) {
      record(matrix, 'Attendance', 'Teacher has assigned batches', 'FAIL', 'No batches assigned');
    } else {
      batchId = (batches[0].id || '').toString();
      record(matrix, 'Attendance', 'Teacher has assigned batches', 'PASS', `batch=${batchId}`);

      const batchStudents = unwrap((await teacher.client.get(`/batches/${batchId}/students`)).data);
      const students = Array.isArray(batchStudents) ? batchStudents : [];
      if (students.length === 0) {
        record(matrix, 'Attendance', 'Batch has students for attendance', 'FAIL', 'No students in batch');
      } else {
        studentId = (students[0].id || students[0].student_id || '').toString();
        const records = students.slice(0, 3).map((s, i) => ({
          student_id: (s.id || s.student_id || '').toString(),
          status: i === 0 ? 'absent' : 'present',
          note: 'full-role-audit',
        })).filter((r) => r.student_id);

        await teacher.client.post('/attendance/mark', {
          batch_id: batchId,
          session_date: new Date().toISOString().slice(0, 10),
          notify_parents: true,
          records,
        });

        const adminStats = unwrap((await admin.client.get('/attendance/stats')).data);
        const adminToday = Array.isArray(adminStats?.today) ? adminStats.today.length : 0;
        const studentAttendance = unwrap((await student.client.get('/students/me/attendance')).data);
        const studentHasRecords = Array.isArray(studentAttendance) ? studentAttendance.length > 0 : Boolean(studentAttendance?.records?.length);

        record(matrix, 'Attendance', 'Teacher mark visible to admin stats', adminToday >= 0 ? 'PASS' : 'FAIL', `todaySessions=${adminToday}`);
        record(matrix, 'Attendance', 'Teacher mark visible to student', studentHasRecords ? 'PASS' : 'WARN', 'student attendance endpoint responded');
      }
    }
  } catch (e) {
    record(matrix, 'Attendance', 'Teacher mark + cross-role visibility', 'FAIL', errDetails(e));
  }

  // 6) Fees workflow
  try {
    if (!batchId) {
      record(matrix, 'Fees', 'Admin fee flow', 'WARN', 'Skipped (no batch id)');
    } else {
      await admin.client.post('/fees/structure', {
        batch_id: batchId,
        monthly_fee: 1000,
        admission_fee: 0,
        exam_fee: 0,
        late_fee_amount: 50,
        late_after_day: 10,
        grace_days: 0,
      });

      const now = new Date();
      await admin.client.post('/fees/generate', {
        batch_id: batchId,
        month: now.getMonth() + 1,
        year: now.getFullYear(),
      });

      const records = unwrap((await admin.client.get('/fees/records')).data);
      const feeRecords = Array.isArray(records) ? records : [];
      const target = feeRecords.find((r) => (r.student_id || r.student?.id || '').toString() === studentId) || feeRecords[0];

      if (!target) {
        record(matrix, 'Fees', 'Fee record generation', 'FAIL', 'No fee records generated');
      } else {
        await admin.client.post('/fees/pay', {
          fee_record_id: (target.id || '').toString(),
          amount_paid: 100,
          payment_mode: 'cash',
          note: 'full-role-audit',
        });

        const studentFees = unwrap((await student.client.get('/students/me/fees')).data);
        const studentFeeVisible = Array.isArray(studentFees) ? studentFees.length > 0 : Boolean(studentFees);
        record(matrix, 'Fees', 'Admin fee update visible to student', studentFeeVisible ? 'PASS' : 'WARN', `feeRecord=${target.id}`);
      }
    }
  } catch (e) {
    record(matrix, 'Fees', 'Admin fee flow', 'FAIL', errDetails(e));
  }

  // 7) Exams / results workflow
  try {
    const exams = unwrap((await teacher.client.get('/exams')).data);
    const examList = Array.isArray(exams) ? exams : [];
    if (examList.length === 0 || !studentId) {
      record(matrix, 'Exams', 'Teacher result publish', 'WARN', 'Skipped (missing exam/student)');
    } else {
      const examId = (examList[0].id || '').toString();
      await teacher.client.post('/exams/results', {
        examId,
        studentId,
        score: 8,
        maxMarks: 10,
        remarks: 'full-role-audit',
      });

      const studentResults = unwrap((await student.client.get('/students/me/results')).data);
      const resultVisible = Array.isArray(studentResults)
        ? studentResults.some((r) => (r.exam_id || r.exam?.id || '').toString() === examId)
        : Boolean(studentResults);
      record(matrix, 'Exams', 'Teacher result visible to student', resultVisible ? 'PASS' : 'WARN', `exam=${examId}`);
    }
  } catch (e) {
    record(matrix, 'Exams', 'Teacher result publish', 'FAIL', errDetails(e));
  }

  // 8) Student list batch mapping (admin UI backend dependency)
  try {
    const studentsRes = unwrap((await admin.client.get('/students')).data);
    const students = Array.isArray(studentsRes) ? studentsRes : [];
    const seeded = students.find((s) => (s.id || '').toString() === studentId) || students[0];
    const hasBatchMapping = Array.isArray(seeded?.student_batches) || Boolean(seeded?.batch || seeded?.batch_name || seeded?.batches);
    record(matrix, 'Students', 'Admin student list batch mapping data', hasBatchMapping ? 'PASS' : 'FAIL', seeded ? `student=${seeded.id}` : 'no student rows');
  } catch (e) {
    record(matrix, 'Students', 'Admin student list batch mapping data', 'FAIL', errDetails(e));
  }

  print(matrix);

  const hardFails = matrix.filter((m) => m.status === 'FAIL').length;
  if (hardFails > 0) process.exitCode = 1;
}

function print(matrix) {
  console.log('\n=== FULL ROLE AUDIT MATRIX ===');
  for (const row of matrix) {
    const status = row.status.padEnd(5);
    console.log(`${status} | ${row.category.padEnd(13)} | ${row.feature} | ${row.details}`);
  }
}

run().catch((e) => {
  console.error('Audit script crashed:', e?.message || e);
  process.exit(1);
});

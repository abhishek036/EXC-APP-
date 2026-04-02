/* eslint-disable no-console */
const axios = require('axios');

const baseUrl = (process.env.SMOKE_BASE_URL || 'http://127.0.0.1:3000/api').replace(/\/$/, '');
const otp = process.env.SMOKE_OTP;
const adminPhone = process.env.SMOKE_ADMIN_PHONE;
const teacherPhone = process.env.SMOKE_TEACHER_PHONE;
const studentPhone = process.env.SMOKE_STUDENT_PHONE;

function unwrap(payload) {
  if (payload && typeof payload === 'object' && 'data' in payload) return payload.data;
  return payload;
}

async function otpLogin(phone) {
  const client = axios.create({ baseURL: baseUrl, timeout: 20000 });
  await client.post('/auth/otp/send', { phone, purpose: 'login' });
  const verifyRes = await client.post('/auth/otp/verify', { phone, otp, purpose: 'login' });
  const body = unwrap(verifyRes.data) || {};
  const token = body.accessToken || body.access_token || body.token;
  const user = body.user || {};
  if (!token) throw new Error(`OTP login missing token for ${phone}`);
  client.defaults.headers.common.Authorization = `Bearer ${token}`;
  return { client, user };
}

async function safeGet(label, fn, acceptedStatus = [200]) {
  try {
    const res = await fn();
    if (!acceptedStatus.includes(res.status)) {
      return { label, status: 'FAIL', detail: `status=${res.status}` };
    }
    return { label, status: 'PASS', detail: `status=${res.status}` };
  } catch (e) {
    const s = e?.response?.status;
    const d = s ? `status=${s}` : (e.message || 'unknown error');
    return { label, status: 'FAIL', detail: d };
  }
}

async function run() {
  console.log('--- Auth Panel Regression ---');
  console.log(`Base URL: ${baseUrl}`);

  if (!otp || !adminPhone || !teacherPhone || !studentPhone) {
    console.log('SKIP: Set SMOKE_OTP, SMOKE_ADMIN_PHONE, SMOKE_TEACHER_PHONE, SMOKE_STUDENT_PHONE for full real-auth run.');
    process.exit(0);
  }

  const admin = await otpLogin(adminPhone);
  const teacher = await otpLogin(teacherPhone);
  const student = await otpLogin(studentPhone);

  console.log(`Admin login role=${admin.user.role || 'n/a'}`);
  console.log(`Teacher login role=${teacher.user.role || 'n/a'}`);
  console.log(`Student login role=${student.user.role || 'n/a'}`);

  const checks = [];

  checks.push(await safeGet('Teacher dashboard allowed', () => teacher.client.get('/teachers/me/dashboard')));
  checks.push(await safeGet('Teacher batches allowed', () => teacher.client.get('/teachers/me/batches')));
  checks.push(await safeGet('Student dashboard allowed', () => student.client.get('/students/me/dashboard')));
  checks.push(await safeGet('Student batches allowed', () => student.client.get('/students/me/batches')));

  checks.push(await safeGet('Teacher blocked from student self dashboard', () => teacher.client.get('/students/me/dashboard'), [403]));
  checks.push(await safeGet('Student blocked from teacher self dashboard', () => student.client.get('/teachers/me/dashboard'), [403]));

  checks.push(await safeGet('Admin can list students', () => admin.client.get('/students')));

  console.log('\n--- Regression Matrix ---');
  checks.forEach((c) => console.log(`${c.status.padEnd(5)} | ${c.label} | ${c.detail}`));

  const fails = checks.filter((c) => c.status === 'FAIL').length;
  if (fails > 0) process.exit(1);
}

run().catch((e) => {
  const status = e?.response?.status;
  if (status) {
    console.error(`FAIL HTTP ${status}`);
    console.error(JSON.stringify(e.response.data, null, 2));
  } else {
    console.error('FAIL', e.message || e);
  }
  process.exit(1);
});

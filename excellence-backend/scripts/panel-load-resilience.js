/* eslint-disable no-console */
const jwt = require('jsonwebtoken');
const { PrismaClient } = require('@prisma/client');

const prisma = new PrismaClient();
const baseUrl = (process.env.SMOKE_BASE_URL || 'http://127.0.0.1:3000/api').replace(/\/$/, '');

function assert(condition, message) {
  if (!condition) throw new Error(message);
}

function tokenFor(user, instituteId) {
  const secret = process.env.JWT_SECRET;
  assert(secret && secret.length >= 16, 'JWT_SECRET missing or invalid');
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

async function call(path, token) {
  const start = Date.now();
  try {
    const res = await fetch(`${baseUrl}${path}`, {
      headers: {
        Accept: 'application/json',
        Authorization: `Bearer ${token}`,
      },
    });
    return { ok: true, status: res.status, ms: Date.now() - start };
  } catch (e) {
    return { ok: false, status: 0, ms: Date.now() - start, error: e.message || String(e) };
  }
}

function percentile(values, p) {
  if (values.length === 0) return 0;
  const sorted = [...values].sort((a, b) => a - b);
  const idx = Math.min(sorted.length - 1, Math.floor((p / 100) * sorted.length));
  return sorted[idx];
}

async function runConcurrent(label, path, token, count = 30) {
  const tasks = Array.from({ length: count }, () => call(path, token));
  const results = await Promise.all(tasks);
  const status5xx = results.filter((r) => r.status >= 500).length;
  const transportFail = results.filter((r) => !r.ok).length;
  const timings = results.map((r) => r.ms);

  return {
    label,
    path,
    count,
    status5xx,
    transportFail,
    p95: percentile(timings, 95),
    max: Math.max(...timings),
  };
}

async function run() {
  console.log('--- Panel Load & Resilience ---');
  console.log(`Base URL: ${baseUrl}`);

  const teacher = await prisma.teacher.findFirst({
    where: { is_active: true, user: { is_active: true, role: 'teacher' } },
    include: { user: true },
  });
  const student = await prisma.student.findFirst({
    where: { institute_id: teacher?.institute_id, is_active: true, user: { is_active: true, role: 'student' } },
    include: { user: true },
  });

  assert(teacher, 'No teacher found');
  assert(student, 'No student found for teacher institute');

  const teacherToken = tokenFor(teacher.user, teacher.institute_id);
  const studentToken = tokenFor(student.user, student.institute_id);

  const checks = [];
  checks.push(await runConcurrent('Teacher dashboard load', '/teachers/me/dashboard', teacherToken));
  checks.push(await runConcurrent('Teacher batches load', '/teachers/me/batches', teacherToken));
  checks.push(await runConcurrent('Student dashboard load', '/students/me/dashboard', studentToken));
  checks.push(await runConcurrent('Student schedule load', '/students/me/schedule/today', studentToken));

  console.log('\n--- Resilience Matrix ---');
  checks.forEach((c) => {
    console.log(
      `${c.label} | req=${c.count} | 5xx=${c.status5xx} | netFail=${c.transportFail} | p95=${c.p95}ms | max=${c.max}ms`,
    );
  });

  const anyHardFail = checks.some((c) => c.status5xx > 0 || c.transportFail > 0);
  await prisma.$disconnect();
  if (anyHardFail) process.exit(1);
}

run().catch(async (e) => {
  console.error('FAIL', e.message || e);
  try {
    await prisma.$disconnect();
  } catch {}
  process.exit(1);
});

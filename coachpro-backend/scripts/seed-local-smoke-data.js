const { PrismaClient } = require('@prisma/client');

const prisma = new PrismaClient();

const INSTITUTE_ID = '00000000-0000-0000-0000-000000000001';
const BATCH_ID = '00000000-0000-0000-0000-000000000101';
const STUDENT_ID = '00000000-0000-0000-0000-000000001001';
const EXAM_ID = '00000000-0000-0000-0000-000000009001';
const TEACHER_PHONE = process.env.SMOKE_TEACHER_PHONE || '6283983051';

async function run() {
  const institute = await prisma.institute.upsert({
    where: { id: INSTITUTE_ID },
    update: {},
    create: {
      id: INSTITUTE_ID,
      name: 'Elite Coaching Academy',
      slug: 'elite-academy',
      primary_color: '#3F72AF',
    },
  });

  const adminUser = await prisma.user.upsert({
    where: {
      institute_id_phone: {
        institute_id: institute.id,
        phone: '9876543210',
      },
    },
    update: { role: 'admin', status: 'ACTIVE' },
    create: {
      institute_id: institute.id,
      phone: '9876543210',
      role: 'admin',
      status: 'ACTIVE',
    },
  });

  const teacherUser = await prisma.user.upsert({
    where: {
      institute_id_phone: {
        institute_id: institute.id,
        phone: TEACHER_PHONE,
      },
    },
    update: { role: 'teacher', status: 'ACTIVE' },
    create: {
      institute_id: institute.id,
      phone: TEACHER_PHONE,
      role: 'teacher',
      status: 'ACTIVE',
    },
  });

  const teacher = await prisma.teacher.upsert({
    where: { id: '00000000-0000-0000-0000-000000002001' },
    update: {
      user_id: teacherUser.id,
      institute_id: institute.id,
      phone: TEACHER_PHONE,
      is_active: true,
    },
    create: {
      id: '00000000-0000-0000-0000-000000002001',
      user_id: teacherUser.id,
      institute_id: institute.id,
      name: 'Smoke Teacher',
      phone: TEACHER_PHONE,
      subjects: ['General'],
      is_active: true,
    },
  });

  const studentUser = await prisma.user.upsert({
    where: {
      institute_id_phone: {
        institute_id: institute.id,
        phone: '8888888888',
      },
    },
    update: { role: 'student', status: 'ACTIVE' },
    create: {
      institute_id: institute.id,
      phone: '8888888888',
      role: 'student',
      status: 'ACTIVE',
    },
  });

  const student = await prisma.student.upsert({
    where: { id: STUDENT_ID },
    update: {
      user_id: studentUser.id,
      institute_id: institute.id,
      phone: '8888888888',
      is_active: true,
    },
    create: {
      id: STUDENT_ID,
      user_id: studentUser.id,
      institute_id: institute.id,
      name: 'Demo Student',
      phone: '8888888888',
      is_active: true,
    },
  });

  const batch = await prisma.batch.upsert({
    where: { id: BATCH_ID },
    update: {
      institute_id: institute.id,
      teacher_id: teacher.id,
      name: 'Foundation batch 2026',
      is_active: true,
      days_of_week: [1, 3, 5],
    },
    create: {
      id: BATCH_ID,
      institute_id: institute.id,
      teacher_id: teacher.id,
      name: 'Foundation batch 2026',
      subject: 'General',
      days_of_week: [1, 3, 5],
      is_active: true,
    },
  });

  await prisma.studentBatch.upsert({
    where: { student_id_batch_id: { student_id: student.id, batch_id: batch.id } },
    update: { is_active: true, left_date: null },
    create: {
      student_id: student.id,
      batch_id: batch.id,
      institute_id: institute.id,
      is_active: true,
    },
  });

  const exam = await prisma.exam.upsert({
    where: { id: EXAM_ID },
    update: {
      institute_id: institute.id,
      created_by_id: adminUser.id,
      title: 'Smoke Test Exam',
      exam_date: new Date(),
      total_marks: 10,
    },
    create: {
      id: EXAM_ID,
      institute_id: institute.id,
      created_by_id: adminUser.id,
      title: 'Smoke Test Exam',
      exam_date: new Date(),
      total_marks: 10,
    },
  });

  await prisma.examBatch.upsert({
    where: { exam_id_batch_id: { exam_id: exam.id, batch_id: batch.id } },
    update: {},
    create: {
      exam_id: exam.id,
      batch_id: batch.id,
    },
  });

  console.log('Local smoke data ready');
  console.log('Admin phone:', adminUser.phone);
  console.log('Teacher phone:', teacherUser.phone);
  console.log('Student phone:', studentUser.phone);
}

run()
  .catch((e) => {
    console.error(e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });

const { PrismaClient } = require('@prisma/client');

const prisma = new PrismaClient();
const phone = process.env.SMOKE_TEACHER_PHONE || '6283983051';

async function run() {
  const variants = [phone, phone.startsWith('+91') ? phone.slice(3) : `+91${phone}`];

  const user = await prisma.user.findFirst({
    where: { phone: { in: variants } },
    orderBy: { created_at: 'desc' },
  });

  if (!user) {
    throw new Error(`No user found for phone ${phone}`);
  }

  await prisma.user.update({
    where: { id: user.id },
    data: { role: 'teacher', status: 'ACTIVE' },
  });

  const existingTeacher = await prisma.teacher.findFirst({ where: { user_id: user.id } });

  if (!existingTeacher) {
    await prisma.teacher.create({
      data: {
        user_id: user.id,
        institute_id: user.institute_id,
        name: 'Smoke Teacher',
        phone: user.phone,
        subjects: ['General'],
        is_active: true,
      },
    });
  }

  console.log('Teacher mapping ready for user', user.id, 'phone', user.phone);
}

run()
  .catch((e) => {
    console.error(e.message || e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });

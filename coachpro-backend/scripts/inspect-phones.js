const { PrismaClient } = require('@prisma/client');

const prisma = new PrismaClient();

async function run() {
  const phones = ['9876543210', '6283983051', '+919876543210', '+916283983051'];

  const users = await prisma.user.findMany({
    where: { phone: { in: phones } },
    select: { id: true, phone: true, role: true, institute_id: true, status: true },
  });

  const teachers = await prisma.teacher.findMany({
    where: { phone: { in: phones } },
    select: { id: true, phone: true, user_id: true, institute_id: true, name: true },
  });

  const students = await prisma.student.findMany({
    where: { phone: { in: phones } },
    select: { id: true, phone: true, user_id: true, institute_id: true, name: true },
  });

  console.log('USERS', users);
  console.log('TEACHERS', teachers);
  console.log('STUDENTS', students);
}

run()
  .catch((e) => {
    console.error(e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });

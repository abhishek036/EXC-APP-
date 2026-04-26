import { PrismaClient } from '@prisma/client';
import bcrypt from 'bcryptjs';

const prisma = new PrismaClient();

async function main() {
  const salt = await bcrypt.genSalt(10);
  const passwordHash = await bcrypt.hash('password123', salt);

  // 1. Create Institute
  const institute = await prisma.institute.upsert({
    where: { slug: 'elite-academy' },
    update: {},
    create: {
      id: '00000000-0000-0000-0000-000000000001',
      name: 'Elite Coaching Academy',
      slug: 'elite-academy',
      primary_color: '#3F72AF',
    },
  });

  const testUsers = [
    { phone: '1111111110', role: 'admin', name: 'Abhishek Sharma' },
    { phone: '1111111111', role: 'student', name: 'Rahul Kumar' },
    { phone: '1111111112', role: 'teacher', name: 'Amit Patel' },
    { phone: '1111111113', role: 'parent', name: 'Sanjay Singh' },
  ];

  for (const tu of testUsers) {
    const user = await prisma.user.upsert({
      where: { institute_id_phone: { institute_id: institute.id, phone: tu.phone } },
      update: { password_hash: passwordHash, status: 'ACTIVE', role: tu.role as any },
      create: {
        institute_id: institute.id,
        phone: tu.phone,
        role: tu.role as any,
        status: 'ACTIVE',
        password_hash: passwordHash,
      },
    });

    if (tu.role === 'student') {
      await prisma.student.upsert({
        where: { id: `10000000-0000-0000-0000-${tu.phone.padStart(12, '0')}` },
        update: { user_id: user.id },
        create: { id: `10000000-0000-0000-0000-${tu.phone.padStart(12, '0')}`, user_id: user.id, institute_id: institute.id, name: tu.name, phone: tu.phone },
      });
    } else if (tu.role === 'teacher') {
      await prisma.teacher.upsert({
        where: { id: `20000000-0000-0000-0000-${tu.phone.padStart(12, '0')}` },
        update: { user_id: user.id, is_active: true },
        create: { id: `20000000-0000-0000-0000-${tu.phone.padStart(12, '0')}`, user_id: user.id, institute_id: institute.id, name: tu.name, phone: tu.phone, is_active: true },
      });
    } else if (tu.role === 'parent') {
      await prisma.parent.upsert({
        where: { id: `30000000-0000-0000-0000-${tu.phone.padStart(12, '0')}` },
        update: { user_id: user.id },
        create: { id: `30000000-0000-0000-0000-${tu.phone.padStart(12, '0')}`, user_id: user.id, institute_id: institute.id, name: tu.name, phone: tu.phone },
      });
    } else if (tu.role === 'admin') {
      await prisma.staff.upsert({
        where: { id: `40000000-0000-0000-0000-${tu.phone.padStart(12, '0')}` },
        update: {},
        create: { id: `40000000-0000-0000-0000-${tu.phone.padStart(12, '0')}`, institute_id: institute.id, name: tu.name, phone: tu.phone },
      });
    }
  }

  // Also create a test batch
  await prisma.batch.upsert({
    where: { id: '00000000-0000-0000-0000-000000000101' },
    update: {},
    create: {
        id: '00000000-0000-0000-0000-000000000101',
        institute_id: institute.id,
        name: 'Foundation batch 2026',
    }
  });

  console.log('Seed successful:');
  console.log('Play Store Test accounts created:');
  console.log('Admin login: 1111111110 / password123 / OTP 123456');
  console.log('Student login: 1111111111 / password123 / OTP 123456');
  console.log('Teacher login: 1111111112 / password123 / OTP 123456');
  console.log('Parent login: 1111111113 / password123 / OTP 123456');
}

main()
  .catch((e) => {
    console.error(e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });

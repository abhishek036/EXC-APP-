import { PrismaClient } from '@prisma/client';
import bcrypt from 'bcryptjs';

const prisma = new PrismaClient();

async function main() {
  console.log('🌱 Seeding database...');

  // 1. Create Institute
  const institute = await prisma.institute.upsert({
    where: { slug: 'coachpro-demo' },
    update: {},
    create: {
      name: 'CoachPro Academy',
      slug: 'coachpro-demo',
      phone: '+919876543210',
      email: 'demo@coachpro.com',
    },
  });

  const passwordHash = await bcrypt.hash('123456', 10);

  // 2. Create Admin
  await prisma.user.upsert({
    where: { institute_id_phone: { institute_id: institute.id, phone: '+919876543210' } },
    update: { status: 'ACTIVE' },
    create: {
      phone: '+919876543210',
      role: 'admin',
      status: 'ACTIVE',
      password_hash: passwordHash,
      institute_id: institute.id,
    },
  });

  // 3. Create Teacher User
  const teacherUser = await prisma.user.upsert({
    where: { institute_id_phone: { institute_id: institute.id, phone: '+919876543211' } },
    update: { status: 'ACTIVE' },
    create: {
      phone: '+919876543211',
      role: 'teacher',
      status: 'ACTIVE',
      password_hash: passwordHash,
      institute_id: institute.id,
    },
  });

  // Create Teacher Profile
  await prisma.teacher.upsert({
    where: { id: '00000000-0000-0000-0000-000000000001' },
    update: {},
    create: {
      id: '00000000-0000-0000-0000-000000000001',
      user_id: teacherUser.id,
      institute_id: institute.id,
      name: 'Demo Teacher',
      phone: '+919876543211',
    },
  });

  // 4. Create Student User
  const studentUser = await prisma.user.upsert({
    where: { institute_id_phone: { institute_id: institute.id, phone: '+919876543212' } },
    update: { status: 'ACTIVE' },
    create: {
      phone: '+919876543212',
      role: 'student',
      status: 'ACTIVE',
      password_hash: passwordHash,
      institute_id: institute.id,
    },
  });

  // Create Student Profile
  await prisma.student.upsert({
    where: { id: '00000000-0000-0000-0000-000000000002' },
    update: {},
    create: {
      id: '00000000-0000-0000-0000-000000000002',
      user_id: studentUser.id,
      institute_id: institute.id,
      name: 'Demo Student',
      phone: '+919876543212',
    },
  });

  console.log('✅ Seed complete with +91 prefix!');
}

main()
  .catch((e) => {
    console.error('Seeding failed:', e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });

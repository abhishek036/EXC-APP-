import { PrismaClient } from '@prisma/client';
import bcrypt from 'bcrypt';

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

  // 2. Create Admin User
  const adminUser = await prisma.user.upsert({
    where: { 
        institute_id_phone: {
            institute_id: institute.id,
            phone: '9876543210'
        }
    },
    update: { password_hash: passwordHash, status: 'ACTIVE' },
    create: {
      institute_id: institute.id,
      phone: '9876543210',
      role: 'admin',
      status: 'ACTIVE',
      password_hash: passwordHash,
    },
  });

  // 3. Create Student and Batch
  const batch = await prisma.batch.upsert({
      where: { id: '00000000-0000-0000-0000-000000000101' },
      update: {},
      create: {
          id: '00000000-0000-0000-0000-000000000101',
          institute_id: institute.id,
          name: 'Foundation batch 2026',
      }
  });

  const studentUser = await prisma.user.upsert({
      where: { 
        institute_id_phone: {
            institute_id: institute.id,
            phone: '8888888888'
        }
      },
      update: { password_hash: passwordHash, status: 'ACTIVE' },
      create: {
          institute_id: institute.id,
          phone: '8888888888',
          role: 'student',
          status: 'ACTIVE',
          password_hash: passwordHash,
      }
  });

  const student = await prisma.student.upsert({
      where: { id: '00000000-0000-0000-0000-000000001001' },
      update: {},
      create: {
          id: '00000000-0000-0000-0000-000000001001',
          user_id: studentUser.id,
          institute_id: institute.id,
          name: 'Demo Student',
          phone: '8888888888',
      }
  });

  console.log('Seed successful:');
  console.log('Admin login: 9876543210 / password123');
  console.log('Student login: 8888888888 / password123');
}

main()
  .catch((e) => {
    console.error(e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });

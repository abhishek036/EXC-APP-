import { PrismaClient } from '@prisma/client';
import bcrypt from 'bcryptjs';

const prisma = new PrismaClient();

async function main() {
  const phone = '8427996261';
  const password = '8427996261';
  const passwordHash = await bcrypt.hash(password, 10);

  let institute = await prisma.institute.findFirst();
  if (!institute) {
    institute = await prisma.institute.create({
      data: {
        name: 'CoachPro Institute',
        slug: `coachpro-${Date.now()}`,
        phone,
        email: 'admin@coachpro.local',
      },
    });
  }

  await prisma.$executeRawUnsafe('TRUNCATE TABLE "users" CASCADE');

  await prisma.user.create({
    data: {
      institute_id: institute.id,
      phone,
      role: 'admin',
      password_hash: passwordHash,
      is_active: true,
    },
  });

  console.log('✅ Reset complete: all users cleared and admin recreated');
  console.log('📱 Phone:', phone);
  console.log('🔐 Password:', password);
}

main().catch(e => {
  console.error(e);
  process.exit(1);
}).finally(async () => {
  await prisma.$disconnect();
});

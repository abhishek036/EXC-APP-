import { PrismaClient } from '@prisma/client';
import bcrypt from 'bcryptjs';

/**
 * Admin user creation utility.
 *
 * Usage: ADMIN_PHONE=xxx ADMIN_PASSWORD=xxx npx ts-node src/utils/createAdminUser.ts
 *
 * SECURITY: Credentials are read from environment variables only.
 * Never hardcode passwords in source code.
 */

const prisma = new PrismaClient();

async function main() {
  const phone = process.env.ADMIN_PHONE;
  const password = process.env.ADMIN_PASSWORD;

  if (!phone || !password) {
    console.error('❌ ADMIN_PHONE and ADMIN_PASSWORD environment variables are required.');
    console.error('   Usage: ADMIN_PHONE=xxx ADMIN_PASSWORD=xxx npx ts-node src/utils/createAdminUser.ts');
    process.exit(1);
  }

  if (password.length < 8) {
    console.error('❌ ADMIN_PASSWORD must be at least 8 characters.');
    process.exit(1);
  }

  const passwordHash = await bcrypt.hash(password, 12);

  let institute = await prisma.institute.findFirst();
  if (!institute) {
    institute = await prisma.institute.create({
      data: {
        name: 'Excellence Institute',
        slug: `excellence-${Date.now()}`,
        phone,
        email: 'admin@excellence.local',
      },
    });
  }

  await prisma.user.create({
    data: {
      institute_id: institute.id,
      phone,
      role: 'admin',
      password_hash: passwordHash,
      is_active: true,
    },
  });

  console.log('✅ Admin user created successfully');
  console.log(`📱 Phone: ${phone.slice(0, 2)}****${phone.slice(-2)}`);
  // Never log the password
}

main().catch(e => {
  console.error(e);
  process.exit(1);
}).finally(async () => {
  await prisma.$disconnect();
});

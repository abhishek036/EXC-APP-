/* eslint-disable no-console */
const { PrismaClient } = require('@prisma/client');

const prisma = new PrismaClient();

async function run() {
  const phone = process.argv[2] || process.env.SMOKE_PHONE || '8888888888';
  const purpose = process.argv[3] || 'login';

  const phonesToTry = Array.from(new Set([
    phone,
    phone.startsWith('+91') ? phone.substring(3) : phone,
    phone.startsWith('+') ? phone : `+91${phone}`,
  ]));

  const row = await prisma.otpCode.findFirst({
    where: { phone: { in: phonesToTry }, purpose },
    orderBy: { created_at: 'desc' },
  });

  if (!row) {
    console.log(`No OTP rows found for phone=${phone}, purpose=${purpose}`);
    return;
  }

  console.log(`phone=${row.phone}`);
  console.log(`otp=${row.code}`);
  console.log(`created_at=${row.created_at?.toISOString?.() || row.created_at}`);
  console.log(`expires_at=${row.expires_at?.toISOString?.() || row.expires_at}`);
  console.log(`used_at=${row.used_at ? (row.used_at.toISOString?.() || row.used_at) : 'null'}`);
}

run()
  .catch((e) => {
    console.error('Failed to fetch latest OTP:', e.message || e);
    process.exit(1);
  })
  .finally(async () => {
    try {
      await prisma.$disconnect();
    } catch {}
  });

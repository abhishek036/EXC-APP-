import { PrismaClient } from '@prisma/client';

const prisma = new PrismaClient();

const ADMIN_NUMBERS = [
  '8427996261',
  '9425309290'
];

async function main() {
  console.log('Starting admin setup...');

  // Ensure an institute exists
  let institute = await prisma.institute.findFirst();
  if (!institute) {
    console.log('No institute found, creating a default Excellence Academy institute...');
    institute = await prisma.institute.create({
      data: {
        name: 'Excellence Academy',
        slug: `excellence-academy`,
        phone: ADMIN_NUMBERS[0],
        email: 'admin@excellenceacademy.site',
      },
    });
  }

  for (const phone of ADMIN_NUMBERS) {
    console.log(`Processing admin for phone: ${phone}`);
    
    // Check if user already exists
    const existingUser = await prisma.user.findFirst({
      where: { phone }
    });

    if (existingUser) {
      // Update role to admin if they already exist
      await prisma.user.update({
        where: { id: existingUser.id },
        data: { role: 'admin', is_active: true }
      });
      console.log(`✅ Updated existing user ${phone} to admin.`);
    } else {
      // Create new admin user
      await prisma.user.create({
        data: {
          institute_id: institute.id,
          phone,
          role: 'admin',
          is_active: true,
          status: 'APPROVED'
        },
      });
      console.log(`✅ Created new admin user for ${phone}.`);
    }
  }

  console.log('🎉 All admins successfully configured! You can now log in via OTP.');
}

main()
  .catch(e => {
    console.error('❌ Error configuring admins:', e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });

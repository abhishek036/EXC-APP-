
import { PrismaClient } from '@prisma/client';

const prisma = new PrismaClient();

const SUPER_USERS = ['9630457025', '8427996261'];

async function seedSuperUsers() {
  console.log('--- Initializing Super User Seed ---');
  
  // Get first institute
  const institute = await prisma.institute.findFirst();
  if (!institute) {
    console.error('No institute found in database. Please create one first.');
    return;
  }
  
  for (const phone of SUPER_USERS) {
    const fullPhone = phone.startsWith('+91') ? phone : `+91${phone}`;
    
    console.log(`\nProcessing number: ${fullPhone}`);

    // 1. Create Staff (Admin)
    const staff = await prisma.staff.upsert({
      where: { id: `00000000-0000-4000-a000-${phone.padStart(12, '0')}` },
      update: { institute_id: institute.id, phone: fullPhone, role: 'ADMIN', status: 'active' },
      create: { 
        id: `00000000-0000-4000-a000-${phone.padStart(12, '0')}`,
        institute_id: institute.id, 
        name: 'Abhishek Admin',
        phone: fullPhone,
        role: 'ADMIN',
        status: 'active'
      }
    });
    console.log(`- Staff entry verified: ${staff.id}`);

    // 2. Create Teacher
    const teacher = await prisma.teacher.upsert({
      where: { id: `00000000-0000-4000-b000-${phone.padStart(12, '0')}` },
      update: { institute_id: institute.id, phone: fullPhone, is_active: true },
      create: { 
        id: `00000000-0000-4000-b000-${phone.padStart(12, '0')}`,
        institute_id: institute.id, 
        name: 'Abhishek Teacher',
        phone: fullPhone,
        is_active: true
      }
    });
    console.log(`- Teacher entry verified: ${teacher.id}`);

    // 3. Create Student
    const student = await prisma.student.upsert({
        where: { id: `00000000-0000-4000-c000-${phone.padStart(12, '0')}` },
        update: { institute_id: institute.id, phone: fullPhone, is_active: true },
        create: { 
          id: `00000000-0000-4000-c000-${phone.padStart(12, '0')}`,
          institute_id: institute.id, 
          name: 'Abhishek Student',
          phone: fullPhone,
          is_active: true
        }
      });
      console.log(`- Student entry verified: ${student.id}`);

    // 4. Create User Records (to avoid first-time setup delays)
    // For many-role support, we'll just ensure ONE user entry exists for now.
    // The verifyOtp logic handles the role override dynamically.
    await prisma.user.upsert({
        where: { institute_id_phone: { institute_id: institute.id, phone: fullPhone } },
        update: { status: 'ACTIVE' },
        create: {
            id: `00000000-1111-4000-d000-${phone.padStart(12, '0')}`,
            phone: fullPhone,
            role: 'student', // default
            institute_id: institute.id,
            status: 'ACTIVE'
        }
    });
  }
  
  console.log('\n--- Super User Seeding Completed ---');
}

seedSuperUsers()
  .catch((e) => {
    console.error(e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });

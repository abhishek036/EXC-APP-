/**
 * Cleanup Script: Fix Duplicate Profiles
 * 
 * This script identifies and handles duplicate student/teacher/parent profiles
 * that can cause inconsistent profile data across devices.
 * 
 * Run with: npx ts-node scripts/cleanup-duplicate-profiles.ts
 */

import { PrismaClient } from '@prisma/client';

const prisma = new PrismaClient();

async function cleanupDuplicateProfiles() {
  console.log('🔍 Starting duplicate profile cleanup...\n');

  // Get all institutes
  const institutes = await prisma.institute.findMany({ select: { id: true, name: true } });
  
  for (const institute of institutes) {
    console.log(`\n📋 Processing institute: ${institute.name}`);
    
    // Check for duplicate students per phone
    const duplicateStudents = await prisma.$queryRaw<Array<{ phone: string; count: bigint }>>`
      SELECT phone, COUNT(*) as count 
      FROM students 
      WHERE institute_id = ${institute.id} AND phone IS NOT NULL
      GROUP BY phone 
      HAVING COUNT(*) > 1
    `;

    if (duplicateStudents.length > 0) {
      console.log(`  ⚠️  Found ${duplicateStudents.length} duplicate student phone(s)`);
      
      for (const dup of duplicateStudents) {
        const phone = dup.phone as string;
        // Get all students with this phone, ordered by creation date
        const students = await prisma.student.findMany({
          where: { institute_id: institute.id, phone },
          orderBy: { created_at: 'asc' }
        });

        // Keep the oldest one, link others to their user_id if exists, or mark for cleanup
        const [primary, ...others] = students;
        console.log(`     - Phone ${phone}: keeping "${primary.name}" (id: ${primary.id})`);

        for (const other of others) {
          if (other.user_id && other.user_id !== primary.user_id) {
            // Another user ID - this is a real duplicate, delete or merge
            console.log(`       ⚠️  Duplicate "${other.name}" with user_id ${other.user_id} - consider manual review`);
          } else if (!other.user_id) {
            // No user_id linking - this is likely a stale record from OTP auto-creation
            console.log(`       🗑️  "${other.name}" (no user_id) - will delete stale record`);
            // Uncomment to actually delete:
            // await prisma.student.delete({ where: { id: other.id } });
          }
        }
      }
    }

    // Check for duplicate teachers per phone
    const duplicateTeachers = await prisma.$queryRaw<Array<{ phone: string; count: bigint }>>`
      SELECT phone, COUNT(*) as count 
      FROM teachers 
      WHERE institute_id = ${institute.id} AND phone IS NOT NULL
      GROUP BY phone 
      HAVING COUNT(*) > 1
    `;

    if (duplicateTeachers.length > 0) {
      console.log(`  ⚠️  Found ${duplicateTeachers.length} duplicate teacher phone(s)`);
    }

    // Check for duplicate parents per phone
    const duplicateParents = await prisma.$queryRaw<Array<{ phone: string; count: bigint }>>`
      SELECT phone, COUNT(*) as count 
      FROM parents 
      WHERE institute_id = ${institute.id} AND phone IS NOT NULL
      GROUP BY phone 
      HAVING COUNT(*) > 1
    `;

    if (duplicateParents.length > 0) {
      console.log(`  ⚠️  Found ${duplicateParents.length} duplicate parent phone(s)`);
    }

    // Check for students with null user_id but matching phone exists in users table
    const orphanStudents = await prisma.student.findMany({
      where: { 
        institute_id: institute.id,
        user_id: null,
        phone: { not: null }
      },
      include: { user: true }
    });

    console.log(`  📊 Found ${orphanStudents.length} orphan student profiles (no user_id linking)`);

    // Link orphans to existing users based on phone match
    for (const student of orphanStudents) {
      if (student.phone) {
        const userWithPhone = await prisma.user.findFirst({
          where: { 
            institute_id: institute.id,
            phone: { in: [student.phone, `+91${student.phone}`, student.phone.replace('+91', '')] }
          }
        });

        if (userWithPhone) {
          console.log(`     🔗 Linking student "${student.name}" to user ${userWithPhone.id}`);
          // Uncomment to actually link:
          // await prisma.student.update({
          //   where: { id: student.id },
          //   data: { user_id: userWithPhone.id }
          // });
        }
      }
    }
  }

  console.log('\n✅ Duplicate profile cleanup scan complete!');
  console.log('\n📝 NOTE: Uncomment the delete/link operations in this script to actually apply fixes.');
}

cleanupDuplicateProfiles()
  .catch(console.error)
  .finally(() => prisma.$disconnect());
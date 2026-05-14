import { PrismaClient } from '@prisma/client';

const prisma = new PrismaClient();

async function main() {
  const tablesToTruncate = [
    'announcements',
    'assignment_submissions',
    'assignments',
    'attendance_records',
    'attendance_sessions',
    'audit_logs',
    'batches',
    'chat_messages',
    'doubts',
    'download_logs',
    'exam_results',
    'exams',
    'fee_discounts',
    'fee_payment_events',
    'fee_payments',
    'fee_records',
    'fee_structures',
    'holidays',
    'leads',
    'lectures',
    'note_bookmarks',
    'note_files',
    'notes',
    'notification_delivery_logs',
    'notifications',
    'payroll_records',
    'quiz_attempts',
    'quizzes',
    'student_batches',
    'student_syllabus_progress',
    'syllabus_topics',
    'user_device_tokens',
    'refresh_tokens',
    'otp_codes',
    'parent_students'
  ];

  console.log("Truncating operational tables...");
  for (const table of tablesToTruncate) {
    try {
      await prisma.$executeRawUnsafe(`TRUNCATE TABLE "${table}" CASCADE;`);
      console.log(`✅ Truncated ${table}`);
    } catch (err: any) {
      if (err.message.includes('does not exist')) {
        console.log(`⚠️ Skipped ${table} (does not exist)`);
      } else {
        console.error(`❌ Error truncating ${table}:`, err.message);
      }
    }
  }

  // Delete test accounts
  const testPhones = ["1111111110", "1111111111", "1111111112", "1111111113"];
  console.log(`\nDeleting test accounts with phones: ${testPhones.join(', ')}...`);
  
  const testUsers = await prisma.user.findMany({
    where: { phone: { in: testPhones } }
  });
  
  const testUserIds = testUsers.map(u => u.id);
  
  if (testUserIds.length > 0) {
    // Also delete related Student, Teacher, Parent records for these test accounts
    // since they are not truncated and might not have CASCADE on their user_id FK
    await prisma.student.deleteMany({ where: { user_id: { in: testUserIds } } });
    await prisma.teacher.deleteMany({ where: { user_id: { in: testUserIds } } });
    await prisma.parent.deleteMany({ where: { user_id: { in: testUserIds } } });
    
    // Now delete the users
    await prisma.user.deleteMany({ where: { id: { in: testUserIds } } });
    console.log(`✅ Deleted ${testUserIds.length} test accounts.`);
  } else {
    console.log(`ℹ️ No test accounts found to delete.`);
  }

  console.log("\nDatabase dummy data cleared successfully.");
}

main()
  .catch((e) => {
    console.error("Script failed:", e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });

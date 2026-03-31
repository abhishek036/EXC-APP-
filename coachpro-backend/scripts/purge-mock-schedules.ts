import { PrismaClient } from '@prisma/client';

const prisma = new PrismaClient();

async function purgeMockData() {
  const instituteId = '98b40e2d-dc99-43ef-b387-052637738f61'; // Your institute ID from previous logs

  console.log('--- PURGING MOCK DATA ---');

  // 1. Delete all one-off lectures
  const deletedLectures = await prisma.lecture.deleteMany({
    where: { institute_id: instituteId }
  });
  console.log(`Deleted ${deletedLectures.count} Manual Lectures.`);

  // 2. Clear recurring times from batches (to stop them from appearing as mocks)
  const clearedBatches = await prisma.batch.updateMany({
    where: { institute_id: instituteId },
    data: {
      start_time: null,
      end_time: null
    }
  });
  console.log(`Cleared recurring times for ${clearedBatches.count} Batches.`);

  console.log('--- PURGE COMPLETE ---');
}

purgeMockData()
  .catch(e => console.error(e))
  .finally(() => prisma.$disconnect());

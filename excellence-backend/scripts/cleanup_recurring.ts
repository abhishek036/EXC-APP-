import { PrismaClient } from '@prisma/client';
const prisma = new PrismaClient();

async function main() {
  console.log('Cleaning up recurring batch schedules...');
  const result = await prisma.batch.updateMany({
    data: {
      days_of_week: [],
      start_time: null,
      end_time: null,
    },
  });
  console.log(`Updated ${result.count} batches. Recurring placeholders are now disabled.`);
}

main()
  .catch(console.error)
  .finally(() => prisma.$disconnect());

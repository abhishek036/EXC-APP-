import { PrismaClient } from '@prisma/client';

const prisma = new PrismaClient();

async function main() {
  console.log('Fixing database: making youtube_url nullable in lectures table...');
  try {
    await prisma.$executeRawUnsafe(`ALTER TABLE lectures ALTER COLUMN youtube_url DROP NOT NULL;`);
    console.log('Success: youtube_url is now nullable.');
  } catch (error) {
    console.error('Error fixing database:', error);
  } finally {
    await prisma.$disconnect();
  }
}

main();

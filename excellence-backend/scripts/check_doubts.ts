import { PrismaClient } from '@prisma/client';
import * as dotenv from 'dotenv';
dotenv.config();

const prisma = new PrismaClient();

async function checkDoubts() {
  try {
    const doubts = await prisma.doubt.findMany({
      orderBy: { created_at: 'desc' },
      take: 5,
      select: {
        id: true,
        status: true,
        answer_text: true,
        resolved_at: true
      }
    });
    console.log('--- DOUBT CHECK ---');
    console.log(JSON.stringify(doubts, null, 2));
    console.log('--- END CHECK ---');
  } catch (err) {
    console.error('Check failed:', err);
  } finally {
    await prisma.$disconnect();
  }
}

checkDoubts();

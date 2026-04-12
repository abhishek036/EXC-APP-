import { PrismaClient } from '@prisma/client';

const prisma = new PrismaClient();

async function main() {
  const users = await prisma.user.findMany({
    include: {
      institute: true
    }
  });
  console.log('--- USERS IN DATABASE ---');
  users.forEach(u => {
    console.log(`ID: ${u.id}, Phone: [${u.phone}], Role: ${u.role}, Status: ${u.status}, IsActive: ${u.is_active}, Inst: ${u.institute.name}`);
  });
  console.log('-------------------------');
}

main().catch(console.error).finally(() => prisma.$disconnect());

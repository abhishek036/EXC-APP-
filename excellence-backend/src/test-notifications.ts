import { PrismaClient } from '@prisma/client';
const prisma = new PrismaClient();
async function test() {
  const notifs = await prisma.notification.findMany({ take: 1 });
  console.log(JSON.stringify(notifs, null, 2));
}
test().catch(console.error).finally(() => prisma.$disconnect());

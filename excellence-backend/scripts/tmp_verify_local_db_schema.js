require('dotenv').config();

const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

async function main() {
  const cols = await prisma.$queryRaw`
    SELECT column_name
    FROM information_schema.columns
    WHERE table_name = 'assignment_submissions' AND column_name = 'file_name'
  `;
  const tables = await prisma.$queryRaw`
    SELECT tablename
    FROM pg_tables
    WHERE schemaname = 'public' AND tablename = 'note_bookmarks'
  `;

  console.log('assignment_submissions.file_name_exists', cols.length > 0);
  console.log('note_bookmarks_exists', tables.length > 0);
}

main()
  .catch((error) => {
    console.error(error);
    process.exitCode = 1;
  })
  .finally(async () => {
    await prisma.$disconnect();
  });

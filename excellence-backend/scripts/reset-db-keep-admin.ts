import dotenv from 'dotenv';
import { PrismaClient, Prisma } from '@prisma/client';

dotenv.config();

const prisma = new PrismaClient();

type CliFlags = {
  yes: boolean;
};

const parseFlags = (): CliFlags => {
  const args = new Set(process.argv.slice(2));
  return {
    yes: args.has('--yes') || args.has('-y'),
  };
};

const redactDbUrl = (value: string | undefined): string => {
  if (!value) return '(missing DATABASE_URL)';
  try {
    const parsed = new URL(value);
    const dbName = parsed.pathname.replace(/^\//, '') || '(unknown-db)';
    return `${parsed.protocol}//${parsed.hostname}:${parsed.port || '5432'}/${dbName}`;
  } catch {
    return '(invalid DATABASE_URL)';
  }
};

async function main() {
  const flags = parseFlags();

  if (!flags.yes) {
    console.log('This operation is destructive.');
    console.log('It will clear all data except admin users and their institutes.');
    console.log('Run again with --yes to execute.');
    process.exit(1);
  }

  const dbUrl = process.env.DATABASE_URL;
  console.log(`[target-db] ${redactDbUrl(dbUrl)}`);

  const adminUsers = await prisma.user.findMany({
    where: {
      role: {
        equals: 'admin',
        mode: 'insensitive',
      },
    },
  });

  if (adminUsers.length === 0) {
    throw new Error('No admin users found. Aborting to avoid lockout.');
  }

  const instituteIds = [...new Set(adminUsers.map((u) => u.institute_id))];

  const institutes = await prisma.institute.findMany({
    where: { id: { in: instituteIds } },
  });

  if (institutes.length === 0) {
    throw new Error('No institutes found for admin users. Aborting to avoid orphaned logins.');
  }

  const tableRows = await prisma.$queryRaw<{ tablename: string }[]>`
    SELECT tablename
    FROM pg_tables
    WHERE schemaname = 'public'
      AND tablename <> '_prisma_migrations'
    ORDER BY tablename;
  `;

  if (tableRows.length === 0) {
    throw new Error('No public tables found to reset.');
  }

  const quotedTables = tableRows
    .map((row) => `"${row.tablename.replace(/"/g, '""')}"`)
    .join(', ');

  const beforeCounts = {
    institutes: await prisma.institute.count(),
    users: await prisma.user.count(),
    students: await prisma.student.count(),
    teachers: await prisma.teacher.count(),
    parents: await prisma.parent.count(),
    feeRecords: await prisma.feeRecord.count(),
    notifications: await prisma.notification.count(),
  };

  console.log('[before-counts]', beforeCounts);
  console.log(`[preserve] institutes=${institutes.length}, admins=${adminUsers.length}`);

  await prisma.$transaction(
    async (tx) => {
      await tx.$executeRaw(Prisma.sql`TRUNCATE TABLE ${Prisma.raw(quotedTables)} RESTART IDENTITY CASCADE`);

      await tx.institute.createMany({
        data: institutes.map((i) => ({
          id: i.id,
          name: i.name,
          slug: i.slug,
          join_code: i.join_code,
          logo_url: i.logo_url,
          address: i.address,
          phone: i.phone,
          email: i.email,
          website: i.website,
          primary_color: i.primary_color,
          settings: i.settings === null ? Prisma.JsonNull : (i.settings as Prisma.InputJsonValue),
          is_active: i.is_active,
          created_at: i.created_at,
        })),
      });

      await tx.user.createMany({
        data: adminUsers.map((u) => ({
          id: u.id,
          institute_id: u.institute_id,
          phone: u.phone,
          email: u.email,
          password_hash: u.password_hash,
          role: u.role,
          status: u.status,
          is_active: u.is_active,
          last_login_at: u.last_login_at,
          avatar_url: u.avatar_url,
          created_at: u.created_at,
        })),
      });
    },
    {
      maxWait: 10_000,
      timeout: 120_000,
      isolationLevel: Prisma.TransactionIsolationLevel.Serializable,
    },
  );

  const afterCounts = {
    institutes: await prisma.institute.count(),
    users: await prisma.user.count(),
    students: await prisma.student.count(),
    teachers: await prisma.teacher.count(),
    parents: await prisma.parent.count(),
    feeRecords: await prisma.feeRecord.count(),
    notifications: await prisma.notification.count(),
  };

  console.log('[after-counts]', afterCounts);
  console.log('Database reset complete. Admin logins preserved.');
}

main()
  .catch((error) => {
    console.error('[reset-db-keep-admin] failed:', error);
    process.exitCode = 1;
  })
  .finally(async () => {
    await prisma.$disconnect();
  });

/* eslint-disable no-console */
const { PrismaClient } = require('@prisma/client');

const prisma = new PrismaClient();

const UUID_REGEX = '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-5][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$';
const APPLY = process.argv.includes('--apply') || process.env.APPLY_LECTURE_UUID_CLEANUP === 'true';

function whereInvalidClause(alias = 'l') {
  return `
    ${alias}.id::text !~* '${UUID_REGEX}'
    OR ${alias}.teacher_id::text !~* '${UUID_REGEX}'
    OR ${alias}.batch_id::text !~* '${UUID_REGEX}'
  `;
}

async function run() {
  console.log('[lecture-uuid-cleanup] starting');

  const malformedRows = await prisma.$queryRawUnsafe(
    `SELECT COUNT(*)::int AS count FROM lectures l WHERE ${whereInvalidClause('l')}`,
  );
  const malformedCount = Number(malformedRows?.[0]?.count ?? 0);

  console.log(`[lecture-uuid-cleanup] malformed rows found: ${malformedCount}`);

  if (malformedCount === 0) {
    console.log('[lecture-uuid-cleanup] nothing to clean');
    return;
  }

  if (!APPLY) {
    console.log('[lecture-uuid-cleanup] dry run complete. Re-run with --apply to backup + delete malformed rows.');
    return;
  }

  const result = await prisma.$transaction(async (tx) => {
    await tx.$executeRawUnsafe(`
      CREATE TABLE IF NOT EXISTS lectures_bad_uuid_backup AS
      SELECT * FROM lectures WHERE FALSE
    `);

    const backedUp = await tx.$executeRawUnsafe(
      `
      INSERT INTO lectures_bad_uuid_backup
      SELECT *
      FROM lectures l
      WHERE ${whereInvalidClause('l')}
      `,
    );

    const deleted = await tx.$executeRawUnsafe(
      `
      DELETE FROM lectures l
      WHERE ${whereInvalidClause('l')}
      `,
    );

    const remainingRows = await tx.$queryRawUnsafe(
      `SELECT COUNT(*)::int AS count FROM lectures l WHERE ${whereInvalidClause('l')}`,
    );
    const remaining = Number(remainingRows?.[0]?.count ?? 0);

    return { backedUp, deleted, remaining };
  });

  console.log(`[lecture-uuid-cleanup] backup inserted rows: ${Number(result.backedUp || 0)}`);
  console.log(`[lecture-uuid-cleanup] deleted rows: ${Number(result.deleted || 0)}`);
  console.log(`[lecture-uuid-cleanup] malformed rows remaining: ${result.remaining}`);

  if (result.remaining > 0) {
    throw new Error('Cleanup incomplete: malformed rows still remain after delete.');
  }

  console.log('[lecture-uuid-cleanup] cleanup complete');
}

run()
  .catch((err) => {
    console.error('[lecture-uuid-cleanup] failed:', err?.message || err);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });

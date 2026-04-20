require('dotenv').config();

const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

const KEEP_ID = '27dc776f-20ea-47ae-b499-93276ef715ea';
const DROP_ID = 'f9184ad9-56e2-49a6-bd68-02603f9cdb08';

async function main() {
  const beforeKeep = await prisma.parentStudent.count({ where: { parent_id: KEEP_ID } });
  const beforeDrop = await prisma.parentStudent.count({ where: { parent_id: DROP_ID } });

  await prisma.$transaction(async (tx) => {
    await tx.$executeRaw`
      UPDATE parent_students ps
      SET parent_id = ${KEEP_ID}
      WHERE ps.parent_id = ${DROP_ID}
        AND NOT EXISTS (
          SELECT 1
          FROM parent_students existing
          WHERE existing.parent_id = ${KEEP_ID}
            AND existing.student_id = ps.student_id
        )
    `;

    await tx.parentStudent.deleteMany({ where: { parent_id: DROP_ID } });
    await tx.parent.deleteMany({ where: { id: DROP_ID } });
  });

  const afterKeep = await prisma.parentStudent.count({ where: { parent_id: KEEP_ID } });
  const afterDrop = await prisma.parentStudent.count({ where: { parent_id: DROP_ID } });

  const duplicateGroups = await prisma.$queryRaw`
    SELECT institute_id, phone, COUNT(*)::int AS count
    FROM parents
    WHERE phone IS NOT NULL
    GROUP BY institute_id, phone
    HAVING COUNT(*) > 1
  `;

  console.log(
    JSON.stringify(
      {
        keepId: KEEP_ID,
        droppedId: DROP_ID,
        beforeKeep,
        beforeDrop,
        afterKeep,
        afterDrop,
        duplicateParentGroups: duplicateGroups.length,
      },
      null,
      2,
    ),
  );
}

main()
  .catch((error) => {
    console.error(error);
    process.exitCode = 1;
  })
  .finally(async () => {
    await prisma.$disconnect();
  });

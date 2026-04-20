const { PrismaClient, Prisma } = require('@prisma/client');
const prisma = new PrismaClient();

async function main() {
    console.log('--- DB INTEGRITY VERIFICATION ---');
    
    const tables = ['quizzes', 'assignments', 'notes', 'lectures', 'doubts'];
    
    for (const table of tables) {
        try {
            const tableSql = Prisma.raw(`"${table.replace(/"/g, '""')}"`);
            const result = await prisma.$queryRaw(Prisma.sql`SELECT count(*) as count FROM ${tableSql}`);
            console.log(`[OK] ${table.padEnd(12)}: Found ${JSON.stringify(result[0])} rows.`);
        } catch (e) {
            console.error(`[FAIL] ${table.padEnd(12)}: ${e.message}`);
        }
    }

    try {
        const colCheck = await prisma.$queryRaw`
          SELECT column_name
          FROM information_schema.columns
          WHERE table_name = 'quizzes' AND column_name = 'subject'
        `;
        if (Array.isArray(colCheck) && colCheck.length > 0) {
            console.log('[INFO] Quizzes table has "subject" column (no fallback needed)');
        } else {
            console.log('[WARN] Quizzes table MISSING "subject" column (fallback ACTIVE)');
        }
    } catch (e) {
        console.error('[ERR] Column check failed:', e.message);
    }

    await prisma.$disconnect();
}

main();

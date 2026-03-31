import { PrismaClient } from '@prisma/client';

const prisma = new PrismaClient();

async function main() {
    console.log("Checking scheduled lectures for all batches.");
    const actualLectures = await prisma.lecture.findMany({
        where: {
            is_active: true,
        },
        include: {
            batch: { select: { name: true } }
        },
        orderBy: { scheduled_at: 'asc' }
    });
    console.log("Found:", actualLectures.length, "total lectures.");
    
    actualLectures.forEach(l => {
        console.log(`Lecture ID: ${l.id}, Batch ID: ${l.batch_id}, Scheduled At: ${l.scheduled_at}`);
    });
}
main().finally(() => prisma.$disconnect());

import { Queue, Worker, Job } from 'bullmq';
import { redis } from '../config/redis';
import { FeeHandler } from './handlers/fee.handler';
import { AttendanceHandler } from './handlers/attendance.handler';

// Only create queues if Redis is available
export const notificationQueue = redis ? new Queue('notifications', { connection: redis as any }) : null;
export const reportQueue = redis ? new Queue('reports', { connection: redis as any }) : null;
export const cronQueue = redis ? new Queue('cron', { connection: redis as any }) : null;

export const setupQueues = () => {
    if (!redis) {
        console.warn('⚠️ BullMQ disabled: no Redis connection. Background jobs will not run.');
        return;
    }
    console.log('✅ BullMQ Queues initialized');

    // 1. Notification Worker (for sending individual alerts)
    const notificationWorker = new Worker('notifications', async (job: Job) => {
        console.log(`Processing job ${job.id}: ${job.name}`);

        switch (job.name) {
            case 'ATTENDANCE_ALERT':
                await AttendanceHandler.processAttendanceAlerts(job.data.sessionId, job.data.instituteId);
                break;
            case 'FEE_REMINDER':
                // Individual fee reminder (if manually triggered)
                break;
        }
    }, { connection: redis as any });

    // 2. CRON Worker (for recurring tasks)
    const cronWorker = new Worker('cron', async (job: Job) => {
        console.log(`Processing CRON job: ${job.name}`);

        switch (job.name) {
            case 'MONTHLY_FEE_GENERATION':
                await FeeHandler.generateAllMonthlyFees();
                break;
            case 'DAILY_FEE_REMINDERS':
                await FeeHandler.sendPendingFeeReminders();
                break;
        }
    }, { connection: redis as any });

    // Setup recurring schedules
    setupSchedules();

    // Listen for events
    notificationWorker.on('failed', (job, err) => console.error(`Job ${job?.id} failed:`, err.message));
    cronWorker.on('failed', (job, err) => console.error(`CRON Job ${job?.id} failed:`, err.message));
};

const setupSchedules = async () => {
    if (!cronQueue) return;
    // 1st of every month at 00:00
    await cronQueue.add('MONTHLY_FEE_GENERATION', {}, {
        repeat: { pattern: '0 0 1 * *' }
    });

    // Daily at 09:00 AM
    await cronQueue.add('DAILY_FEE_REMINDERS', {}, {
        repeat: { pattern: '0 9 * * *' }
    });
};

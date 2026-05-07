import 'dotenv/config';
import app from './app';
import http from 'http';
import { initSocket } from './config/socket';
import { initializeFirebaseAdmin } from './config/firebase-admin';
import { prisma } from './config/prisma';
import { startNeonKeepalive } from './utils/neon-keepalive';

const PORT = process.env.PORT || 3000;
export { prisma };

function validateCriticalEnv() {
    if (!process.env.JWT_SECRET || process.env.JWT_SECRET.trim().length < 32) {
        throw new Error('JWT_SECRET is missing or too short. Set a stable JWT_SECRET in Azure App Settings before starting the server.');
    }
}

import { setupQueues } from './jobs/queue';

// Only start the server if this file is run directly (not imported via tests/seeder)
if (require.main === module) {
    const startServer = async () => {
        try {
            validateCriticalEnv();
            await prisma.$connect();
            console.log('✅ Connected to database successfully');
            startNeonKeepalive();
            initializeFirebaseAdmin();
            
            setupQueues();

            const server = http.createServer(app);
            initSocket(server);

            server.on('error', (error: NodeJS.ErrnoException) => {
                if (error.code === 'EADDRINUSE') {
                    console.error(`❌ Port ${PORT} is already in use. Stop the existing process or change PORT.`);
                } else if (error.code === 'EACCES') {
                    console.error(`❌ Permission denied while binding to port ${PORT}.`);
                } else {
                    console.error('❌ Server failed to start', error);
                }
                process.exit(1);
            });

            server.listen(PORT, () => {
                 console.log(`🚀 Server running on port ${PORT}`);
                 console.log(`⏱ Environment: ${process.env.NODE_ENV}`);
            });

            // Graceful shutdown — PM2 sends SIGINT on restart, SIGTERM on stop
            const gracefulShutdown = async (signal: string) => {
                console.log(`\n🛑 ${signal} received — starting graceful shutdown...`);
                server.close(async () => {
                    console.log('✅ HTTP server closed');
                    try {
                        await prisma.$disconnect();
                        console.log('✅ Database disconnected');
                    } catch (e) { /* swallow */ }
                    process.exit(0);
                });
                // Force close after 10s if connections won't drain
                setTimeout(() => {
                    console.error('⚠️ Forced shutdown after 10s timeout');
                    process.exit(1);
                }, 10_000);
            };

            process.on('SIGINT', () => gracefulShutdown('SIGINT'));
            process.on('SIGTERM', () => gracefulShutdown('SIGTERM'));

        } catch (error) {
            console.error('❌ Failed to connect to database', error);
            process.exit(1);
        }
    };
    
    startServer().catch((err: any) => {
        console.error('Fatal error starting server:', err);
        process.exit(1);
    });

    // Catch unhandled errors so PM2 can log them before restart
    process.on('unhandledRejection', (reason) => {
        console.error('⚠️ Unhandled Promise Rejection:', reason);
    });

    process.on('uncaughtException', (error) => {
        console.error('💀 Uncaught Exception:', error);
        process.exit(1);
    });
}

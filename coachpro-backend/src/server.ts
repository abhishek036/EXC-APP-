import app from './app';
import dotenv from 'dotenv';
import { PrismaClient } from '@prisma/client';
import http from 'http';
import { initSocket } from './config/socket';
import { initializeFirebaseAdmin } from './config/firebase-admin';

dotenv.config();

const PORT = process.env.PORT || 3000;
export const prisma = new PrismaClient();

function validateCriticalEnv() {
    if (!process.env.JWT_SECRET || process.env.JWT_SECRET.trim().length < 16) {
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
            initializeFirebaseAdmin();
            
            setupQueues();

            const server = http.createServer(app);
            initSocket(server);

            server.listen(PORT, () => {
                 console.log(`🚀 Server running on port ${PORT}`);
                 console.log(`⏱ Environment: ${process.env.NODE_ENV}`);
            });
        } catch (error) {
            console.error('❌ Failed to connect to database', error);
            process.exit(1);
        }
    };
    
    startServer();
}

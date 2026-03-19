import app from './app';
import dotenv from 'dotenv';
import { PrismaClient } from '@prisma/client';
import http from 'http';
import { initSocket } from './config/socket';

dotenv.config();

const PORT = process.env.PORT || 3000;
export const prisma = new PrismaClient();

import { setupQueues } from './jobs/queue';

// Only start the server if this file is run directly (not imported via tests/seeder)
if (require.main === module) {
    const startServer = async () => {
        try {
            await prisma.$connect();
            console.log('✅ Connected to database successfully');
            
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

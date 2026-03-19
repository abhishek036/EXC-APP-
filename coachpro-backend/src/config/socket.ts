import { Server } from 'socket.io';
import http from 'http';

let io: Server;

export const initSocket = (server: http.Server) => {
    io = new Server(server, {
        cors: {
            origin: '*', // For development; refine in production
            methods: ['GET', 'POST']
        }
    });

    console.log('📶 Socket.io initialized');

    io.on('connection', (socket) => {
        console.log(`🔌 New client connected: ${socket.id}`);

        socket.on('join_batch', (batchId: string) => {
            socket.join(`batch_${batchId}`);
            console.log(`👤 Client ${socket.id} joined batch room: ${batchId}`);
        });

        socket.on('send_message', (data: { batchId: string, senderId: string, message: string, senderName: string, role: string }) => {
            // Emitting to the room
            io.to(`batch_${data.batchId}`).emit('new_message', {
                ...data,
                created_at: new Date()
            });
        });

        socket.on('disconnect', () => {
            console.log(`🔌 Client disconnected: ${socket.id}`);
        });
    });

    return io;
};

export const getIO = () => {
    if (!io) throw new Error('Socket.io not initialized');
    return io;
};

import { Server } from 'socket.io';
import http from 'http';
import * as jwt from 'jsonwebtoken';

let io: Server;

type TokenPayload = {
    userId?: string;
    role?: string;
    instituteId?: string;
};

const readToken = (socket: any): string | undefined => {
    const fromAuth = socket?.handshake?.auth?.token;
    if (typeof fromAuth === 'string' && fromAuth.trim().length > 0) return fromAuth;
    const fromQuery = socket?.handshake?.query?.token;
    if (typeof fromQuery === 'string' && fromQuery.trim().length > 0) return fromQuery;
    return undefined;
};

const decodePayload = (token?: string): TokenPayload | null => {
    if (!token) return null;
    const secret = process.env.JWT_SECRET;
    if (!secret) return null;
    try {
        return jwt.verify(token, secret) as TokenPayload;
    } catch {
        return null;
    }
};

const roomInstitute = (instituteId: string) => `institute_${instituteId}`;
const roomRole = (instituteId: string, role: string) => `role_${role}_${instituteId}`;

export const initSocket = (server: http.Server) => {
    const allowedOrigins = (process.env.ALLOWED_ORIGINS || '').split(',').map(o => o.trim()).filter(Boolean);

    io = new Server(server, {
        cors: {
            origin: function(origin: any, callback: any) {
                if (!origin || allowedOrigins.length === 0 || allowedOrigins.includes('*') || allowedOrigins.includes(origin)) {
                    callback(null, true);
                } else {
                    callback(new Error(`Origin ${origin} not allowed by Socket.io CORS`));
                }
            },
            methods: ['GET', 'POST']
        }
    });

    console.log('📶 Socket.io initialized');

    io.on('connection', (socket) => {
        console.log(`🔌 New client connected: ${socket.id}`);

        const payload = decodePayload(readToken(socket));
        if (payload?.instituteId) {
            socket.join(roomInstitute(payload.instituteId));
            if (payload.userId) {
                socket.join(`user_${payload.userId}`);
            }
            if (payload.role) {
                socket.join(roomRole(payload.instituteId, payload.role));
            }
        }

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

export const emitInstituteDashboardSync = (
    instituteId: string,
    reason: string,
    payload: Record<string, unknown> = {},
) => {
    if (!io) return;
    io.to(roomInstitute(instituteId)).emit('dashboard_sync', {
        reason,
        institute_id: instituteId,
        at: new Date().toISOString(),
        ...payload,
    });
};

export const emitBatchSync = (
    instituteId: string,
    batchId: string,
    reason: string,
    payload: Record<string, unknown> = {},
) => {
    if (!io) return;
    io.to(`batch_${batchId}`).emit('batch_sync', {
        reason,
        institute_id: instituteId,
        batch_id: batchId,
        at: new Date().toISOString(),
        ...payload,
    });

    io.to(roomInstitute(instituteId)).emit('dashboard_sync', {
        reason,
        institute_id: instituteId,
        batch_id: batchId,
        at: new Date().toISOString(),
        ...payload,
    });
};

export const emitUnreadCount = (instituteId: string, userId: string, count: number) => {
    if (!io) return;
    io.to(`user_${userId}`).emit('unread_count_update', {
        institute_id: instituteId,
        user_id: userId,
        unread_count: count,
    });
};

import { Server } from 'socket.io';
import http from 'http';
import * as jwt from 'jsonwebtoken';
import { prisma } from './prisma';
import { buildCorsPolicy, isOriginAllowed } from '../utils/cors';

let io: Server;

type TokenPayload = {
    userId: string;
    role: string;
    instituteId: string;
    iat?: number;
    exp?: number;
};

type SocketMessagePayload = {
    batchId?: string;
    message?: string;
    senderName?: string;
};

const SOCKET_VERIFY_ALGORITHMS: jwt.Algorithm[] = ['HS256'];
const SOCKET_CLOCK_TOLERANCE_SECONDS = Number.parseInt(process.env.JWT_CLOCK_TOLERANCE_SECONDS || '300', 10);
const SOCKET_MAX_MESSAGE_BYTES = Number.parseInt(process.env.SOCKET_MAX_HTTP_BUFFER_SIZE || `${1024 * 1024}`, 10);
const SOCKET_MESSAGE_LIMIT_WINDOW_MS = Number.parseInt(process.env.SOCKET_MESSAGE_WINDOW_MS || '10000', 10);
const SOCKET_MESSAGE_LIMIT_COUNT = Number.parseInt(process.env.SOCKET_MESSAGE_LIMIT_COUNT || '20', 10);

const getSafeWindowMs = () => (Number.isFinite(SOCKET_MESSAGE_LIMIT_WINDOW_MS) ? SOCKET_MESSAGE_LIMIT_WINDOW_MS : 10000);
const getSafeMessageCount = () => (Number.isFinite(SOCKET_MESSAGE_LIMIT_COUNT) ? SOCKET_MESSAGE_LIMIT_COUNT : 20);

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
        const decoded = jwt.verify(token, secret, {
            algorithms: SOCKET_VERIFY_ALGORITHMS,
            clockTolerance: Number.isFinite(SOCKET_CLOCK_TOLERANCE_SECONDS) ? SOCKET_CLOCK_TOLERANCE_SECONDS : 300,
        }) as Partial<TokenPayload>;

        if (!decoded || typeof decoded.userId !== 'string' || typeof decoded.role !== 'string' || typeof decoded.instituteId !== 'string') {
            return null;
        }

        return {
            userId: decoded.userId,
            role: decoded.role,
            instituteId: decoded.instituteId,
            iat: decoded.iat,
            exp: decoded.exp,
        };
    } catch {
        return null;
    }
};

const canAccessBatch = async (payload: TokenPayload, batchId: string): Promise<boolean> => {
    const normalizedRole = payload.role.toLowerCase();

    if (normalizedRole === 'admin') {
        const batch = await prisma.batch.findFirst({
            where: { id: batchId, institute_id: payload.instituteId, is_active: true },
            select: { id: true },
        });
        return Boolean(batch);
    }

    if (normalizedRole === 'teacher') {
        const teacher = await prisma.teacher.findFirst({
            where: { user_id: payload.userId, institute_id: payload.instituteId },
            select: { id: true },
        });
        if (!teacher) return false;

        const batch = await prisma.batch.findFirst({
            where: {
                id: batchId,
                institute_id: payload.instituteId,
                teacher_id: teacher.id,
                is_active: true,
            },
            select: { id: true },
        });
        return Boolean(batch);
    }

    if (normalizedRole === 'student') {
        const student = await prisma.student.findFirst({
            where: { user_id: payload.userId, institute_id: payload.instituteId },
            select: { id: true },
        });
        if (!student) return false;

        const membership = await prisma.studentBatch.findFirst({
            where: {
                student_id: student.id,
                batch_id: batchId,
                is_active: true,
            },
            select: { id: true },
        });
        return Boolean(membership);
    }

    if (normalizedRole === 'parent') {
        const parent = await prisma.parent.findFirst({
            where: { user_id: payload.userId, institute_id: payload.instituteId },
            select: { id: true },
        });
        if (!parent) return false;

        const membership = await prisma.studentBatch.findFirst({
            where: {
                batch_id: batchId,
                is_active: true,
                student: {
                    parent_students: {
                        some: { parent_id: parent.id },
                    },
                },
            },
            select: { id: true },
        });
        return Boolean(membership);
    }

    return false;
};

const isSocketMessageRateLimited = (socket: any): boolean => {
    const now = Date.now();
    const windowMs = getSafeWindowMs();
    const maxMessages = getSafeMessageCount();
    const current = socket.data?.messageRate as { startAt: number; count: number } | undefined;

    if (!current || now - current.startAt > windowMs) {
        socket.data.messageRate = { startAt: now, count: 1 };
        return false;
    }

    if (current.count >= maxMessages) {
        return true;
    }

    current.count += 1;
    socket.data.messageRate = current;
    return false;
};

const roomInstitute = (instituteId: string) => `institute_${instituteId}`;
const roomRole = (instituteId: string, role: string) => `role_${role}_${instituteId}`;

export const initSocket = (server: http.Server) => {
    const corsPolicy = buildCorsPolicy(process.env.NODE_ENV, process.env.ALLOWED_ORIGINS || '');

    io = new Server(server, {
        cors: {
            origin: function(origin: any, callback: any) {
                if (isOriginAllowed(origin, corsPolicy)) {
                    callback(null, true);
                } else {
                    callback(new Error(`Origin ${origin} not allowed by Socket.io CORS`));
                }
            },
            methods: ['GET', 'POST'],
            credentials: corsPolicy.supportsCredentials,
        },
        maxHttpBufferSize: Number.isFinite(SOCKET_MAX_MESSAGE_BYTES) ? SOCKET_MAX_MESSAGE_BYTES : 1024 * 1024,
    });

    io.use((socket, next) => {
        const payload = decodePayload(readToken(socket));
        if (!payload) {
            return next(new Error('UNAUTHORIZED_SOCKET'));
        }

        socket.data.auth = payload;
        socket.data.joinedBatches = new Set<string>();
        return next();
    });

    console.log('📶 Socket.io initialized');

    io.on('connection', (socket) => {
        console.log(`🔌 New client connected: ${socket.id}`);

        const payload = socket.data.auth as TokenPayload;
        socket.join(roomInstitute(payload.instituteId));
        socket.join(`user_${payload.userId}`);
        socket.join(roomRole(payload.instituteId, payload.role));

        socket.on('join_batch', async (batchIdRaw: string) => {
            const batchId = String(batchIdRaw || '').trim();
            if (!batchId) {
                socket.emit('socket_error', { code: 'INVALID_BATCH_ID', message: 'Batch id is required' });
                return;
            }

            try {
                const canJoin = await canAccessBatch(payload, batchId);
                if (!canJoin) {
                    socket.emit('socket_error', { code: 'FORBIDDEN_BATCH', message: 'You are not allowed to join this batch room' });
                    return;
                }

                socket.join(`batch_${batchId}`);
                const joinedBatches = (socket.data.joinedBatches as Set<string>) || new Set<string>();
                joinedBatches.add(batchId);
                socket.data.joinedBatches = joinedBatches;
                console.log(`👤 Client ${socket.id} joined batch room: ${batchId}`);
            } catch (error) {
                console.error('[SOCKET] Failed to authorize batch join:', error);
                socket.emit('socket_error', { code: 'JOIN_FAILED', message: 'Unable to join batch room' });
            }
        });

        socket.on('send_message', (data: SocketMessagePayload) => {
            if (isSocketMessageRateLimited(socket)) {
                socket.emit('socket_error', { code: 'RATE_LIMITED', message: 'Too many messages, slow down.' });
                return;
            }

            const batchId = String(data?.batchId || '').trim();
            const message = String(data?.message || '').trim();
            const joinedBatches = (socket.data.joinedBatches as Set<string>) || new Set<string>();

            if (!batchId || !joinedBatches.has(batchId)) {
                socket.emit('socket_error', { code: 'FORBIDDEN_BATCH', message: 'Join the room before sending messages.' });
                return;
            }

            if (!message) {
                socket.emit('socket_error', { code: 'EMPTY_MESSAGE', message: 'Message cannot be empty.' });
                return;
            }

            io.to(`batch_${data.batchId}`).emit('new_message', {
                batchId,
                senderId: payload.userId,
                senderName: String(data?.senderName || 'User').trim().slice(0, 80),
                role: payload.role,
                message: message.slice(0, 2000),
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

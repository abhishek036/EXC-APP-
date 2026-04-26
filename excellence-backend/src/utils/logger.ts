import { prisma } from '../config/prisma';

export enum AuditAction {
    LOGIN = 'LOGIN',
    LOGOUT = 'LOGOUT',
    CREATE = 'CREATE',
    UPDATE = 'UPDATE',
    DELETE = 'DELETE',
    FEE_PAYMENT = 'FEE_PAYMENT',
    ATTENDANCE_MARK = 'ATTENDANCE_MARK'
}

export class Logger {
    static async log(params: {
        actorId?: string;
        instituteId?: string;
        action: AuditAction | string;
        entityType?: string;
        entityId?: string;
        oldValue?: any;
        newValue?: any;
        ipAddress?: string;
    }) {
        try {
            // Log to console in development
            if (process.env.NODE_ENV === 'development') {
                console.log(`[AUDIT] ${params.action} by ${params.actorId || 'SYSTEM'} on ${params.entityType || 'N/A'}`);
            }

            // Save to database AuditLog
            await prisma.auditLog.create({
                data: {
                    actor_id: params.actorId,
                    institute_id: params.instituteId,
                    action: params.action,
                    entity_type: params.entityType,
                    entity_id: params.entityId,
                    old_value: params.oldValue,
                    new_value: params.newValue,
                    ip_address: params.ipAddress
                }
            });
        } catch (error) {
            console.error('CRITICAL: Audit log failed to write to database', error);
        }
    }

    static info(message: string) {
        console.log(`[INFO] ${new Date().toISOString()}: ${message}`);
    }

    static error(message: string, error?: any) {
        console.error(`[ERROR] ${new Date().toISOString()}: ${message}`, error || '');
    }
}

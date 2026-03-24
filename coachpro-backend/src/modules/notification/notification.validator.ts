import { z } from 'zod';

export const notificationTypeSchema = z.enum(['fee', 'class', 'exam', 'attendance', 'system', 'content', 'result']);
export const notificationRoleTargetSchema = z.enum(['admin', 'teacher', 'student', 'parent', 'all']);

export const registerDeviceTokenSchema = z.object({
  body: z.object({
    token: z.string().min(20),
    platform: z.enum(['android', 'ios', 'web']),
  }),
});

export const unregisterDeviceTokenSchema = z.object({
  body: z.object({
    token: z.string().min(20),
  }),
});

export const listNotificationsQuerySchema = z.object({
  query: z.object({
    page: z.coerce.number().int().positive().optional(),
    perPage: z.coerce.number().int().positive().max(100).optional(),
    type: notificationTypeSchema.optional(),
    read_status: z.enum(['read', 'unread', 'all']).optional(),
  }),
});

export const markNotificationReadSchema = z.object({
  body: z.object({
    read_status: z.boolean(),
  }),
});

export const sendNotificationSchema = z.object({
  body: z.object({
    title: z.string().min(1).max(200),
    body: z.string().min(1),
    type: notificationTypeSchema,
    role_target: notificationRoleTargetSchema.optional(),
    user_id: z.string().uuid().optional(),
    institute_id: z.string().uuid().optional(),
    meta: z.record(z.any()).optional(),
  }).refine((body) => body.user_id || body.role_target || body.institute_id, {
    message: 'Provide one target: user_id, role_target, or institute_id',
    path: ['user_id'],
  }),
});

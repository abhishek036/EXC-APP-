import { z } from 'zod';

export const createBatchSchema = z.object({
  body: z.object({
    name: z.string().min(2).max(200),
    subject: z.string().max(100).optional(),
    teacher_id: z.string().uuid().optional(),
    days_of_week: z.array(z.number().min(0).max(6)).optional(),
    start_time: z.string().optional(), // 'HH:mm:ss' assumed, but db.Time is weird in Prisma, often passed as a DateTime ISO string but with time 
    end_time: z.string().optional(),
    room: z.string().max(50).optional(),
    start_date: z.string().datetime().optional(), // Or parse from simple date
    end_date: z.string().datetime().optional(),
    capacity: z.number().positive().optional(),
    batch_type: z.enum(['regular', 'crash', 'test_series']).optional(),
  })
});

export const updateBatchSchema = createBatchSchema.deepPartial();

export const addStudentsToBatchSchema = z.object({
  body: z.object({
    studentIds: z.array(z.string().uuid())
  })
});

export type CreateBatchInput = z.infer<typeof createBatchSchema>['body'];
export type UpdateBatchInput = z.infer<typeof updateBatchSchema>['body'];

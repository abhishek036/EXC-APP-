import { z } from 'zod';

export const createBatchSchema = z.object({
  body: z.object({
    name: z.string().min(2).max(200),
    subject: z.string().max(100).optional(),
    teacher_id: z.string().uuid().optional(),
    teacher_ids: z.array(z.string().uuid()).optional(),
    days_of_week: z.array(z.number().min(0).max(6)).optional(),
    start_time: z.string().optional(), // 'HH:mm:ss' assumed, but db.Time is weird in Prisma, often passed as a DateTime ISO string but with time 
    end_time: z.string().optional(),
    room: z.string().max(50).optional(),
    start_date: z.string().optional(), // accepts ISO or yyyy-mm-dd
    end_date: z.string().optional(),
    capacity: z.number().positive().optional(),
    batch_type: z.enum(['regular', 'crash', 'test_series']).optional(),
    description: z.string().max(2000).optional(),
    cover_image_url: z.string().url().optional(),
    faqs: z.array(
      z.object({
        question: z.string().min(1).max(300),
        answer: z.string().min(1).max(2000),
      })
    ).optional(),
  })
});

export const updateBatchSchema = createBatchSchema.deepPartial();

export const addStudentsToBatchSchema = z.object({
  body: z.object({
    studentIds: z.array(z.string().uuid())
  })
});

export const updateBatchMetaSchema = z.object({
  body: z.object({
    description: z.string().max(2000).optional(),
    cover_image_url: z.string().url().optional(),
    teacher_ids: z.array(z.string().uuid()).optional(),
    faqs: z.array(
      z.object({
        question: z.string().min(1).max(300),
        answer: z.string().min(1).max(2000),
      })
    ).optional(),
  })
});

export const migrateBatchStudentsSchema = z.object({
  body: z.object({
    target_batch_id: z.string().uuid(),
    deactivate_source: z.boolean().optional(),
    activate_target: z.boolean().optional(),
  })
});

export type CreateBatchInput = z.infer<typeof createBatchSchema>['body'];
export type UpdateBatchInput = z.infer<typeof updateBatchSchema>['body'];
export type UpdateBatchMetaInput = z.infer<typeof updateBatchMetaSchema>['body'];
export type MigrateBatchStudentsInput = z.infer<typeof migrateBatchStudentsSchema>['body'];

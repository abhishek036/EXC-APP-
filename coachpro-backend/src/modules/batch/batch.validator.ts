import { z } from 'zod';

const nullableOptionalString = () => z.preprocess((value) => value === null ? undefined : value, z.string().optional());
const nullableOptionalUrl = () => z.preprocess((value) => value === null || value === '' ? undefined : value, z.string().url().optional());

export const createBatchSchema = z.object({
  body: z.object({
    name: z.string().min(2).max(200),
    subject: nullableOptionalString().refine((v) => v == null || v.length <= 100, { message: 'String must contain at most 100 character(s)' }),
    teacher_id: z.string().uuid().optional(),
    teacher_ids: z.array(z.string().uuid()).optional(),
    days_of_week: z.array(z.number().min(0).max(6)).optional(),
    start_time: nullableOptionalString(), // 'HH:mm:ss' assumed, but db.Time is weird in Prisma, often passed as a DateTime ISO string but with time 
    end_time: nullableOptionalString(),
    room: nullableOptionalString().refine((v) => v == null || v.length <= 50, { message: 'String must contain at most 50 character(s)' }),
    start_date: nullableOptionalString(), // accepts ISO or yyyy-mm-dd
    end_date: nullableOptionalString(),
    capacity: z.number().positive().optional(),
    batch_type: z.enum(['regular', 'crash', 'test_series']).optional(),
    description: nullableOptionalString().refine((v) => v == null || v.length <= 2000, { message: 'String must contain at most 2000 character(s)' }),
    cover_image_url: z.preprocess((value) => value === null ? undefined : value, z.string().url().optional()),
    faqs: z.array(
      z.object({
        question: z.string().min(1).max(300),
        answer: z.string().min(1).max(2000),
      })
    ).optional(),
    subjects: z.array(z.string()).optional(),
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
    description: z.preprocess((value) => value === null ? undefined : value, z.string().max(2000).optional()),
    cover_image_url: nullableOptionalUrl(),
    teacher_ids: z.preprocess((value) => value === null ? undefined : value, z.array(z.string().uuid()).optional()),
    faqs: z.preprocess((value) => value === null ? undefined : value, z.array(
      z.object({
        question: z.string().min(1).max(300),
        answer: z.string().min(1).max(2000),
      })
    ).optional()),
    subjects: z.preprocess((value) => value === null ? undefined : value, z.array(z.string()).optional()),
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

import { z } from 'zod';

export const createExamSchema = z.object({
  body: z.object({
    name: z.string().min(2).max(200),
    subject: z.string().max(100).optional(),
    date: z.string().min(4),
    duration: z.number().int().positive().optional(),
    totalMarks: z.number().int().positive(),
    batchId: z.string().uuid().optional(),
  }),
});

export const updateExamStatusSchema = z.object({
  body: z.object({
    status: z.enum(['upcoming', 'completed']),
  }),
});

export type CreateExamInput = z.infer<typeof createExamSchema>['body'];

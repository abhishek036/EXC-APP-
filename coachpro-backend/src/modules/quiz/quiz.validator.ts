import { z } from 'zod';

export const createQuizSchema = z.object({
  batch_id: z.string().uuid(),
  title: z.string().min(1).max(200),
  subject: z.string().max(100).optional(),
  time_limit_min: z.number().int().positive().optional(),
  questions: z.array(
    z.object({
      question_text: z.string().min(1),
      image_url: z.string().url().optional(),
      option_a: z.string().min(1),
      option_b: z.string().min(1),
      option_c: z.string().min(1),
      option_d: z.string().min(1),
      correct_option: z.enum(['A', 'B', 'C', 'D']),
      marks: z.number().int().positive().optional(),
      order_index: z.number().int().nonnegative().optional(),
    })
  ).min(1),
});

export const updateQuizSchema = z.object({
  title: z.string().min(1).max(200).optional(),
  subject: z.string().max(100).optional(),
  time_limit_min: z.number().int().positive().optional(),
});

export const submitQuizSchema = z.object({
  answers: z.record(z.string().uuid(), z.enum(['A', 'B', 'C', 'D'])),
});

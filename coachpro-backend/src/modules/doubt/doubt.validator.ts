import { z } from 'zod';

export const createDoubtSchema = z.object({
  body: z.object({
    batch_id: z.string().uuid(),
    question_text: z.string().min(1).max(2000),
    question_img: z.string().url().nullable().optional(),
  }),
});

export const answerDoubtSchema = z.object({
  body: z.object({
    answer_text: z.string().min(1).max(2000),
    answer_img: z.string().url().nullable().optional(),
  }),
});

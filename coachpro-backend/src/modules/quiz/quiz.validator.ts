import { z } from 'zod';

const assessmentTypeSchema = z.enum(['QUIZ', 'TEST']);

export const createQuizSchema = z.object({
  body: z.object({
    batch_id: z.string().uuid(),
    assessment_type: assessmentTypeSchema.optional(),
    title: z.string().min(1).max(200),
    subject: z.string().max(100).optional(),
    time_limit_min: z.number().int().positive().optional(),
    scheduled_at: z.string().datetime().optional(),
    negative_marking: z.number().min(0).max(10).optional(),
    allow_retry: z.boolean().optional(),
    show_instant_result: z.boolean().optional(),
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
  }).superRefine((body, ctx) => {
    const assessmentType = body.assessment_type ?? 'QUIZ';
    const questionCount = body.questions.length;

    if (assessmentType === 'TEST') {
      if (!body.time_limit_min || body.time_limit_min <= 0) {
        ctx.addIssue({
          code: z.ZodIssueCode.custom,
          path: ['time_limit_min'],
          message: 'TEST mode requires a strict time limit',
        });
      }
    }
  }),
});

export const updateQuizSchema = z.object({
  body: z.object({
    batch_id: z.string().uuid().optional(),
    assessment_type: assessmentTypeSchema.optional(),
    title: z.string().min(1).max(200).optional(),
    subject: z.string().max(100).optional(),
    time_limit_min: z.number().int().positive().optional(),
    scheduled_at: z.string().datetime().optional(),
    negative_marking: z.number().min(0).max(10).optional(),
    allow_retry: z.boolean().optional(),
    show_instant_result: z.boolean().optional(),
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
    ).min(1).optional(),
  }),
});

export const submitQuizSchema = z.object({
  body: z.object({
    answers: z.record(z.string().uuid(), z.enum(['A', 'B', 'C', 'D'])),
  }),
});

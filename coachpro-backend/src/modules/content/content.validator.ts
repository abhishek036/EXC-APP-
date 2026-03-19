import { z } from 'zod';

export const createNoteSchema = z.object({
  body: z.object({
    title: z.string().min(2).max(200),
    subject: z.string().max(100).optional(),
    batch_id: z.string().uuid(),
    file_url: z.string().url(),
    file_type: z.string().optional(),
    file_size_kb: z.number().optional()
  })
});

export const createAssignmentSchema = z.object({
  body: z.object({
    title: z.string().min(2).max(200),
    description: z.string().optional(),
    batch_id: z.string().uuid(),
    due_date: z.string().datetime().optional(),
    file_url: z.string().url().optional()
  })
});

export const createDoubtSchema = z.object({
  body: z.object({
    batch_id: z.string().uuid(),
    question_text: z.string().min(5),
    question_img: z.string().url().optional()
  })
});

export const respondDoubtSchema = z.object({
    body: z.object({
      answer_text: z.string().min(2).optional(),
      answer_img: z.string().url().optional(),
      status: z.enum(['pending', 'resolved']).optional()
    })
});

export type CreateNoteInput = z.infer<typeof createNoteSchema>['body'];
export type CreateAssignmentInput = z.infer<typeof createAssignmentSchema>['body'];
export type CreateDoubtInput = z.infer<typeof createDoubtSchema>['body'];
export type RespondDoubtInput = z.infer<typeof respondDoubtSchema>['body'];

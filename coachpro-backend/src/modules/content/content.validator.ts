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
    file_url: z.string().url().optional(),
    subject: z.string().max(100).optional(),
  })
});

export const submitAssignmentSchema = z.object({
  body: z.object({
    file_url: z.string().url().optional(),
    submission_text: z.string().max(4000).optional(),
  }).refine((value) => {
    return !!(value.file_url || value.submission_text?.trim());
  }, {
    message: 'Either file_url or submission_text is required',
    path: ['file_url'],
  }),
});

export const reviewAssignmentSubmissionSchema = z.object({
  body: z.object({
    status: z.enum(['submitted', 'reviewed']).optional(),
    marks_obtained: z.number().min(0).max(1000).optional(),
    remarks: z.string().max(4000).optional(),
  }),
});

export const createDoubtSchema = z.object({
  body: z.object({
    batch_id: z.string().uuid(),
    question_text: z.string().min(5),
    question_img: z.string().url().optional(),
    subject: z.string().max(100).optional(),
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
export type SubmitAssignmentInput = z.infer<typeof submitAssignmentSchema>['body'];
export type ReviewAssignmentSubmissionInput = z.infer<typeof reviewAssignmentSubmissionSchema>['body'];
export type CreateDoubtInput = z.infer<typeof createDoubtSchema>['body'];
export type RespondDoubtInput = z.infer<typeof respondDoubtSchema>['body'];

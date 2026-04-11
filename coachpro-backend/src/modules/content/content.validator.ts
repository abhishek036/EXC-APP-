import { z } from 'zod';

const assignmentFileTypes = ['pdf', 'jpg', 'jpeg', 'png', 'doc', 'docx'] as const;
const noteFileTypes = ['pdf', 'image', 'video', 'zip', 'doc', 'docx', 'ppt', 'pptx', 'other'] as const;
const youtubeVisibilityTypes = ['unlisted', 'public'] as const;

const extractExtension = (value?: string | null): string | null => {
  const raw = (value ?? '').trim();
  if (!raw) return null;

  let pathCandidate = raw;
  try {
    pathCandidate = new URL(raw).pathname;
  } catch {
    pathCandidate = raw;
  }

  const withoutQuery = pathCandidate.split(/[?#]/)[0] ?? '';
  const fileName = withoutQuery.split('/').filter(Boolean).pop() ?? '';
  if (!fileName || !fileName.includes('.')) return null;

  const ext = fileName.split('.').pop()?.trim().toLowerCase() ?? '';
  if (!ext || !/^[a-z0-9]+$/.test(ext)) return null;
  return ext;
};

export const createNoteSchema = z.object({
  body: z.object({
    title: z.string().min(2).max(200),
    subject: z.string().max(100).optional(),
    batch_id: z.string().uuid(),
    description: z.string().max(4000).optional(),
    chapter_title: z.string().max(150).optional(),
    chapter_order: z.number().int().min(0).max(999).optional(),
    file_url: z.string().url().optional(),
    file_type: z.enum(noteFileTypes).optional(),
    youtube_visibility: z.enum(youtubeVisibilityTypes).optional(),
    file_size_kb: z.number().int().min(1).max(512 * 1024).optional(),
    note_files: z.array(z.object({
      file_url: z.string().url(),
      file_name: z.string().max(255).optional(),
      file_type: z.enum(noteFileTypes).optional(),
      mime_type: z.string().max(120).optional(),
      file_size_kb: z.number().int().min(1).max(512 * 1024).optional(),
      storage_provider: z.enum(['cloudinary', 'supabase', 'b2', 'external']).optional(),
      storage_path: z.string().max(1000).optional(),
      file_hash: z.string().max(80).optional(),
      version_no: z.number().int().min(1).max(100).optional(),
    })).max(20).optional(),
  }).superRefine((value, ctx) => {
    const hasSingle = !!value.file_url;
    const hasList = Array.isArray(value.note_files) && value.note_files.length > 0;
    if (!hasSingle && !hasList) {
      ctx.addIssue({
        code: z.ZodIssueCode.custom,
        message: 'At least one note file is required',
        path: ['file_url'],
      });
    }
  })
});

export const updateNoteSchema = z.object({
  params: z.object({
    noteId: z.string().uuid(),
  }),
  body: z.object({
    title: z.string().min(2).max(200).optional(),
    subject: z.string().max(100).optional(),
    batch_id: z.string().uuid().optional(),
    description: z.string().max(4000).optional(),
    chapter_title: z.string().max(150).optional(),
    chapter_order: z.number().int().min(0).max(999).optional(),
    file_url: z.string().url().optional(),
    file_type: z.enum(noteFileTypes).optional(),
    youtube_visibility: z.enum(youtubeVisibilityTypes).optional(),
    file_size_kb: z.number().int().min(1).max(512 * 1024).optional(),
  }),
});

export const noteBookmarkSchema = z.object({
  params: z.object({
    noteId: z.string().uuid(),
  }),
});

export const noteFileAccessSchema = z.object({
  params: z.object({
    noteId: z.string().uuid(),
    fileId: z.string().uuid(),
  }),
  query: z.object({
    action: z.enum(['view', 'download']).optional(),
    token: z.string().optional(),
  }),
});

export const createAssignmentSchema = z.object({
  body: z.object({
    title: z.string().min(2).max(200),
    description: z.string().optional(),
    instructions: z.string().max(4000).optional(),
    batch_id: z.string().uuid(),
    due_date: z.string().datetime().optional(),
    max_marks: z.number().positive().max(1000).optional(),
    file_url: z.string().url().optional(),
    question_file_url: z.string().url().optional(),
    subject: z.string().max(100).optional(),
    allow_late_submission: z.boolean().optional(),
    late_grace_minutes: z.number().int().min(0).max(60 * 24 * 30).optional(),
    max_attempts: z.number().int().min(1).max(20).optional(),
    allow_text_submission: z.boolean().optional(),
    allow_file_submission: z.boolean().optional(),
    max_file_size_kb: z.number().int().min(50).max(200 * 1024).optional(),
    allowed_file_types: z.array(z.enum(assignmentFileTypes)).min(1).max(6).optional(),
    correct_solution_url: z.string().url().optional(),
  }).superRefine((value, ctx) => {
    if (value.allow_text_submission === false && value.allow_file_submission === false) {
      ctx.addIssue({
        code: z.ZodIssueCode.custom,
        message: 'At least one submission mode must be enabled',
        path: ['allow_text_submission'],
      });
    }

    if (value.due_date) {
      const dueDate = new Date(value.due_date);
      if (Number.isFinite(dueDate.getTime()) && dueDate.getTime() <= Date.now()) {
        ctx.addIssue({
          code: z.ZodIssueCode.custom,
          message: 'Due date must be in the future',
          path: ['due_date'],
        });
      }
    }
  })
});

export const updateAssignmentSchema = z.object({
  params: z.object({
    assignmentId: z.string().uuid(),
  }),
  body: z.object({
    title: z.string().min(2).max(200).optional(),
    description: z.string().optional(),
    instructions: z.string().max(4000).optional(),
    batch_id: z.string().uuid().optional(),
    due_date: z.string().datetime().optional(),
    max_marks: z.number().positive().max(1000).optional(),
    file_url: z.string().url().optional(),
    question_file_url: z.string().url().optional(),
    subject: z.string().max(100).optional(),
    allow_late_submission: z.boolean().optional(),
    late_grace_minutes: z.number().int().min(0).max(60 * 24 * 30).optional(),
    max_attempts: z.number().int().min(1).max(20).optional(),
    allow_text_submission: z.boolean().optional(),
    allow_file_submission: z.boolean().optional(),
    max_file_size_kb: z.number().int().min(50).max(200 * 1024).optional(),
    allowed_file_types: z.array(z.enum(assignmentFileTypes)).min(1).max(6).optional(),
    correct_solution_url: z.string().url().optional(),
  }).superRefine((value, ctx) => {
    if (value.allow_text_submission === false && value.allow_file_submission === false) {
      ctx.addIssue({
        code: z.ZodIssueCode.custom,
        message: 'At least one submission mode must be enabled',
        path: ['allow_text_submission'],
      });
    }

    if (value.due_date) {
      const dueDate = new Date(value.due_date);
      if (Number.isFinite(dueDate.getTime()) && dueDate.getTime() <= Date.now()) {
        ctx.addIssue({
          code: z.ZodIssueCode.custom,
          message: 'Due date must be in the future',
          path: ['due_date'],
        });
      }
    }
  }),
});

export const assignmentIdParamSchema = z.object({
  params: z.object({
    assignmentId: z.string().uuid(),
  }),
});

export const submitAssignmentSchema = z.object({
  body: z.object({
    file_url: z.string().url().optional(),
    submission_text: z.string().max(4000).optional(),
    is_draft: z.boolean().optional(),
    file_name: z.string().max(255).optional(),
    file_mime_type: z.string().max(120).optional(),
    file_size_kb: z.number().int().min(1).max(200 * 1024).optional(),
    file_ext: z.enum(assignmentFileTypes).optional(),
    scan_status: z.enum(['pending', 'clean', 'infected']).optional(),
  }).superRefine((value, ctx) => {
    const text = value.submission_text?.trim() ?? '';
    const isDraft = value.is_draft === true;
    if (!isDraft && !value.file_url && !text) {
      ctx.addIssue({
        code: z.ZodIssueCode.custom,
        message: 'Either file_url or submission_text is required',
        path: ['file_url'],
      });
    }

    if (value.file_url) {
      const ext = (value.file_ext ?? extractExtension(value.file_name ?? value.file_url) ?? '').toLowerCase();
      if (ext && !assignmentFileTypes.includes(ext as typeof assignmentFileTypes[number])) {
        ctx.addIssue({
          code: z.ZodIssueCode.custom,
          message: 'Unsupported file type for assignment submission',
          path: ['file_ext'],
        });
      }
    }
  }),
});

export const reviewAssignmentSubmissionSchema = z.object({
  body: z.object({
    status: z.enum(['submitted', 'late_submission', 'evaluated']).optional(),
    marks_obtained: z.number().min(0).max(1000).optional(),
    remarks: z.string().max(4000).optional(),
    feedback_text: z.string().max(4000).optional(),
    feedback_audio_url: z.string().url().optional(),
    annotated_file_url: z.string().url().optional(),
    rubric_json: z.record(z.string(), z.any()).optional(),
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
export type UpdateNoteInput = z.infer<typeof updateNoteSchema>['body'];
export type NoteBookmarkInput = z.infer<typeof noteBookmarkSchema>['params'];
export type NoteFileAccessInput = z.infer<typeof noteFileAccessSchema>['params'] & z.infer<typeof noteFileAccessSchema>['query'];
export type CreateAssignmentInput = z.infer<typeof createAssignmentSchema>['body'];
export type UpdateAssignmentInput = z.infer<typeof updateAssignmentSchema>['body'];
export type SubmitAssignmentInput = z.infer<typeof submitAssignmentSchema>['body'];
export type ReviewAssignmentSubmissionInput = z.infer<typeof reviewAssignmentSubmissionSchema>['body'];
export type CreateDoubtInput = z.infer<typeof createDoubtSchema>['body'];
export type RespondDoubtInput = z.infer<typeof respondDoubtSchema>['body'];

import { z } from 'zod';

export const createLectureSchema = z.object({
  batch_id: z.string().uuid(),
  title: z.string().min(1).max(200),
  description: z.string().max(1000).optional(),
  youtube_url: z.string().url(),
  lecture_type: z.enum(['live', 'recorded']).optional(),
  scheduled_at: z.string().datetime().optional(),
});

export const updateLectureSchema = z.object({
  title: z.string().min(1).max(200).optional(),
  description: z.string().max(1000).optional(),
  youtube_url: z.string().url().optional(),
  lecture_type: z.enum(['live', 'recorded']).optional(),
  scheduled_at: z.string().datetime().optional(),
  is_active: z.boolean().optional(),
});

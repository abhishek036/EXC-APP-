import { z } from 'zod';

export const createAnnouncementSchema = z.object({
  body: z.object({
    title: z.string().min(2).max(200),
    body: z.string().min(2),
    category: z.string().max(30).optional(),
    pinned: z.boolean().optional(),
  }),
});

export const updateAnnouncementSchema = z.object({
  body: z.object({
    title: z.string().min(2).max(200).optional(),
    body: z.string().min(2).optional(),
    category: z.string().max(30).optional(),
    pinned: z.boolean().optional(),
  }),
});

export type CreateAnnouncementInput = z.infer<typeof createAnnouncementSchema>['body'];
export type UpdateAnnouncementInput = z.infer<typeof updateAnnouncementSchema>['body'];

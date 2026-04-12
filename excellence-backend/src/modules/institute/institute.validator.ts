import { z } from 'zod';

export const updateInstituteSchema = z.object({
  body: z.object({
    name: z.string().min(2).max(200).optional(),
    logo_url: z.string().url().optional(),
    address: z.string().optional(),
    phone: z.string().min(10).max(15).optional(),
    email: z.string().email().optional(),
    website: z.string().url().optional(),
    primary_color: z.string().regex(/^#([A-Fa-f0-9]{6}|[A-Fa-f0-9]{3})$/, 'Invalid hex color').optional(),
    settings: z.any().optional(), // Json configuration
  })
});

export type UpdateInstituteInput = z.infer<typeof updateInstituteSchema>['body'];

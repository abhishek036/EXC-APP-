import { z } from 'zod';

export const createLeadSchema = z.object({
  body: z.object({
    name: z.string().min(2).max(200),
    phone: z.string().min(10).max(15),
    status: z.string().max(30).optional(),
  }),
});

export const updateLeadStatusSchema = z.object({
  body: z.object({
    status: z.string().min(2).max(30),
  }),
});

export type CreateLeadInput = z.infer<typeof createLeadSchema>['body'];

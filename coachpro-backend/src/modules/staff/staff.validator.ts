import { z } from 'zod';

export const createStaffSchema = z.object({
  body: z.object({
    name: z.string().min(2).max(200),
    role: z.string().max(100).optional(),
    phone: z.string().min(10).max(15).optional(),
    salary: z.number().nonnegative().optional(),
    status: z.string().max(30).optional(),
  }),
});

export const createPayrollSchema = z.object({
  body: z.object({
    staffId: z.string().uuid(),
    amount: z.number().nonnegative(),
    type: z.string().max(30),
    month: z.string().max(30).optional(),
    date: z.string().datetime().optional(),
  }),
});

export type CreateStaffInput = z.infer<typeof createStaffSchema>['body'];
export type CreatePayrollInput = z.infer<typeof createPayrollSchema>['body'];

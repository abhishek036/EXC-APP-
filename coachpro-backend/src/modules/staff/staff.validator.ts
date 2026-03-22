import { z } from 'zod';

const phoneSchema = z
  .string()
  .trim()
  .regex(/^\d{10,15}$/, 'Phone must be 10 to 15 digits');

export const createStaffSchema = z.object({
  body: z.object({
    name: z.string().min(2).max(200),
    role: z.string().max(100).optional(),
    phone: phoneSchema.optional(),
    salary: z.number().nonnegative().optional(),
    status: z.string().max(30).optional(),
  }),
});

export const updateStaffSchema = z.object({
  body: z
    .object({
      name: z.string().min(2).max(200).optional(),
      role: z.string().max(100).optional(),
      phone: phoneSchema.optional(),
      salary: z.number().nonnegative().optional(),
      status: z.string().max(30).optional(),
    })
    .refine((value) => Object.keys(value).length > 0, {
      message: 'At least one field must be provided for update',
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
export type UpdateStaffInput = z.infer<typeof updateStaffSchema>['body'];
export type CreatePayrollInput = z.infer<typeof createPayrollSchema>['body'];

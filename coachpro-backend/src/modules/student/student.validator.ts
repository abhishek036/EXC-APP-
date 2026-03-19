import { z } from 'zod';

export const createStudentSchema = z.object({
  body: z.object({
    name: z.string().min(2).max(200),
    phone: z.string().min(10).max(15).optional(),
    dob: z.string().datetime().optional(), // Or custom date format
    gender: z.enum(['Male', 'Female', 'Other']).optional(),
    address: z.string().optional(),
    blood_group: z.string().max(5).optional(),
    prev_institute: z.string().max(200).optional(),
    // Allow optionally passing parent details during student creation
    parent_name: z.string().min(2).max(200).optional(),
    parent_phone: z.string().min(10).max(15).optional(),
    parent_relation: z.string().max(20).optional(),
    batch_ids: z.array(z.string()).optional(),
    lead_id: z.string().uuid().optional(),
  })
});

export const updateStudentSchema = createStudentSchema.deepPartial();

export type CreateStudentInput = z.infer<typeof createStudentSchema>['body'];
export type UpdateStudentInput = z.infer<typeof updateStudentSchema>['body'];

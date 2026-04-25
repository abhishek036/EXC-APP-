import { z } from 'zod';

export const createStudentSchema = z.object({
  body: z.object({
    name: z.string().min(2).max(200),
    phone: z.string().min(10).max(15).optional(),
    dob: z.union([z.string().datetime(), z.literal(''), z.null()]).optional(),
    gender: z.union([z.enum(['Male', 'Female', 'Other']), z.literal(''), z.null()]).optional(),
    address: z.union([z.string(), z.literal(''), z.null()]).optional(),
    blood_group: z.union([z.string().max(5), z.literal(''), z.null()]).optional(),
    prev_institute: z.union([z.string().max(200), z.literal(''), z.null()]).optional(),
    student_code: z.union([z.string(), z.literal(''), z.null()]).optional(),
    // Allow optionally passing parent details during student creation
    parent_name: z.union([z.string().max(200), z.literal(''), z.null()]).optional(),
    parent_phone: z.union([z.string().min(10).max(20), z.literal(''), z.null()]).optional(),
    parent_relation: z.union([z.string().max(20), z.literal(''), z.null()]).optional(),
    batch_ids: z.array(z.string()).optional(),
    lead_id: z.string().uuid().optional(),
  })
});

export const updateStudentSchema = createStudentSchema.deepPartial();

export type CreateStudentInput = z.infer<typeof createStudentSchema>['body'];
export type UpdateStudentInput = z.infer<typeof updateStudentSchema>['body'];

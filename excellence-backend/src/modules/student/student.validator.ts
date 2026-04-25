import { z } from 'zod';

export const createStudentSchema = z.object({
  body: z.object({
    name: z.string().min(2).max(200),
    phone: z.string().min(10).max(15).optional(),
    dob: z.preprocess((val) => (val === '' ? null : val), z.string().nullish()),
    gender: z.preprocess((val) => (val === '' ? null : val), z.enum(['Male', 'Female', 'Other']).nullish()),
    address: z.preprocess((val) => (val === '' ? null : val), z.string().max(500).nullish()),
    blood_group: z.preprocess((val) => (val === '' ? null : val), z.string().max(10).nullish()),
    prev_institute: z.preprocess((val) => (val === '' ? null : val), z.string().max(200).nullish()),
    student_code: z.preprocess((val) => (val === '' ? null : val), z.string().max(50).nullish()),
    // Allow optionally passing parent details during student creation
    parent_name: z.preprocess((val) => (val === '' ? null : val), z.string().max(200).nullish()),
    parent_phone: z.preprocess((val) => (val === '' ? null : val), z.string().min(10).max(20).nullish()),
    parent_relation: z.preprocess((val) => (val === '' ? null : val), z.string().max(50).nullish()),
    batch_ids: z.array(z.string()).optional(),
    lead_id: z.string().uuid().optional(),
  })
});

export const updateStudentSchema = createStudentSchema.deepPartial();

export type CreateStudentInput = z.infer<typeof createStudentSchema>['body'];
export type UpdateStudentInput = z.infer<typeof updateStudentSchema>['body'];

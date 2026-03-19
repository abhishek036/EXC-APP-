import { z } from 'zod';

export const createTeacherSchema = z.object({
  body: z.object({
    name: z.string().min(2).max(200),
    phone: z.string().min(10).max(15).optional(),
    email: z.string().email().optional(),
    qualification: z.string().optional(),
    subjects: z.array(z.string()).optional(),
  })
});

export const updateTeacherSchema = createTeacherSchema.deepPartial();

export type CreateTeacherInput = z.infer<typeof createTeacherSchema>['body'];
export type UpdateTeacherInput = z.infer<typeof updateTeacherSchema>['body'];

import { z } from 'zod';

const nullableOptionalString = () => z.preprocess((value) => value === null ? undefined : value, z.string().optional());

const permissionsSchema = z.object({
  can_edit_attendance: z.boolean().optional(),
  can_see_fee_data: z.boolean().optional(),
  can_upload_study_material: z.boolean().optional(),
  can_create_exams: z.boolean().optional(),
  can_manage_students: z.boolean().optional(),
}).partial();

export const createTeacherSchema = z.object({
  body: z.object({
    name: z.string().min(2).max(200),
    phone: nullableOptionalString().refine((v) => v == null || (v.length >= 10 && v.length <= 15), { message: 'Phone must be between 10 and 15 characters' }),
    email: z.preprocess((value) => value === null ? undefined : value, z.string().email().optional()),
    qualification: nullableOptionalString(),
    subject: nullableOptionalString(),
    subjects: z.array(z.string()).optional(),
    salary: z.union([z.number(), z.string()]).optional(),
    revenue_share: z.union([z.number(), z.string()]).optional(),
    permissions: permissionsSchema.optional(),
  })
});

export const updateTeacherSchema = createTeacherSchema.deepPartial();

export const updateTeacherSettingsSchema = z.object({
  body: z.object({
    permissions: permissionsSchema.optional(),
    salary: z.union([z.number(), z.string()]).optional(),
    revenue_share: z.union([z.number(), z.string()]).optional(),
  })
});

export const addTeacherFeedbackSchema = z.object({
  body: z.object({
    rating: z.number().min(1).max(5),
    comment: z.string().max(1000).optional(),
    student_name: z.string().max(200).optional(),
  })
});

export type CreateTeacherInput = z.infer<typeof createTeacherSchema>['body'];
export type UpdateTeacherInput = z.infer<typeof updateTeacherSchema>['body'];
export type UpdateTeacherSettingsInput = z.infer<typeof updateTeacherSettingsSchema>['body'];
export type AddTeacherFeedbackInput = z.infer<typeof addTeacherFeedbackSchema>['body'];

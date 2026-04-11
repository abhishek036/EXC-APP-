import { z } from 'zod';

const strongPasswordSchema = z
  .string()
  .min(8, 'Password must be at least 8 characters')
  .max(72, 'Password must be at most 72 characters')
  .regex(/[A-Z]/, 'Password must include at least one uppercase letter')
  .regex(/[a-z]/, 'Password must include at least one lowercase letter')
  .regex(/\d/, 'Password must include at least one number')
  .regex(/[^A-Za-z\d]/, 'Password must include at least one special character');

const otpSchema = z.string().regex(/^\d{6}$/, 'OTP must be exactly 6 numeric digits');

export const sendOtpSchema = z.object({
  body: z.object({
    phone: z.string().min(10).max(15, 'Invalid phone number format'),
    joinCode: z.string().optional(),
    role: z.enum(['admin', 'super_admin', 'sub_admin', 'teacher', 'student', 'parent']).optional(),
    purpose: z.enum(['login', 'password_reset']).default('login')
  })
});

export const verifyOtpSchema = z.object({
  body: z.object({
    phone: z.string().min(10).max(15, 'Invalid phone number format'),
    otp: otpSchema,
    joinCode: z.string().optional(),
    role: z.enum(['admin', 'super_admin', 'sub_admin', 'teacher', 'student', 'parent']).optional(),
    purpose: z.enum(['login', 'password_reset']).default('login')
  })
});

export const loginSchema = z.object({
  body: z.object({
    phone: z.string().min(10).max(15),
    password: z.string().min(6, 'Password must be at least 6 characters'),
    joinCode: z.string().optional()
  })
});

export const passwordChangeSchema = z.object({
  body: z.object({
    oldPassword: z.string(),
    newPassword: strongPasswordSchema,
  })
});

export const passwordResetSchema = z.object({
  body: z.object({
    phone: z.string().min(10).max(15),
    otp: otpSchema,
    newPassword: strongPasswordSchema,
    joinCode: z.string().optional(),
  })
});

export const updateMeSchema = z.object({
  body: z.object({
    name: z.string().min(2).max(200).optional(),
    email: z.string().email().optional(),
    // Phone changes are intentionally not supported yet (to avoid breaking login + uniqueness)
    phone: z.string().min(10).max(15).optional(),
  }).refine((v) => v.name != null || v.email != null || v.phone != null, {
    message: 'At least one field must be provided',
  }),
});

export type SendOtpInput = z.infer<typeof sendOtpSchema>['body'];
export type VerifyOtpInput = z.infer<typeof verifyOtpSchema>['body'];
export type LoginInput = z.infer<typeof loginSchema>['body'];
export type PasswordChangeInput = z.infer<typeof passwordChangeSchema>['body'];
export type PasswordResetInput = z.infer<typeof passwordResetSchema>['body'];
export type UpdateMeInput = z.infer<typeof updateMeSchema>['body'];

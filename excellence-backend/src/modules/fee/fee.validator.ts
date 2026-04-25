import { z } from 'zod';

export const defineFeeStructureSchema = z.object({
  body: z.object({
    batch_id: z.string().uuid(),
    monthly_fee: z.number().min(0),
    admission_fee: z.number().min(0).optional(),
    exam_fee: z.number().min(0).optional(),
    late_fee_amount: z.number().min(0).optional(),
    late_after_day: z.number().min(1).max(31).optional(),
    grace_days: z.number().min(0).optional()
  })
});

export const recordFeePaymentSchema = z.object({
  body: z.object({
    fee_record_id: z.string().uuid(),
    amount_paid: z.number().min(1),
    payment_mode: z.string().min(2), // cash, online, upi
    transaction_id: z.string().optional(),
    note: z.string().optional()
  })
});

export const generateMonthlyFeesSchema = z.object({
  body: z.object({
    batch_id: z.string().uuid(),
    month: z.number().min(1).max(12),
    year: z.number().min(2020),
    due_date: z.string().datetime().optional()
  })
});

export const submitFeeProofSchema = z.object({
  body: z.object({
    fee_record_id: z.string().uuid(),
    amount: z.number().min(1).optional(),
    screenshot_url: z.string().min(10),
    note: z.string().max(1000).optional(),
    whatsapp_notified: z.boolean().optional(),
  })
});

export const reviewFeePaymentSchema = z.object({
  body: z.object({
    note: z.string().max(1000).optional(),
    rejection_reason: z.string().max(1000).optional(),
  })
});

export const adjustFeeRecordSchema = z.object({
  body: z.object({
    fee_record_id: z.string().uuid(),
    adjustment_type: z.enum(['increase', 'decrease']),
    amount: z.number().positive(),
    reason: z.string().min(3).max(1000),
    note: z.string().max(1000).optional(),
  }),
});

export const sendFeeReminderSchema = z.object({
  params: z.object({
    recordId: z.string().uuid(),
  }),
});

export type DefineFeeStructureInput = z.infer<typeof defineFeeStructureSchema>['body'];
export type RecordFeePaymentInput = z.infer<typeof recordFeePaymentSchema>['body'];
export type GenerateMonthlyFeesInput = z.infer<typeof generateMonthlyFeesSchema>['body'];
export type SubmitFeeProofInput = z.infer<typeof submitFeeProofSchema>['body'];
export type ReviewFeePaymentInput = z.infer<typeof reviewFeePaymentSchema>['body'];
export type AdjustFeeRecordInput = z.infer<typeof adjustFeeRecordSchema>['body'];

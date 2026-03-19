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

export type DefineFeeStructureInput = z.infer<typeof defineFeeStructureSchema>['body'];
export type RecordFeePaymentInput = z.infer<typeof recordFeePaymentSchema>['body'];
export type GenerateMonthlyFeesInput = z.infer<typeof generateMonthlyFeesSchema>['body'];

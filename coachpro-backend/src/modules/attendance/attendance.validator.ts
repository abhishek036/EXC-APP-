import { z } from 'zod';

export const markAttendanceSchema = z.object({
  body: z.object({
    batch_id: z.string().uuid(),
    session_date: z.string(), // Simple YYYY-MM-DD format
    subject: z.string().optional(),
    notify_parents: z.boolean().optional().default(true),
    records: z.array(z.object({
       student_id: z.string().uuid(),
       status: z.enum(['present', 'absent', 'late', 'excused']),
       note: z.string().optional()
    }))
  })
});

export const reportIssueSchema = z.object({
  body: z.object({
    note: z.string().min(5).max(500)
  })
});

export type MarkAttendanceInput = z.infer<typeof markAttendanceSchema>['body'];
export type ReportIssueInput = z.infer<typeof reportIssueSchema>['body'];

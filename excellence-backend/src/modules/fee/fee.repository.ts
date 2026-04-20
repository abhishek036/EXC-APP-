import { prisma } from '../../server';
import { Prisma } from '@prisma/client';
import {
    DefineFeeStructureInput,
    RecordFeePaymentInput,
    GenerateMonthlyFeesInput,
    SubmitFeeProofInput,
    AdjustFeeRecordInput,
} from './fee.validator';
import { ApiError } from '../../middleware/error.middleware';
import { Logger } from '../../utils/logger';

type FeeStatus = 'unpaid' | 'pending_verification' | 'paid' | 'rejected';
type PaymentStatus = 'pending_verification' | 'approved' | 'rejected' | 'paid';

const APPROVED_PAYMENT_STATUSES: PaymentStatus[] = ['approved', 'paid'];

export class FeeRepository {
    private canViewAmounts(role?: string): boolean {
        const normalized = (role ?? '').toString().trim().toLowerCase();
        return normalized !== 'sub_admin';
    }

    private async appendEvent(
        tx: Prisma.TransactionClient,
        params: {
            instituteId: string;
            feeRecordId: string;
            paymentId?: string | null;
            actorId?: string | null;
            action: string;
            fromStatus?: string | null;
            toStatus?: string | null;
            meta?: Prisma.JsonObject;
        },
    ) {
        await tx.feePaymentEvent.create({
            data: {
                institute_id: params.instituteId,
                fee_record_id: params.feeRecordId,
                payment_id: params.paymentId ?? null,
                actor_id: params.actorId ?? null,
                action: params.action,
                from_status: params.fromStatus ?? null,
                to_status: params.toStatus ?? null,
                meta: params.meta,
            },
        });
    }

    private async getApprovedPaidAmount(
        tx: Prisma.TransactionClient,
        instituteId: string,
        feeRecordId: string,
    ): Promise<number> {
        const rows = await tx.feePayment.findMany({
            where: {
                institute_id: instituteId,
                fee_record_id: feeRecordId,
                status: { in: APPROVED_PAYMENT_STATUSES },
            },
            select: { amount_paid: true },
        });
        return rows.reduce((sum, row) => sum + Number(row.amount_paid), 0);
    }

    private async getPendingPaymentCount(
        tx: Prisma.TransactionClient,
        instituteId: string,
        feeRecordId: string,
    ): Promise<number> {
        return tx.feePayment.count({
            where: {
                institute_id: instituteId,
                fee_record_id: feeRecordId,
                status: 'pending_verification',
            },
        });
    }

    private resolveFeeStatus(params: {
        paidAmount: number;
        finalAmount: number;
        pendingCount: number;
        hasRejectedAttempt?: boolean;
    }): FeeStatus {
        if (params.paidAmount >= params.finalAmount) return 'paid';
        if (params.pendingCount > 0) return 'pending_verification';
        if (params.hasRejectedAttempt) return 'rejected';
        return 'unpaid';
    }

    private redactAmounts<T extends Record<string, any>>(records: T[]): T[] {
        return records.map((record) => {
            const next = { ...record } as Record<string, any>;
            delete next.total_amount;
            delete next.discount_amount;
            delete next.late_fee;
            delete next.final_amount;
            delete next.paid_amount;

            if (Array.isArray(next.payments)) {
                next.payments = next.payments.map((payment: Record<string, any>) => {
                    const p = { ...payment };
                    delete p.amount_paid;
                    return p;
                });
            }

            return next as T;
        });
    }

  async getFeeStructure(batchId: string, instituteId: string) {
    return prisma.feeStructure.findFirst({
      where: { batch_id: batchId, institute_id: instituteId }
    });
  }

  // Proper implementation without upsert by non-unique
  async setFeeStructure(instituteId: string, data: DefineFeeStructureInput) {
      const existing = await this.getFeeStructure(data.batch_id, instituteId);
      
      const payload = {
          batch_id: data.batch_id,
          institute_id: instituteId,
          monthly_fee: new Prisma.Decimal(data.monthly_fee),
          admission_fee: data.admission_fee ? new Prisma.Decimal(data.admission_fee) : new Prisma.Decimal(0),
          exam_fee: data.exam_fee ? new Prisma.Decimal(data.exam_fee) : new Prisma.Decimal(0),
          late_fee_amount: data.late_fee_amount ? new Prisma.Decimal(data.late_fee_amount) : new Prisma.Decimal(0),
          late_after_day: data.late_after_day || 10,
          grace_days: data.grace_days || 0
      };

      if (existing) {
          return prisma.feeStructure.update({
              where: { id: existing.id },
              data: payload
          });
      } else {
          return prisma.feeStructure.create({
              data: payload
          });
      }
  }

    async autoSyncStudentFees(instituteId: string, studentId: string) {
        const studentBatches = await prisma.studentBatch.findMany({
            where: { student_id: studentId, institute_id: instituteId, is_active: true },
        });

        const now = new Date();
        const currentMonth = now.getMonth() + 1;
        const currentYear = now.getFullYear();

        for (const sb of studentBatches) {
            const structure = await prisma.feeStructure.findFirst({
                where: { batch_id: sb.batch_id, institute_id: instituteId },
            });
            if (!structure) continue;

            const existing = await prisma.feeRecord.findFirst({
                where: { student_id: studentId, batch_id: sb.batch_id, month: currentMonth, year: currentYear },
                include: { payments: true },
            });

            if (!existing) {
                const defaultDueDate = new Date(now.getFullYear(), now.getMonth(), Number(structure.grace_days) || 10);
                const discounts = await prisma.feeDiscount.findMany({
                    where: {
                        student_id: studentId,
                        institute_id: instituteId,
                        OR: [{ valid_to: null }, { valid_to: { gte: now } }],
                    },
                });

                let totalDiscount = new Prisma.Decimal(0);
                discounts.forEach((d) => {
                    totalDiscount = totalDiscount.add(d.amount);
                });

                const totalAmount = structure.monthly_fee;
                const finalAmount = Prisma.Decimal.max(new Prisma.Decimal(0), totalAmount.minus(totalDiscount));

                await prisma.feeRecord.create({
                    data: {
                        institute_id: instituteId,
                        student_id: studentId,
                        batch_id: sb.batch_id,
                        month: currentMonth,
                        year: currentYear,
                        total_amount: totalAmount,
                        paid_amount: new Prisma.Decimal(0),
                        discount_amount: totalDiscount,
                        late_fee: new Prisma.Decimal(0),
                        final_amount: finalAmount,
                        due_date: defaultDueDate,
                        status: finalAmount.equals(new Prisma.Decimal(0)) ? 'paid' : 'unpaid',
                    },
                });
            } else {
                const paidAmount = Number(existing.paid_amount);
                if (existing.status === 'unpaid' && paidAmount === 0 && existing.payments.length === 0) {
                    if (!existing.total_amount.equals(structure.monthly_fee)) {
                        const totalAmount = structure.monthly_fee;
                        const finalAmount = Prisma.Decimal.max(
                            new Prisma.Decimal(0),
                            totalAmount.minus(existing.discount_amount ?? 0).plus(existing.late_fee ?? 0),
                        );
                        await prisma.feeRecord.update({
                            where: { id: existing.id },
                            data: {
                                total_amount: totalAmount,
                                final_amount: finalAmount,
                                status: finalAmount.equals(new Prisma.Decimal(0)) ? 'paid' : 'unpaid',
                            },
                        });
                    }
                }
                if (Number(existing.final_amount) === 0 && existing.status !== 'paid') {
                    await prisma.feeRecord.update({
                        where: { id: existing.id },
                        data: { status: 'paid' },
                    });
                }
            }
        }
    }

  async findFeeRecords(instituteId: string, batchId?: string, studentId?: string, month?: number, year?: number) {
            return this.findFeeRecordsByRole(instituteId, {
                batchId,
                studentId,
                month,
                year,
            });
    }

    async findFeeRecordsByRole(
            instituteId: string,
            query: {
                batchId?: string;
                studentId?: string;
                month?: number;
                year?: number;
                status?: string;
            },
            role?: string,
    ) {
            if (query.studentId) {
                try {
                    await this.autoSyncStudentFees(instituteId, query.studentId);
                } catch (error) {
                    Logger.error(
                        `[FeeRepository] autoSyncStudentFees failed for student ${query.studentId} in institute ${instituteId}`,
                        error,
                    );
                }
            } else if (query.batchId) {
                try {
                    const studentBatches = await prisma.studentBatch.findMany({
                        where: { batch_id: query.batchId, institute_id: instituteId, is_active: true }
                    });
                    for (const sb of studentBatches) {
                        try {
                            await this.autoSyncStudentFees(instituteId, sb.student_id);
                        } catch (error) {
                            Logger.error(
                                `[FeeRepository] autoSyncStudentFees failed for student ${sb.student_id} in batch ${query.batchId}`,
                                error,
                            );
                        }
                    }
                } catch (error) {
                    Logger.error(
                        `[FeeRepository] autoSyncStudentFees failed while iterating batch ${query.batchId}`,
                        error,
                    );
                }
            }
      const where: Prisma.FeeRecordWhereInput = { institute_id: instituteId };
            if (query.batchId) where.batch_id = query.batchId;
            if (query.studentId) where.student_id = query.studentId;
            if (query.month) where.month = query.month;
            if (query.year) where.year = query.year;
            if (query.status) where.status = query.status;

            const records = await prisma.feeRecord.findMany({
         where,
         include: {
            student: { select: { name: true, phone: true } },
            batch: { select: { name: true } },
                        payments: {
                            select: {
                                id: true,
                                amount_paid: true,
                                payment_mode: true,
                                payment_channel: true,
                                status: true,
                                screenshot_url: true,
                                submitted_at: true,
                                approved_at: true,
                                rejection_reason: true,
                                note: true,
                                receipt_number: true,
                                receipt_url: true,
                            },
                            orderBy: { submitted_at: 'desc' },
                        },
         },
         orderBy: [{ year: 'desc' }, { month: 'desc' }]
      });

            if (!this.canViewAmounts(role)) {
                return this.redactAmounts(records);
            }

            return records;
  }

  async findFeeRecordById(recordId: string, instituteId: string) {
      return prisma.feeRecord.findFirst({
         where: { id: recordId, institute_id: instituteId }
      });
  }

  async getBatchStudents(batchId: string, instituteId: string) {
      return prisma.studentBatch.findMany({
          where: { batch_id: batchId, institute_id: instituteId, is_active: true }
      });
  }

  async createMonthlyFeeRecords(instituteId: string, data: GenerateMonthlyFeesInput, defaultDueDate: Date) {
      const structure = await this.getFeeStructure(data.batch_id, instituteId);
      if (!structure) throw new Error("Fee structure not defined for this batch");

      const students = await this.getBatchStudents(data.batch_id, instituteId);
      if (!students.length) return { generated: 0 };

      let generated = 0;
      for (const sb of students) {
          // Check if record exists
          const existing = await prisma.feeRecord.findFirst({
              where: { student_id: sb.student_id, batch_id: data.batch_id, month: data.month, year: data.year }
          });

          if (!existing) {
              // Check for student-specific discounts
              const discounts = await prisma.feeDiscount.findMany({
                  where: { 
                      student_id: sb.student_id, 
                      institute_id: instituteId,
                      OR: [
                          { valid_to: null },
                          { valid_to: { gte: new Date() } }
                      ]
                  }
              });

              let totalDiscount = new Prisma.Decimal(0);
              discounts.forEach(d => {
                  totalDiscount = totalDiscount.add(d.amount);
              });

              const totalAmount = structure.monthly_fee;
              const finalAmount = Prisma.Decimal.max(0, totalAmount.minus(totalDiscount));

              await prisma.feeRecord.create({
                 data: {
                    institute_id: instituteId,
                    student_id: sb.student_id,
                    batch_id: data.batch_id,
                    month: data.month,
                    year: data.year,
                    total_amount: totalAmount,
                          paid_amount: new Prisma.Decimal(0),
                    discount_amount: totalDiscount,
                    final_amount: finalAmount,
                    due_date: data.due_date ? new Date(data.due_date) : defaultDueDate,
                          status: 'unpaid'
                 }
              });
              generated++;
          }
      }
      return { generated };
  }

  async recordPayment(instituteId: string, userId: string, data: RecordFeePaymentInput) {
     return prisma.$transaction(async (tx) => {
         const record = await tx.feeRecord.findFirst({
             where: { id: data.fee_record_id, institute_id: instituteId }
         });

                 if (!record) throw new ApiError('Fee record not found', 404, 'NOT_FOUND');
                 if (Number(data.amount_paid) <= 0) {
                        throw new ApiError('Amount must be greater than zero', 400, 'INVALID_AMOUNT');
                 }

         const paymentCode = `REC-${Date.now().toString(36).toUpperCase()}`;
                 const now = new Date();
                 const fromStatus = record.status ?? 'unpaid';

         const payment = await tx.feePayment.create({
             data: {
                 institute_id: instituteId,
                 fee_record_id: record.id,
                                 student_id: record.student_id,
                                 batch_id: record.batch_id,
                 collected_by_id: userId,
                                 approved_by_id: userId,
                                 approved_at: now,
                 amount_paid: new Prisma.Decimal(data.amount_paid),
                 payment_mode: data.payment_mode,
                                 payment_channel: 'manual_qr',
                                 status: 'approved',
                 transaction_id: data.transaction_id,
                 note: data.note,
                                 receipt_number: paymentCode,
                                 submitted_at: now,
                                 paid_at: now,
             }
         });

                 const totalPaid = await this.getApprovedPaidAmount(tx, instituteId, record.id);
                 const pendingCount = await this.getPendingPaymentCount(tx, instituteId, record.id);
                 const finalAmount = Number(record.final_amount);
                 const status = this.resolveFeeStatus({
                        paidAmount: totalPaid,
                        finalAmount,
                        pendingCount,
                 });

         await tx.feeRecord.update({
             where: { id: record.id },
                         data: {
                                paid_amount: new Prisma.Decimal(totalPaid),
                                status,
                                approved_by_id: status === 'paid' ? userId : null,
                                approved_at: status === 'paid' ? now : null,
                         }
         });

                 await this.appendEvent(tx, {
                        instituteId,
                        feeRecordId: record.id,
                        paymentId: payment.id,
                        actorId: userId,
                        action: 'admin_payment_recorded',
                        fromStatus,
                        toStatus: status,
                        meta: {
                            amount: Number(data.amount_paid),
                            mode: data.payment_mode,
                        },
                 });

         return payment;
     });
  }

    async submitPaymentProof(instituteId: string, userId: string, data: SubmitFeeProofInput, role?: string) {
        return prisma.$transaction(async (tx) => {
            const record = await tx.feeRecord.findFirst({
                where: {
                    id: data.fee_record_id,
                    institute_id: instituteId,
                },
            });
            if (!record) throw new ApiError('Fee record not found', 404, 'NOT_FOUND');

            const normalizedRole = (role ?? '').toString().trim().toLowerCase();
            if (normalizedRole === 'parent') {
                const parent = await tx.parent.findFirst({
                    where: { user_id: userId, institute_id: instituteId },
                    select: { id: true },
                });
                if (!parent) throw new ApiError('Parent profile not found', 404, 'NOT_FOUND');

                const link = await tx.parentStudent.findFirst({
                    where: {
                        parent_id: parent.id,
                        student_id: record.student_id,
                    },
                    select: { id: true },
                });
                if (!link) {
                    throw new ApiError('Fee record not accessible for this parent', 403, 'FORBIDDEN');
                }
            } else {
                const student = await tx.student.findFirst({
                    where: { user_id: userId, institute_id: instituteId },
                    select: { id: true },
                });
                if (!student) throw new ApiError('Student not found', 404, 'NOT_FOUND');
                if (student.id !== record.student_id) {
                    throw new ApiError('Fee record not accessible for this student', 403, 'FORBIDDEN');
                }
            }

            const paidAmount = Number(record.paid_amount ?? 0);
            const finalAmount = Number(record.final_amount);
            const remainingAmount = Math.max(finalAmount - paidAmount, 0);
            if (remainingAmount <= 0) {
                throw new ApiError('Fee is already fully paid', 400, 'ALREADY_PAID');
            }

            const requestedAmount = Number(data.amount ?? remainingAmount);
            if (!Number.isFinite(requestedAmount) || requestedAmount <= 0) {
                throw new ApiError('Submitted amount must be greater than zero', 400, 'INVALID_AMOUNT');
            }

            const allowPartialProofPayments = (process.env.ALLOW_PARTIAL_QR_PROOF || 'false').toLowerCase() === 'true';
            if (allowPartialProofPayments && requestedAmount > remainingAmount) {
                throw new ApiError('Submitted amount exceeds remaining amount', 400, 'AMOUNT_EXCEEDS_DUE');
            }

            const effectiveAmount = allowPartialProofPayments ? requestedAmount : remainingAmount;

            const fromStatus = record.status ?? 'unpaid';
            const now = new Date();

            const payment = await tx.feePayment.create({
                data: {
                    institute_id: instituteId,
                    fee_record_id: record.id,
                    student_id: record.student_id,
                    batch_id: record.batch_id,
                    amount_paid: new Prisma.Decimal(effectiveAmount),
                    payment_mode: 'upi_qr_manual',
                    payment_channel: 'manual_qr',
                    screenshot_url: data.screenshot_url,
                    note: data.note,
                    status: 'pending_verification',
                    submitted_at: now,
                },
            });

            await tx.feeRecord.update({
                where: { id: record.id },
                data: { status: 'pending_verification' },
            });

            await this.appendEvent(tx, {
                instituteId,
                feeRecordId: record.id,
                paymentId: payment.id,
                actorId: userId,
                action: 'payment_proof_submitted',
                fromStatus,
                toStatus: 'pending_verification',
                meta: {
                    amount: effectiveAmount,
                    requested_amount: requestedAmount,
                    partial_allowed: allowPartialProofPayments,
                    whatsapp_notified: data.whatsapp_notified === true,
                },
            });

            return {
                payment,
                fee_record: {
                    id: record.id,
                    status: 'pending_verification',
                    total_amount: finalAmount,
                    paid_amount: paidAmount,
                    remaining_amount: remainingAmount,
                },
            };
        });
    }

    async listStudentPayments(instituteId: string, userId: string, role?: string) {
        const normalizedRole = (role ?? '').toString().trim().toLowerCase();
        let studentIds: string[] = [];

        if (normalizedRole === 'parent') {
            const parent = await prisma.parent.findFirst({
                where: { user_id: userId, institute_id: instituteId },
                select: { id: true },
            });
            if (!parent) throw new ApiError('Parent profile not found', 404, 'NOT_FOUND');

            const links = await prisma.parentStudent.findMany({
                where: { parent_id: parent.id },
                select: { student_id: true },
            });
            studentIds = [...new Set(links.map((link) => link.student_id))];
            if (!studentIds.length) return [];
        } else {
            const student = await prisma.student.findFirst({
                where: { user_id: userId, institute_id: instituteId },
                select: { id: true },
            });
            if (!student) throw new ApiError('Student not found', 404, 'NOT_FOUND');
            studentIds = [student.id];
        }

        return prisma.feePayment.findMany({
            where: {
                institute_id: instituteId,
                student_id: { in: studentIds },
            },
            include: {
                student: { select: { id: true, name: true, phone: true } },
                batch: { select: { id: true, name: true } },
                fee_record: {
                    select: {
                        id: true,
                        month: true,
                        year: true,
                        total_amount: true,
                        paid_amount: true,
                        final_amount: true,
                        status: true,
                    },
                },
            },
            orderBy: { submitted_at: 'desc' },
        });
    }

    async listPaymentsForReview(
        instituteId: string,
        query: { status?: string; batchId?: string; studentId?: string },
        role?: string,
    ) {
        const requestedStatus = (query.status ?? '').trim().toLowerCase();
        const statusFilter: PaymentStatus | undefined =
            requestedStatus === 'pending' ? 'pending_verification' : (requestedStatus as PaymentStatus);

        const where: Prisma.FeePaymentWhereInput = {
            institute_id: instituteId,
            ...(query.batchId ? { batch_id: query.batchId } : {}),
            ...(query.studentId ? { student_id: query.studentId } : {}),
            ...(statusFilter ? { status: statusFilter } : {}),
        };

        const payments = await prisma.feePayment.findMany({
            where,
            include: {
                student: { select: { id: true, name: true, phone: true } },
                batch: { select: { id: true, name: true } },
                fee_record: {
                    select: {
                        id: true,
                        month: true,
                        year: true,
                        total_amount: true,
                        paid_amount: true,
                        final_amount: true,
                        status: true,
                        due_date: true,
                    },
                },
                approved_by: { select: { id: true, role: true } },
            },
            orderBy: { submitted_at: 'desc' },
        });

        if (this.canViewAmounts(role)) return payments;

        return payments.map((payment) => ({
            ...payment,
            amount_paid: null,
            fee_record: payment.fee_record
                ? {
                        ...payment.fee_record,
                        total_amount: null,
                        paid_amount: null,
                        final_amount: null,
                    }
                : null,
        }));
    }

    async approvePaymentProof(instituteId: string, paymentId: string, approverId: string, note?: string) {
        return prisma.$transaction(async (tx) => {
            const payment = await tx.feePayment.findFirst({
                where: { id: paymentId, institute_id: instituteId },
                include: { fee_record: true },
            });
            if (!payment) throw new ApiError('Payment proof not found', 404, 'NOT_FOUND');
            if (payment.status !== 'pending_verification') {
                throw new ApiError('Only pending proofs can be approved', 400, 'INVALID_STATUS');
            }

            const now = new Date();
            const fromStatus = payment.fee_record.status ?? 'unpaid';

            const updatedPayment = await tx.feePayment.update({
                where: { id: payment.id },
                data: {
                    status: 'approved',
                    approved_by_id: approverId,
                    approved_at: now,
                    collected_by_id: approverId,
                    paid_at: now,
                    note: [payment.note, note].filter(Boolean).join('\n').trim() || payment.note,
                },
            });

            const approvedPaidAmount = await this.getApprovedPaidAmount(tx, instituteId, payment.fee_record_id);
            const pendingCount = await this.getPendingPaymentCount(tx, instituteId, payment.fee_record_id);
            const nextStatus = this.resolveFeeStatus({
                paidAmount: approvedPaidAmount,
                finalAmount: Number(payment.fee_record.final_amount),
                pendingCount,
            });

            await tx.feeRecord.update({
                where: { id: payment.fee_record_id },
                data: {
                    paid_amount: new Prisma.Decimal(approvedPaidAmount),
                    status: nextStatus,
                    approved_by_id: approverId,
                    approved_at: nextStatus === 'paid' ? now : null,
                },
            });

            await this.appendEvent(tx, {
                instituteId,
                feeRecordId: payment.fee_record_id,
                paymentId: payment.id,
                actorId: approverId,
                action: 'payment_proof_approved',
                fromStatus,
                toStatus: nextStatus,
                meta: {
                    payment_status: 'approved',
                    amount: Number(payment.amount_paid),
                },
            });

            return {
                payment: updatedPayment,
                fee_record_status: nextStatus,
            };
        });
    }

    async rejectPaymentProof(
        instituteId: string,
        paymentId: string,
        reviewerId: string,
        rejectionReason?: string,
        note?: string,
    ) {
        return prisma.$transaction(async (tx) => {
            const payment = await tx.feePayment.findFirst({
                where: { id: paymentId, institute_id: instituteId },
                include: { fee_record: true },
            });
            if (!payment) throw new ApiError('Payment proof not found', 404, 'NOT_FOUND');
            if (payment.status !== 'pending_verification') {
                throw new ApiError('Only pending proofs can be rejected', 400, 'INVALID_STATUS');
            }

            const now = new Date();
            const fromStatus = payment.fee_record.status ?? 'unpaid';

            const updatedPayment = await tx.feePayment.update({
                where: { id: payment.id },
                data: {
                    status: 'rejected',
                    rejection_reason: rejectionReason,
                    rejected_at: now,
                    note: [payment.note, note].filter(Boolean).join('\n').trim() || payment.note,
                    approved_by_id: reviewerId,
                },
            });

            const approvedPaidAmount = await this.getApprovedPaidAmount(tx, instituteId, payment.fee_record_id);
            const pendingCount = await this.getPendingPaymentCount(tx, instituteId, payment.fee_record_id);
            const nextStatus = this.resolveFeeStatus({
                paidAmount: approvedPaidAmount,
                finalAmount: Number(payment.fee_record.final_amount),
                pendingCount,
                hasRejectedAttempt: true,
            });

            await tx.feeRecord.update({
                where: { id: payment.fee_record_id },
                data: {
                    paid_amount: new Prisma.Decimal(approvedPaidAmount),
                    status: nextStatus,
                },
            });

            await this.appendEvent(tx, {
                instituteId,
                feeRecordId: payment.fee_record_id,
                paymentId: payment.id,
                actorId: reviewerId,
                action: 'payment_proof_rejected',
                fromStatus,
                toStatus: nextStatus,
                meta: {
                    payment_status: 'rejected',
                    rejection_reason: rejectionReason ?? null,
                },
            });

            return {
                payment: updatedPayment,
                fee_record_status: nextStatus,
            };
        });
    }

    async adjustFeeRecord(instituteId: string, actorId: string, data: AdjustFeeRecordInput) {
        return prisma.$transaction(async (tx) => {
            const record = await tx.feeRecord.findFirst({
                where: { id: data.fee_record_id, institute_id: instituteId },
            });

            if (!record) {
                throw new ApiError('Fee record not found', 404, 'NOT_FOUND');
            }

            const amount = Number(data.amount);
            if (!Number.isFinite(amount) || amount <= 0) {
                throw new ApiError('Amount must be greater than zero', 400, 'INVALID_AMOUNT');
            }

            const delta = data.adjustment_type === 'increase' ? amount : -amount;
            const approvedPaidAmount = await this.getApprovedPaidAmount(tx, instituteId, record.id);

            const currentTotalAmount = Number(record.total_amount);
            const currentDiscountAmount = Number(record.discount_amount ?? 0);
            const currentLateFeeAmount = Number(record.late_fee ?? 0);

            let nextDiscountAmount = currentDiscountAmount;
            let nextLateFeeAmount = currentLateFeeAmount;

            if (delta > 0) {
                nextLateFeeAmount += delta;
            } else {
                nextDiscountAmount += Math.abs(delta);
            }

            const nextFinalAmount = Math.max(currentTotalAmount - nextDiscountAmount + nextLateFeeAmount, 0);
            if (nextFinalAmount < approvedPaidAmount) {
                throw new ApiError(
                    'Adjustment would make final amount lower than already approved payments',
                    400,
                    'INVALID_ADJUSTMENT',
                );
            }

            const pendingCount = await this.getPendingPaymentCount(tx, instituteId, record.id);
            const rejectedCount = await tx.feePayment.count({
                where: {
                    institute_id: instituteId,
                    fee_record_id: record.id,
                    status: 'rejected',
                },
            });

            const nextStatus = this.resolveFeeStatus({
                paidAmount: approvedPaidAmount,
                finalAmount: nextFinalAmount,
                pendingCount,
                hasRejectedAttempt: rejectedCount > 0,
            });

            const updatedRecord = await tx.feeRecord.update({
                where: { id: record.id },
                data: {
                    paid_amount: new Prisma.Decimal(approvedPaidAmount),
                    discount_amount: new Prisma.Decimal(nextDiscountAmount),
                    late_fee: new Prisma.Decimal(nextLateFeeAmount),
                    final_amount: new Prisma.Decimal(nextFinalAmount),
                    status: nextStatus,
                    approved_by_id: nextStatus === 'paid' ? actorId : null,
                    approved_at: nextStatus === 'paid' ? new Date() : null,
                },
            });

            await this.appendEvent(tx, {
                instituteId,
                feeRecordId: record.id,
                actorId,
                action: 'manual_fee_adjustment',
                fromStatus: record.status ?? 'unpaid',
                toStatus: nextStatus,
                meta: {
                    adjustment_type: data.adjustment_type,
                    amount,
                    delta,
                    reason: data.reason,
                    note: data.note ?? null,
                    before: {
                        final_amount: Number(record.final_amount),
                        paid_amount: Number(record.paid_amount),
                        discount_amount: currentDiscountAmount,
                        late_fee: currentLateFeeAmount,
                    },
                    after: {
                        final_amount: nextFinalAmount,
                        paid_amount: approvedPaidAmount,
                        discount_amount: nextDiscountAmount,
                        late_fee: nextLateFeeAmount,
                    },
                },
            });

            return {
                fee_record: updatedRecord,
                adjustment: {
                    type: data.adjustment_type,
                    amount,
                    reason: data.reason,
                    note: data.note ?? null,
                },
            };
        });
    }
}

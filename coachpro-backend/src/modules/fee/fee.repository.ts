import { prisma } from '../../server';
import { Prisma } from '@prisma/client';
import { DefineFeeStructureInput, RecordFeePaymentInput, GenerateMonthlyFeesInput } from './fee.validator';

export class FeeRepository {
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

  async findFeeRecords(instituteId: string, batchId?: string, studentId?: string, month?: number, year?: number) {
      const where: Prisma.FeeRecordWhereInput = { institute_id: instituteId };
      if (batchId) where.batch_id = batchId;
      if (studentId) where.student_id = studentId;
      if (month) where.month = month;
      if (year) where.year = year;

      return prisma.feeRecord.findMany({
         where,
         include: {
            student: { select: { name: true, phone: true } },
            batch: { select: { name: true } },
            payments: true
         },
         orderBy: [{ year: 'desc' }, { month: 'desc' }]
      });
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
                    discount_amount: totalDiscount,
                    final_amount: finalAmount,
                    due_date: data.due_date ? new Date(data.due_date) : defaultDueDate,
                    status: 'pending'
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

         if (!record) throw new Error("Fee record not found");

         const paymentCode = `REC-${Date.now().toString(36).toUpperCase()}`;

         const payment = await tx.feePayment.create({
             data: {
                 institute_id: instituteId,
                 fee_record_id: record.id,
                 collected_by_id: userId,
                 amount_paid: new Prisma.Decimal(data.amount_paid),
                 payment_mode: data.payment_mode,
                 transaction_id: data.transaction_id,
                 note: data.note,
                 receipt_number: paymentCode
             }
         });

         // Calculate new totals and status
         const allPayments = await tx.feePayment.findMany({
             where: { fee_record_id: record.id },
             select: { amount_paid: true }
         });

         const totalPaidObj = allPayments.reduce((acc, curr) => acc + Number(curr.amount_paid), 0);
         const totalPaid = Number(totalPaidObj);
         const finalAmount = Number(record.final_amount);
         
         let status = 'pending';
         if (totalPaid >= finalAmount) status = 'paid';
         else if (totalPaid > 0) status = 'partial';

         await tx.feeRecord.update({
             where: { id: record.id },
             data: { status }
         });

         return payment;
     });
  }
}

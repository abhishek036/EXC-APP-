import { prisma } from '../../server';
import { FeeRepository } from '../../modules/fee/fee.repository';
import { WhatsAppService } from '../../modules/whatsapp/whatsapp.service';
import { Prisma } from '@prisma/client';

export class FeeHandler {
  private static repo = new FeeRepository();

  /**
   * Generates monthly fee records for all active students in all batches.
   * Typically runs on the 1st of every month.
   */
  static async generateAllMonthlyFees() {
    const now = new Date();
    const month = now.getMonth() + 1;
    const year = now.getFullYear();

    console.log(`🚀 Starting Global Monthly Fee Generation for ${month}/${year}`);

    const institutes = await prisma.institute.findMany({ where: { is_active: true } });
    
    for (const institute of institutes) {
      const batches = await prisma.batch.findMany({ 
        where: { institute_id: institute.id, is_active: true } 
      });

      for (const batch of batches) {
        try {
          const struct = await this.repo.getFeeStructure(batch.id, institute.id);
          if (!struct) continue;

          const defaultDueDate = new Date(year, month - 1, struct.late_after_day || 10);
          
          const result = await this.repo.createMonthlyFeeRecords(
            institute.id, 
            { batch_id: batch.id, month, year }, 
            defaultDueDate
          );
          
          if (result.generated > 0) {
            console.log(`✅ Generated ${result.generated} fee records for batch: ${batch.name} (Inst: ${institute.name})`);
          }
        } catch (error: any) {
          console.error(`❌ Error generating fees for batch ${batch.name}:`, error.message);
        }
      }
    }
  }

  /**
   * Sends automated WhatsApp reminders for pending fees.
   * Can be configured to run daily.
   */
  static async sendPendingFeeReminders() {
    const today = new Date();
    
    // Find all pending records where due_date is within 3 days or already passed
    const pendingRecords = await prisma.feeRecord.findMany({
      where: {
        status: { in: ['pending', 'partial'] },
        due_date: { lte: new Date(today.getTime() + 3 * 24 * 60 * 60 * 1000) }
      },
      include: {
        student: {
          include: { 
            parent_students: { 
               include: { parent: true } 
            },
            institute: true
          }
        }
      }
    });

    console.log(`🔔 Sending ${pendingRecords.length} fee reminders...`);

    for (const record of pendingRecords) {
      const student = record.student;
      const primaryParent = student.parent_students.find(ps => ps.is_primary)?.parent;
      
      const remainingAmount = Number(record.final_amount); 
      
      // 🔔 PUSH NOTIFICATION (Parent)
      if (primaryParent?.user_id) {
          try {
              const { NotificationService } = await import('../../modules/notification/notification.service');
              await NotificationService.sendNotificationToUser(primaryParent.user_id, {
                  title: 'Fee Payment Reminder',
                  body: `Payment of ₹${remainingAmount} for ${student.name} is due by ${record.due_date.toDateString()}.`,
                  type: 'fee',
                  role_target: 'parent',
                  institute_id: record.institute_id,
                  meta: {
                      route: '/parent/fees',
                      fee_record_id: record.id,
                      dedupe_key: `fee:${record.id}:${primaryParent.user_id}:${today.toISOString().split('T')[0]}`,
                  },
              });
          } catch {}
      }

      // 🔔 PUSH NOTIFICATION (Student)
      if (student.user_id) {
          try {
              const { NotificationService } = await import('../../modules/notification/notification.service');
              await NotificationService.sendNotificationToUser(student.user_id, {
                  title: 'Fee Payment Reminder',
                  body: `Your fee payment of ₹${remainingAmount} is due by ${record.due_date.toDateString()}.`,
                  type: 'fee',
                  role_target: 'student',
                  institute_id: record.institute_id,
                  meta: {
                      route: '/student/fees',
                      fee_record_id: record.id,
                      dedupe_key: `fee:${record.id}:${student.user_id}:${today.toISOString().split('T')[0]}`,
                  },
              });
          } catch {}
      }

      if (primaryParent && primaryParent.phone) {
        const remainingAmount = Number(record.final_amount); // Simplified for now, should subtract payments
        
        try {
          await WhatsAppService.sendFeeReminder(
            primaryParent.phone,
            primaryParent.name,
            student.name,
            remainingAmount,
            record.due_date.toDateString(),
            `https://pay.neurovax.tech/fees/${record.id}`, // Example link
            student.institute.phone || 'Contact Institute'
          );
        } catch (error: any) {
          console.error(`❌ Failed to send reminder to ${primaryParent.name}:`, error.message);
        }
      }
    }
  }
}

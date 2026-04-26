import { prisma } from '../../config/prisma';
import { NotificationService } from '../../modules/notification/notification.service';

export class NotificationHandler {
  static async processFeeReminders() {
    const today = new Date();
    const startOfToday = new Date(today.getFullYear(), today.getMonth(), today.getDate());

    const targets = [7, 1, 0];

    let notificationsSent = 0;

    for (const offsetDays of targets) {
      const targetDate = new Date(startOfToday);
      targetDate.setDate(startOfToday.getDate() + offsetDays);

      const records = await prisma.feeRecord.findMany({
        where: {
          status: { in: ['pending', 'partial'] },
          due_date: targetDate,
          institute: { is_active: true },
        },
        include: {
          student: {
            select: {
              id: true,
              name: true,
              user_id: true,
              parent_students: {
                include: {
                  parent: {
                    select: {
                      user_id: true,
                    },
                  },
                },
              },
            },
          },
          batch: {
            select: {
              name: true,
            },
          },
        },
      });

      for (const record of records) {
        const title = offsetDays === 0 ? 'Fee Due Today' : `Fee Due in ${offsetDays} day${offsetDays > 1 ? 's' : ''}`;
        const body = `${record.student.name}, your fee for ${record.batch.name} is due on ${record.due_date.toDateString()}.`;

        const dedupeBase = `${record.id}:${offsetDays}:${startOfToday.toISOString().substring(0, 10)}`;

        if (record.student.user_id) {
          await NotificationService.sendNotificationToUser(record.student.user_id, {
            title,
            body,
            type: 'fee',
            role_target: 'student',
            institute_id: record.institute_id,
            meta: {
              route: '/student/fees',
              fee_record_id: record.id,
              dedupe_key: `student:${dedupeBase}`,
            },
          });
          notificationsSent += 1;
        }

        const parentUserIds = record.student.parent_students
          .map((item) => item.parent.user_id)
          .filter((value): value is string => Boolean(value));

        for (const parentUserId of parentUserIds) {
          await NotificationService.sendNotificationToUser(parentUserId, {
            title,
            body,
            type: 'fee',
            role_target: 'parent',
            institute_id: record.institute_id,
            meta: {
              route: '/parent/fees',
              fee_record_id: record.id,
              dedupe_key: `parent:${parentUserId}:${dedupeBase}`,
            },
          });
          notificationsSent += 1;
        }
      }
    }

    return { notificationsSent };
  }

  static async processClassReminders() {
    const from = new Date();
    const to = new Date(Date.now() + 30 * 60 * 1000);

    const upcomingLectures = await prisma.lecture.findMany({
      where: {
        scheduled_at: {
          gte: from,
          lte: to,
        },
        is_active: true,
      },
      include: {
        batch: {
          include: {
            student_batches: {
              where: { is_active: true },
              include: {
                student: { select: { user_id: true } },
              },
            },
          },
        },
      },
    });

    let notificationsSent = 0;

    for (const lecture of upcomingLectures) {
      const title = 'Class Starting Soon';
      const body = `${lecture.title} starts in about 30 minutes.`;

      const dedupeKey = `class:${lecture.id}:${from.toISOString().substring(0, 16)}`;

      const studentUserIds = lecture.batch.student_batches
        .map((sb) => sb.student.user_id)
        .filter((value): value is string => Boolean(value));

      for (const userId of studentUserIds) {
        await NotificationService.sendNotificationToUser(userId, {
          title,
          body,
          type: 'class',
          role_target: 'student',
          institute_id: lecture.institute_id,
          meta: {
            route: '/student/classes',
            lecture_id: lecture.id,
            dedupe_key: `${dedupeKey}:${userId}`,
          },
        });
        notificationsSent += 1;
      }
    }

    return { notificationsSent };
  }

  static async processDailyRevenueSummary() {
    const now = new Date();
    const start = new Date(now.getFullYear(), now.getMonth(), now.getDate());
    const end = new Date(now.getFullYear(), now.getMonth(), now.getDate(), 23, 59, 59);

    const payments = await prisma.feePayment.groupBy({
      by: ['institute_id'],
      where: {
        paid_at: {
          gte: start,
          lte: end,
        },
      },
      _sum: {
        amount_paid: true,
      },
      _count: {
        id: true,
      },
    });

    let notificationsSent = 0;

    for (const item of payments) {
      const amount = Number(item._sum.amount_paid ?? 0).toFixed(2);
      const txCount = item._count.id;

      const response = await NotificationService.sendNotificationToRole('admin', {
        title: 'Daily Revenue Summary',
        body: `Collected INR ${amount} today in ${txCount} payment(s).`,
        type: 'system',
        role_target: 'admin',
        institute_id: item.institute_id,
        meta: {
          route: '/admin/reports',
          summary_date: start.toISOString().substring(0, 10),
          dedupe_key: `revenue:${item.institute_id}:${start.toISOString().substring(0, 10)}`,
        },
      });

      notificationsSent += Number(response.delivered ?? 0);
    }

    return { notificationsSent };
  }
}

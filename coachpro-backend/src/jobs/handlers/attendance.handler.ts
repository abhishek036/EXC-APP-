import { prisma } from '../../server';
import { WhatsAppService } from '../../modules/whatsapp/whatsapp.service';
import { NotificationService } from '../../modules/notification/notification.service';

export class AttendanceHandler {
  /**
   * Processes a newly submitted attendance session to send alerts for absentees.
   * Typically triggered by markSession event.
   */
  static async processAttendanceAlerts(sessionId: string, instituteId: string) {
    const session = await prisma.attendanceSession.findUnique({
      where: { id: sessionId, institute_id: instituteId },
      include: {
        batch: { select: { name: true } },
        teacher: { select: { name: true } },
        institute: { select: { name: true } },
        records: {
          where: { status: 'absent' },
          include: {
            student: {
              include: {
                parent_students: { include: { parent: true } }
              }
            }
          }
        }
      }
    });

    if (!session || !session.records.length) return;

    console.log(`📡 Processing ${session.records.length} absent alerts for session: ${session.id}`);

    for (const record of session.records) {
      const student = record.student;
      const primaryParent = student.parent_students.find(ps => ps.is_primary)?.parent;

      if (primaryParent && primaryParent.phone) {
        try {
          await WhatsAppService.sendAbsentAlert(
            primaryParent.phone,
            student.name,
            session.session_date.toDateString(),
            session.batch.name,
            session.teacher?.name || 'Assigned Teacher',
            session.institute.name
          );
        } catch (error: any) {
          console.error(`❌ Failed to send absent alert to ${primaryParent.name}:`, error.message);
        }
      }

      if (primaryParent?.user_id) {
        await NotificationService.sendNotificationToUser(primaryParent.user_id, {
          title: 'Student Absent Alert',
          body: `${student.name} was marked absent for ${session.batch.name} on ${session.session_date.toDateString()}.`,
          type: 'attendance',
          role_target: 'parent',
          institute_id: instituteId,
          meta: {
            route: '/parent/attendance',
            student_id: student.id,
            dedupe_key: `absent:${session.id}:${student.id}:parent`,
          },
        });
      }
    }

    await NotificationService.sendNotificationToRole('admin', {
      title: 'Low Attendance Alert',
      body: `${session.records.length} absent student(s) recorded for ${session.batch.name}.`,
      type: 'attendance',
      role_target: 'admin',
      institute_id: instituteId,
      meta: {
        route: '/admin/attendance',
        session_id: session.id,
        dedupe_key: `absent:admin:${session.id}`,
      },
    });
  }
}

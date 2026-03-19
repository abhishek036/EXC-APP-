import { prisma } from '../../server';
import { WhatsAppService } from '../../modules/whatsapp/whatsapp.service';

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
    }
  }
}

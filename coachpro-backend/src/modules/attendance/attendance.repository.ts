import { prisma } from '../../server';
import { MarkAttendanceInput } from './attendance.validator';
import { Prisma } from '@prisma/client';

export class AttendanceRepository {
    async markAttendance(
        instituteId: string,
        actorUserId: string,
        teacherProfileId: string | null,
        data: MarkAttendanceInput,
    ) {
     return prisma.$transaction(async (tx) => {
         // Find or create session
         const sessionDate = new Date(data.session_date);
         
         const session = await tx.attendanceSession.upsert({
             where: {
                 batch_id_session_date_subject: {
                     batch_id: data.batch_id,
                     session_date: sessionDate,
                     subject: data.subject || null as any
                 }
             },
             update: {
                 submitted_at: new Date(),
                 ...(teacherProfileId ? { teacher_id: teacherProfileId } : {}),
             },
             create: {
                 institute_id: instituteId,
                 batch_id: data.batch_id,
                 session_date: sessionDate,
                 subject: data.subject || null,
                 submitted_at: new Date(),
                 ...(teacherProfileId ? { teacher_id: teacherProfileId } : {}),
             }
         });

         // Bulk Insert/Update Records
         // We do it sequentially or via Promise.all mapping for upserts. Prisma doesn't perfectly support bulk upsert without some raw queries or createMany with skipDuplicates.
         const upsertPromises = data.records.map(record => 
             tx.attendanceRecord.upsert({
                 where: {
                     session_id_student_id: {
                         session_id: session.id,
                         student_id: record.student_id
                     }
                 },
                 update: {
                     status: record.status,
                     correction_note: record.note,
                     corrected_by_id: actorUserId,
                 },
                 create: {
                     institute_id: instituteId,
                     session_id: session.id,
                     student_id: record.student_id,
                     status: record.status,
                     correction_note: record.note
                 }
             })
         );

         await Promise.all(upsertPromises);

         return session;
     });
  }

  async getBatchAttendanceForMonth(batchId: string, instituteId: string, startDate: Date, endDate: Date, subject?: string) {
      return prisma.attendanceSession.findMany({
         where: {
            batch_id: batchId,
            institute_id: instituteId,
            session_date: { gte: startDate, lte: endDate },
            ...(subject ? { subject } : {})
         },
         include: {
            records: {
               include: {
                  student: { select: { id: true, name: true } }
               }
            }
         },
         orderBy: { session_date: 'asc' }
      });
  }

  async getStudentAttendance(studentId: string, instituteId: string, batchId?: string, subject?: string) {
      const where: Prisma.AttendanceRecordWhereInput = { student_id: studentId, institute_id: instituteId };
      if (batchId || subject) {
          where.session = { 
              ...(batchId ? { batch_id: batchId } : {}),
              ...(subject ? { subject: subject } : {})
          };
      }

      return prisma.attendanceRecord.findMany({
         where,
         include: {
            session: {
               select: { session_date: true, batch: { select: { name: true } } }
            }
         },
         orderBy: { session: { session_date: 'desc' } }
      });
  }

  async getSessionsInRange(instituteId: string, start: Date, end: Date, batchId?: string, subject?: string) {
      return (prisma.attendanceSession as any).findMany({
          where: {
              institute_id: instituteId,
              session_date: { gte: start, lte: end },
              ...(batchId ? { batch_id: batchId } : {}),
              ...(subject ? { subject: subject } : {})
          },
          include: {
              records: {
                  include: {
                      student: { select: { id: true, name: true } }
                  }
              }
          }
      });
  }

  async getAggregateStats(instituteId: string, start: Date, end: Date, batchId?: string, subject?: string) {
       // This could be optimized into a single group-by if complex, but simple for now
       const records = await prisma.attendanceRecord.findMany({
           where: {
               institute_id: instituteId,
               ...(batchId || subject ? { 
                   session: { 
                       ...(batchId ? { batch_id: batchId } : {}),
                       ...(subject ? { subject: subject } : {}),
                       session_date: { gte: start, lte: end }
                   }
               } : {
                   session: { session_date: { gte: start, lte: end } }
               }),
           },
           select: { status: true, session: { select: { session_date: true } } }
       });

       return records;
  }
}

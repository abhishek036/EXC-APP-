import { prisma } from '../../server';
import { MarkAttendanceInput } from './attendance.validator';
import { Prisma } from '@prisma/client';

export class AttendanceRepository {
    private isLegacyAttendanceSubjectColumnError(error: unknown): boolean {
        const isValidationError = error instanceof Error && error.toString().includes('PrismaClientValidationError');
        if (isValidationError) return true;

        const code = (error as any)?.code;
        const column = String((error as any)?.meta?.column ?? '').toLowerCase();
        return code === 'P2022' && (column.includes('attendance_sessions.subject') || column.includes('subject'));
    }

    private mapLegacySessionRow(row: any) {
        return {
            id: row.id,
            batch_id: row.batch_id,
            institute_id: row.institute_id,
            teacher_id: row.teacher_id,
            session_date: row.session_date,
            subject: null,
            submitted_at: row.submitted_at,
            is_corrected: row.is_corrected,
        };
    }

    private mapLegacyRecordRow(row: any) {
        return {
            id: row.id,
            session_id: row.session_id,
            student_id: row.student_id,
            institute_id: row.institute_id,
            status: row.status,
            correction_note: row.correction_note,
            corrected_by_id: row.corrected_by_id,
            student: {
                id: row.student_id,
                name: row.student_name,
            },
        };
    }

    private async listSessionsLegacy(instituteId: string, startDate: Date, endDate: Date, filter: { batchId?: string }) {
        const rows = await prisma.$queryRawUnsafe<any[]>(
            `SELECT id::text,
                    batch_id::text,
                    institute_id::text,
                    teacher_id::text,
                    session_date,
                    submitted_at,
                    is_corrected
             FROM attendance_sessions
             WHERE institute_id::text = $1::text
               AND session_date >= $2::date
               AND session_date <= $3::date
               AND ($4::text IS NULL OR batch_id::text = $4::text)
             ORDER BY session_date ASC`,
            instituteId,
            startDate,
            endDate,
            filter.batchId ?? null,
        );

        return rows.map((row) => this.mapLegacySessionRow(row));
    }

    private async listSessionRecordsLegacy(sessionId: string) {
        const rows = await prisma.$queryRawUnsafe<any[]>(
            `SELECT ar.id::text,
                    ar.session_id::text,
                    ar.student_id::text,
                    ar.institute_id::text,
                    ar.status,
                    ar.correction_note,
                    ar.corrected_by::text as corrected_by_id,
                    s.name as student_name
             FROM attendance_records ar
             LEFT JOIN students s ON s.id = ar.student_id
             WHERE ar.session_id::text = $1::text`,
            sessionId,
        );

        return rows.map((row) => this.mapLegacyRecordRow(row));
    }

    private async hydrateLegacySessionsWithRecords(sessions: any[]) {
        const enriched = await Promise.all(
            sessions.map(async (session) => {
                const records = await this.listSessionRecordsLegacy(session.id);
                return {
                    ...session,
                    records,
                };
            }),
        );

        return enriched;
    }

    private async markAttendanceLegacy(
        tx: Prisma.TransactionClient,
        instituteId: string,
        actorUserId: string,
        teacherProfileId: string | null,
        data: MarkAttendanceInput,
    ) {
        const sessionDate = new Date(data.session_date);
        const existingRows = await tx.$queryRawUnsafe<any[]>(
            `SELECT id::text
             FROM attendance_sessions
             WHERE institute_id::text = $1::text
               AND batch_id::text = $2::text
               AND session_date = $3::date
             ORDER BY submitted_at DESC NULLS LAST, id DESC
             LIMIT 1`,
            instituteId,
            data.batch_id,
            sessionDate,
        );

        let sessionId: string;
        if (existingRows.length > 0) {
            sessionId = existingRows[0].id;
            await tx.$executeRawUnsafe(
                `UPDATE attendance_sessions
                 SET submitted_at = NOW(),
                     teacher_id = COALESCE($1::uuid, teacher_id)
                 WHERE id::text = $2::text`,
                teacherProfileId,
                sessionId,
            );
        } else {
            const insertedRows = await tx.$queryRawUnsafe<any[]>(
                `INSERT INTO attendance_sessions (institute_id, batch_id, session_date, submitted_at, teacher_id)
                 VALUES ($1::uuid, $2::uuid, $3::date, NOW(), $4::uuid)
                 RETURNING id::text`,
                instituteId,
                data.batch_id,
                sessionDate,
                teacherProfileId,
            );
            sessionId = insertedRows[0].id;
        }

        const upsertPromises = data.records.map((record) =>
            tx.attendanceRecord.upsert({
                where: {
                    session_id_student_id: {
                        session_id: sessionId,
                        student_id: record.student_id,
                    },
                },
                update: {
                    status: record.status,
                    correction_note: record.note,
                    corrected_by_id: actorUserId,
                },
                create: {
                    institute_id: instituteId,
                    session_id: sessionId,
                    student_id: record.student_id,
                    status: record.status,
                    correction_note: record.note,
                },
            }),
        );

        await Promise.all(upsertPromises);

        return {
            id: sessionId,
            batch_id: data.batch_id,
            institute_id: instituteId,
            session_date: sessionDate,
            subject: null,
        };
    }

    async markAttendance(
        instituteId: string,
        actorUserId: string,
        teacherProfileId: string | null,
        data: MarkAttendanceInput,
    ) {
     return prisma.$transaction(async (tx) => {
         try {
             const sessionDate = new Date(data.session_date);
             const session = await tx.attendanceSession.upsert({
                 where: {
                     batch_id_session_date_subject: {
                         batch_id: data.batch_id,
                         session_date: sessionDate,
                         subject: data.subject?.trim() || '',
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
                     subject: data.subject?.trim() || '',
                     submitted_at: new Date(),
                     ...(teacherProfileId ? { teacher_id: teacherProfileId } : {}),
                 }
             });

             const upsertPromises = data.records.map(record =>
                 tx.attendanceRecord.upsert({
                     where: {
                         session_id_student_id: {
                             session_id: session.id,
                             student_id: record.student_id,
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
                         correction_note: record.note,
                     }
                 })
             );

             await Promise.all(upsertPromises);
             return session;
         } catch (error) {
             if (!this.isLegacyAttendanceSubjectColumnError(error)) throw error;
             return this.markAttendanceLegacy(tx, instituteId, actorUserId, teacherProfileId, data);
         }
     });
  }

  async getBatchAttendanceForMonth(batchId: string, instituteId: string, startDate: Date, endDate: Date, subject?: string) {
        try {
             return await prisma.attendanceSession.findMany({
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
        } catch (error) {
             if (!this.isLegacyAttendanceSubjectColumnError(error)) throw error;
             const sessions = await this.listSessionsLegacy(instituteId, startDate, endDate, { batchId });
             return this.hydrateLegacySessionsWithRecords(sessions);
        }
  }

  async getStudentAttendance(studentId: string, instituteId: string, batchId?: string, subject?: string) {
      const where: Prisma.AttendanceRecordWhereInput = { student_id: studentId, institute_id: instituteId };
      if (batchId || subject) {
          where.session = { 
              ...(batchId ? { batch_id: batchId } : {}),
              ...(subject ? { subject: subject } : {})
          };
      }

      try {
          return await prisma.attendanceRecord.findMany({
             where,
             include: {
                session: {
                   select: { session_date: true, batch: { select: { name: true } } }
                }
             },
             orderBy: { session: { session_date: 'desc' } }
          });
      } catch (error) {
          if (!this.isLegacyAttendanceSubjectColumnError(error) || !subject) throw error;

          const fallbackWhere: Prisma.AttendanceRecordWhereInput = {
              student_id: studentId,
              institute_id: instituteId,
              ...(batchId ? { session: { batch_id: batchId } } : {}),
          };

          return prisma.attendanceRecord.findMany({
              where: fallbackWhere,
              include: {
                  session: {
                      select: { session_date: true, batch: { select: { name: true } } },
                  },
              },
              orderBy: { session: { session_date: 'desc' } },
          });
      }
  }

  async getSessionsInRange(instituteId: string, start: Date, end: Date, batchId?: string, subject?: string) {
      try {
          return await (prisma.attendanceSession as any).findMany({
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
      } catch (error) {
          if (!this.isLegacyAttendanceSubjectColumnError(error)) throw error;
          const sessions = await this.listSessionsLegacy(instituteId, start, end, { batchId });
          return this.hydrateLegacySessionsWithRecords(sessions);
      }
  }

  async getAggregateStats(instituteId: string, start: Date, end: Date, batchId?: string, subject?: string) {
       // This could be optimized into a single group-by if complex, but simple for now
       try {
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
       } catch (error) {
           if (!this.isLegacyAttendanceSubjectColumnError(error) || !subject) throw error;

           return prisma.attendanceRecord.findMany({
               where: {
                   institute_id: instituteId,
                   ...(batchId ? {
                       session: {
                           batch_id: batchId,
                           session_date: { gte: start, lte: end }
                       }
                   } : {
                       session: { session_date: { gte: start, lte: end } }
                   }),
               },
               select: { status: true, session: { select: { session_date: true } } }
           });
       }
  }
}

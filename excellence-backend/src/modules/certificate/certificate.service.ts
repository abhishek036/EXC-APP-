import { prisma } from '../../config/prisma';
import { ApiError } from '../../middleware/error.middleware';

export class CertificateService {
  /**
   * Generates a formal certificate record for a student.
   */
  async mintCertificate(instituteId: string, data: { studentId: string, type: string, courseName: string, metadata?: any }) {
    const student = await prisma.student.findUnique({
      where: { id: data.studentId, institute_id: instituteId }
    });
    if (!student) throw new ApiError('Student not found', 404, 'NOT_FOUND');

    // Generate a unique number: CP-[YEAR]-[TOTAL_COUNT + 1]
    const currentYear = new Date().getFullYear();
    const count = await prisma.certificate.count({
        where: { institute_id: instituteId }
    });
    
    const certNumber = `CP-${currentYear}-${(count + 1).toString().padStart(4, '0')}`;

    const certificate = await prisma.certificate.create({
      data: {
        cert_number: certNumber,
        institute_id: instituteId,
        student_id: data.studentId,
        type: data.type.toUpperCase(),
        course_name: data.courseName,
        metadata: data.metadata || {}
      },
      include: {
          student: { select: { name: true, phone: true } }
      }
    });

    return certificate;
  }

  async listCertificates(instituteId: string, query: { studentId?: string }) {
    return prisma.certificate.findMany({
      where: {
        institute_id: instituteId,
        ...(query.studentId && { student_id: query.studentId })
      },
      include: {
          student: { select: { name: true } }
      },
      orderBy: { created_at: 'desc' }
    });
  }

  async verifyCertificate(certNumber: string) {
      const cert = await prisma.certificate.findUnique({
          where: { cert_number: certNumber },
          include: {
              student: { select: { name: true } },
              institute: { select: { name: true } }
          }
      });
      if (!cert) throw new ApiError('Invalid Certificate Number', 404, 'NOT_FOUND');
      return cert;
  }
}

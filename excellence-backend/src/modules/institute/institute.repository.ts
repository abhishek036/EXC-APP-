import { prisma } from '../../config/prisma';
import { UpdateInstituteInput } from './institute.validator';

export class InstituteRepository {
  async getInstituteById(instituteId: string) {
    return prisma.institute.findUnique({
      where: { id: instituteId }
    });
  }

  async updateInstitute(instituteId: string, data: UpdateInstituteInput) {
    return prisma.institute.update({
      where: { id: instituteId },
      data: data as any
    });
  }
}

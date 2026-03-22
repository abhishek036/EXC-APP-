import { prisma } from '../../server';
import { CreateLeadInput } from './lead.validator';

export class LeadRepository {
  async list(instituteId: string) {
    return prisma.lead.findMany({
      where: { institute_id: instituteId },
      orderBy: { created_at: 'desc' },
      take: 200,
    });
  }

  async create(instituteId: string, data: CreateLeadInput) {
    return prisma.lead.create({
      data: {
        institute_id: instituteId,
        name: data.name,
        phone: data.phone,
        status: data.status ?? 'New',
      },
    });
  }

  async updateStatus(instituteId: string, id: string, status: string) {
    await prisma.lead.updateMany({
      where: { id, institute_id: instituteId },
      data: { status },
    });
    return { success: true };
  }

  async updateLead(instituteId: string, id: string, data: any) {
    return prisma.lead.update({
      where: { id, institute_id: instituteId },
      data,
    });
  }

  async deleteLead(instituteId: string, id: string) {
    return prisma.lead.delete({
      where: { id, institute_id: instituteId },
    });
  }
}

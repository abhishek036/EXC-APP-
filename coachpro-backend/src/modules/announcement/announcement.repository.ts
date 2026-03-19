import { prisma } from '../../server';
import { CreateAnnouncementInput } from './announcement.validator';

export class AnnouncementRepository {
  async list(instituteId: string, category?: string) {
    return prisma.announcement.findMany({
      where: {
        institute_id: instituteId,
        ...(category && category !== 'All' ? { target_role: category } : {}),
      },
      include: {
        created_by: { select: { id: true, phone: true } },
      },
      orderBy: { created_at: 'desc' },
      take: 100,
    });
  }

  async create(instituteId: string, userId: string, data: CreateAnnouncementInput) {
    return prisma.announcement.create({
      data: {
        institute_id: instituteId,
        title: data.title,
        body: data.body,
        target_role: data.category ?? 'Academic',
        send_whatsapp: data.pinned ?? false,
        created_by_id: userId,
      },
    });
  }

  async remove(id: string, instituteId: string) {
    return prisma.announcement.delete({
      where: { id, institute_id: instituteId },
    });
  }
}

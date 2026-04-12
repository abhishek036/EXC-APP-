import { prisma } from '../../server';
import { CreateAnnouncementInput, UpdateAnnouncementInput } from './announcement.validator';

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

  async update(id: string, instituteId: string, data: UpdateAnnouncementInput) {
    return prisma.announcement.update({
      where: { id, institute_id: instituteId },
      data: {
        ...(data.title != null ? { title: data.title } : {}),
        ...(data.body != null ? { body: data.body } : {}),
        ...(data.category != null ? { target_role: data.category } : {}),
        ...(data.pinned != null ? { send_whatsapp: data.pinned } : {}),
      },
    });
  }

  async remove(id: string, instituteId: string) {
    return prisma.announcement.delete({
      where: { id, institute_id: instituteId },
    });
  }
}

import { ApiError } from '../../middleware/error.middleware';
import { CreateAnnouncementInput, UpdateAnnouncementInput } from './announcement.validator';
import { AnnouncementRepository } from './announcement.repository';
import { NotificationService } from '../notification/notification.service';

export class AnnouncementService {
  private repo: AnnouncementRepository;

  constructor() {
    this.repo = new AnnouncementRepository();
  }

  async list(instituteId: string, category?: string) {
    const items = await this.repo.list(instituteId, category);
    return items.map((item) => ({
      id: item.id,
      title: item.title,
      body: item.body,
      category: item.target_role ?? 'Academic',
      pinned: item.send_whatsapp ?? false,
      createdAt: item.created_at,
      author: 'Admin',
    }));
  }

  async create(instituteId: string, userId: string, data: CreateAnnouncementInput) {
    const created = await this.repo.create(instituteId, userId, data);

    try {
      await NotificationService.sendNotificationToInstitute(instituteId, {
        title: data.title,
        body: data.body,
        type: 'announcement',
        role_target: 'all',
        meta: {
          route: '/announcements',
          source: 'announcement-create',
          announcement_id: created.id,
        },
      });
    } catch (error) {
      console.error('[AnnouncementService] Failed to send push notification:', error);
    }

    return created;
  }

  async update(id: string, instituteId: string, data: UpdateAnnouncementInput) {
    const exists = await this.repo.list(instituteId);
    if (!exists.some((item) => item.id === id)) {
      throw new ApiError('Announcement not found', 404, 'NOT_FOUND');
    }
    return this.repo.update(id, instituteId, data);
  }

  async remove(id: string, instituteId: string) {
    const exists = await this.repo.list(instituteId);
    if (!exists.some((item) => item.id === id)) {
      throw new ApiError('Announcement not found', 404, 'NOT_FOUND');
    }
    await this.repo.remove(id, instituteId);
    try {
      await NotificationService.deleteByAnnouncement({ instituteId, announcementId: id });
    } catch (error) {
      console.error('[AnnouncementService] Failed to delete notification:', error);
    }
    return { success: true };
  }
}

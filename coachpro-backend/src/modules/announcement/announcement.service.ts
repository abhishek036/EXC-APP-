import { ApiError } from '../../middleware/error.middleware';
import { CreateAnnouncementInput } from './announcement.validator';
import { AnnouncementRepository } from './announcement.repository';

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
    return this.repo.create(instituteId, userId, data);
  }

  async remove(id: string, instituteId: string) {
    const exists = await this.repo.list(instituteId);
    if (!exists.some((item) => item.id === id)) {
      throw new ApiError('Announcement not found', 404, 'NOT_FOUND');
    }
    await this.repo.remove(id, instituteId);
    return { success: true };
  }
}

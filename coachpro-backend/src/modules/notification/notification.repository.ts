import { Prisma } from '@prisma/client';
import { prisma } from '../../server';

export class NotificationRepository {
  static async upsertDeviceToken(params: {
    instituteId: string;
    userId: string;
    token: string;
    platform: string;
  }) {
    return prisma.userDeviceToken.upsert({
      where: { token: params.token },
      update: {
        institute_id: params.instituteId,
        user_id: params.userId,
        platform: params.platform,
        is_active: true,
        last_seen_at: new Date(),
      },
      create: {
        institute_id: params.instituteId,
        user_id: params.userId,
        token: params.token,
        platform: params.platform,
        is_active: true,
        last_seen_at: new Date(),
      },
    });
  }

  static async deactivateDeviceToken(params: {
    instituteId: string;
    userId: string;
    token: string;
  }) {
    return prisma.userDeviceToken.updateMany({
      where: {
        institute_id: params.instituteId,
        user_id: params.userId,
        token: params.token,
      },
      data: {
        is_active: false,
      },
    });
  }

  static async getActiveTokensByUsers(instituteId: string, userIds: string[]) {
    if (userIds.length === 0) return [];

    return prisma.userDeviceToken.findMany({
      where: {
        institute_id: instituteId,
        user_id: { in: userIds },
        is_active: true,
      },
      select: {
        user_id: true,
        token: true,
      },
    });
  }

  static async isUserInInstitute(instituteId: string, userId: string) {
    const user = await prisma.user.findFirst({
      where: {
        id: userId,
        institute_id: instituteId,
        is_active: true,
      },
      select: { id: true },
    });

    return Boolean(user);
  }

  static async getUserIdsByRole(instituteId: string, role: string) {
    return prisma.user.findMany({
      where: {
        institute_id: instituteId,
        role,
        is_active: true,
      },
      select: { id: true },
    });
  }

  static async getAllActiveUserIds(instituteId: string) {
    return prisma.user.findMany({
      where: {
        institute_id: instituteId,
        is_active: true,
      },
      select: { id: true },
    });
  }

  static async createNotification(data: Prisma.NotificationUncheckedCreateInput) {
    return prisma.notification.create({
      data,
    });
  }

  static async createDeliveryLog(data: Prisma.NotificationDeliveryLogUncheckedCreateInput) {
    return prisma.notificationDeliveryLog.create({
      data,
    });
  }

  static async findRecentDuplicate(params: {
    instituteId: string;
    userId: string;
    type: string;
    dedupeKey?: string;
    windowMinutes?: number;
  }) {
    const windowMinutes = params.windowMinutes ?? 15;
    const since = new Date(Date.now() - windowMinutes * 60 * 1000);

    return prisma.notification.findFirst({
      where: {
        institute_id: params.instituteId,
        user_id: params.userId,
        type: params.type,
        created_at: { gte: since },
        ...(params.dedupeKey
          ? {
              meta: {
                path: ['dedupe_key'],
                equals: params.dedupeKey,
              },
            }
          : {}),
      },
      select: { id: true },
    });
  }

  static async listByUser(params: {
    instituteId: string;
    userId: string;
    page: number;
    perPage: number;
    type?: string;
    readStatus?: 'read' | 'unread' | 'all';
  }) {
    const where: Prisma.NotificationWhereInput = {
      institute_id: params.instituteId,
      user_id: params.userId,
      ...(params.type ? { type: params.type } : {}),
      ...(params.readStatus === 'read'
        ? { read_status: true }
        : params.readStatus === 'unread'
          ? { read_status: false }
          : {}),
    };

    const [items, total] = await Promise.all([
      prisma.notification.findMany({
        where,
        orderBy: { created_at: 'desc' },
        skip: (params.page - 1) * params.perPage,
        take: params.perPage,
      }),
      prisma.notification.count({ where }),
    ]);

    return { items, total };
  }

  static async markRead(params: {
    instituteId: string;
    userId: string;
    notificationId: string;
    readStatus: boolean;
  }) {
    return prisma.notification.updateMany({
      where: {
        id: params.notificationId,
        institute_id: params.instituteId,
        user_id: params.userId,
      },
      data: {
        read_status: params.readStatus,
      },
    });
  }

  static async markAllRead(params: { instituteId: string; userId: string }) {
    return prisma.notification.updateMany({
      where: {
        institute_id: params.instituteId,
        user_id: params.userId,
        read_status: false,
      },
      data: {
        read_status: true,
      },
    });
  }

  static async findById(instituteId: string, notificationId: string) {
    return prisma.notification.findFirst({
      where: {
        id: notificationId,
        institute_id: instituteId,
      },
    });
  }

  static async removeByIdForUser(params: { instituteId: string; userId: string; notificationId: string }) {
    return prisma.notification.deleteMany({
      where: {
        id: params.notificationId,
        institute_id: params.instituteId,
        user_id: params.userId,
      },
    });
  }

  static async removeById(instituteId: string, notificationId: string) {
    return prisma.notification.deleteMany({
      where: {
        id: notificationId,
        institute_id: instituteId,
      },
    });
  }

  static async removeByBroadcastId(instituteId: string, broadcastId: string) {
    return prisma.notification.deleteMany({
      where: {
        institute_id: instituteId,
        meta: {
          path: ['broadcast_id'],
          equals: broadcastId,
        },
      },
    });
  }

  static async removeByAnnouncementId(instituteId: string, announcementId: string) {
    return prisma.notification.deleteMany({
      where: {
        institute_id: instituteId,
        meta: {
          path: ['announcement_id'],
          equals: announcementId,
        },
      },
    });
  }
}

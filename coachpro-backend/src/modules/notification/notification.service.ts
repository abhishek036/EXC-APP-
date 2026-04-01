import { ApiError } from '../../middleware/error.middleware';
import { firebaseMessaging } from '../../config/firebase-admin';
import { NotificationRepository } from './notification.repository';

type RoleTarget = 'admin' | 'teacher' | 'student' | 'parent' | 'all';

type NotificationPayload = {
  title: string;
  body: string;
  type: string;
  role_target?: RoleTarget;
  institute_id: string;
  meta?: Record<string, any>;
};

export class NotificationService {
  static async registerDeviceToken(params: {
    instituteId: string;
    userId: string;
    token: string;
    platform: string;
  }) {
    return NotificationRepository.upsertDeviceToken({
      instituteId: params.instituteId,
      userId: params.userId,
      token: params.token,
      platform: params.platform,
    });
  }

  static async unregisterDeviceToken(params: {
    instituteId: string;
    userId: string;
    token: string;
  }) {
    await NotificationRepository.deactivateDeviceToken(params);
    return { success: true };
  }

  static async sendNotificationToUser(userId: string, payload: NotificationPayload) {
    const isAllowed = await NotificationRepository.isUserInInstitute(payload.institute_id, userId);
    if (!isAllowed) {
      throw new ApiError('Cannot send notification outside your institute scope', 403, 'FORBIDDEN');
    }
    return this.sendToUsers([userId], payload, payload.role_target ?? 'all');
  }

  static async sendNotificationToRole(role: RoleTarget, payload: NotificationPayload) {
    const users = await NotificationRepository.getUserIdsByRole(payload.institute_id, role);
    const userIds = users.map((item) => item.id);
    return this.sendToUsers(userIds, payload, role);
  }

  static async sendNotificationToInstitute(instituteId: string, payload: Omit<NotificationPayload, 'institute_id'>) {
    const users = await NotificationRepository.getAllActiveUserIds(instituteId);
    const userIds = users.map((item) => item.id);
    return this.sendToUsers(userIds, { ...payload, institute_id: instituteId }, payload.role_target ?? 'all');
  }

  private static async sendToUsers(userIds: string[], payload: NotificationPayload, roleTarget: RoleTarget) {
    if (userIds.length === 0) {
      return { totalUsers: 0, delivered: 0, failed: 0 };
    }

    const tokenRows = await NotificationRepository.getActiveTokensByUsers(payload.institute_id, userIds);
    const tokensByUser = new Map<string, string[]>();

    for (const row of tokenRows) {
      const bucket = tokensByUser.get(row.user_id) ?? [];
      bucket.push(row.token);
      tokensByUser.set(row.user_id, bucket);
    }

    let delivered = 0;
    let failed = 0;

    for (const userId of userIds) {
      const dedupeKey = payload.meta?.dedupe_key ? String(payload.meta.dedupe_key) : undefined;
      const duplicate = dedupeKey
        ? await NotificationRepository.findRecentDuplicate({
            instituteId: payload.institute_id,
            userId,
            type: payload.type,
            dedupeKey,
            windowMinutes: 30,
          })
        : null;

      if (duplicate) continue;

      const notification = await NotificationRepository.createNotification({
        title: payload.title,
        body: payload.body,
        type: payload.type,
        role_target: roleTarget,
        user_id: userId,
        institute_id: payload.institute_id,
        read_status: false,
        meta: payload.meta,
      });

      const { emitInstituteDashboardSync } = await import('../../config/socket');
      emitInstituteDashboardSync(payload.institute_id, 'notification_created', {
        user_id: userId,
        notification_id: notification.id,
        type: payload.type,
      });

      const userTokens = Array.from(new Set(tokensByUser.get(userId) ?? []));
      if (userTokens.length === 0) {
        await NotificationRepository.createDeliveryLog({
          notification_id: notification.id,
          institute_id: payload.institute_id,
          user_id: userId,
          status: 'skipped',
          error_message: 'No active FCM token',
        });
        continue;
      }

      const messaging = firebaseMessaging();
      if (!messaging) {
        await NotificationRepository.createDeliveryLog({
          notification_id: notification.id,
          institute_id: payload.institute_id,
          user_id: userId,
          status: 'failed',
          error_message: 'Firebase Admin not configured',
        });
        failed += userTokens.length;
        continue;
      }

      try {
        const response = await messaging.sendEachForMulticast({
          tokens: userTokens,
          notification: {
            title: payload.title,
            body: payload.body,
          },
          data: {
            type: payload.type,
            click_action: 'FLUTTER_NOTIFICATION_CLICK',
            ...(payload.meta
              ? Object.entries(payload.meta).reduce<Record<string, string>>((acc, [key, value]) => {
                  acc[key] = typeof value === 'string' ? value : JSON.stringify(value);
                  return acc;
                }, {})
              : {}),
          },
        });

        // Emit real-time unread count update via Socket
        const { emitUnreadCount } = await import('../../config/socket');
        const count = await NotificationRepository.getUnreadCount(payload.institute_id, userId);
        emitUnreadCount(payload.institute_id, userId, count);

        for (let i = 0; i < response.responses.length; i++) {
          const item = response.responses[i];
          const token = userTokens[i];
          if (item.success) {
            delivered += 1;
            await NotificationRepository.createDeliveryLog({
              notification_id: notification.id,
              institute_id: payload.institute_id,
              user_id: userId,
              token,
              status: 'sent',
              provider_message_id: item.messageId,
            });
          } else {
            failed += 1;
            const errorCode = item.error?.code ?? '';

            await NotificationRepository.createDeliveryLog({
              notification_id: notification.id,
              institute_id: payload.institute_id,
              user_id: userId,
              token,
              status: 'failed',
              error_message: item.error?.message,
            });

            if (errorCode === 'messaging/registration-token-not-registered' || errorCode === 'messaging/invalid-registration-token') {
              await NotificationRepository.deactivateDeviceToken({
                instituteId: payload.institute_id,
                userId,
                token,
              });
            }
          }
        }
      } catch (error: any) {
        failed += userTokens.length;
        for (const token of userTokens) {
          await NotificationRepository.createDeliveryLog({
            notification_id: notification.id,
            institute_id: payload.institute_id,
            user_id: userId,
            token,
            status: 'failed',
            error_message: error?.message ?? 'FCM send failed',
          });
        }
      }
    }

    return {
      totalUsers: userIds.length,
      delivered,
      failed,
    };
  }

  static async listMyNotifications(params: {
    instituteId: string;
    userId: string;
    page?: number;
    perPage?: number;
    type?: string;
    readStatus?: 'read' | 'unread' | 'all';
  }) {
    const page = params.page && params.page > 0 ? params.page : 1;
    const perPage = params.perPage && params.perPage > 0 ? params.perPage : 20;

    const result = await NotificationRepository.listByUser({
      instituteId: params.instituteId,
      userId: params.userId,
      page,
      perPage,
      type: params.type,
      readStatus: params.readStatus ?? 'all',
    });

    return {
      items: result.items,
      meta: {
        page,
        perPage,
        total: result.total,
        totalPages: Math.ceil(result.total / perPage),
      },
    };
  }

  static async markAsRead(params: {
    instituteId: string;
    userId: string;
    notificationId: string;
    readStatus: boolean;
  }) {
    const result = await NotificationRepository.markRead(params);
    if (result.count === 0) {
      throw new ApiError('Notification not found', 404, 'NOT_FOUND');
    }

    // Trigger update for real-time badge
    const { emitUnreadCount } = await import('../../config/socket');
    const count = await NotificationRepository.getUnreadCount(params.instituteId, params.userId);
    emitUnreadCount(params.instituteId, params.userId, count);

    const { emitInstituteDashboardSync } = await import('../../config/socket');
    emitInstituteDashboardSync(params.instituteId, 'notification_updated', {
      user_id: params.userId,
      notification_id: params.notificationId,
      read_status: params.readStatus,
    });

    return { success: true };
  }

  static async markAllAsRead(params: { instituteId: string; userId: string }) {
    const result = await NotificationRepository.markAllRead(params);

    // Trigger update for real-time badge
    const { emitUnreadCount } = await import('../../config/socket');
    emitUnreadCount(params.instituteId, params.userId, 0);

    const { emitInstituteDashboardSync } = await import('../../config/socket');
    emitInstituteDashboardSync(params.instituteId, 'notification_updated', {
      user_id: params.userId,
      read_all: true,
    });

    return { updated: result.count };
  }

  static async deleteMyNotification(params: { instituteId: string; userId: string; notificationId: string }) {
    const result = await NotificationRepository.removeByIdForUser(params);
    if (result.count === 0) {
      throw new ApiError('Notification not found', 404, 'NOT_FOUND');
    }

    const { emitUnreadCount, emitInstituteDashboardSync } = await import('../../config/socket');
    const count = await NotificationRepository.getUnreadCount(params.instituteId, params.userId);
    emitUnreadCount(params.instituteId, params.userId, count);
    emitInstituteDashboardSync(params.instituteId, 'notification_deleted', {
      user_id: params.userId,
      notification_id: params.notificationId,
      global: false,
    });

    return { deleted: result.count };
  }

  static async deleteGlobalNotification(params: { instituteId: string; requesterRole: string; notificationId: string }) {
    const notification = await NotificationRepository.findById(params.instituteId, params.notificationId);
    if (!notification) {
      throw new ApiError('Notification not found', 404, 'NOT_FOUND');
    }

    const meta = (notification.meta ?? {}) as Record<string, any>;
    const roleTarget = (notification.role_target ?? '').toString();

    if (params.requesterRole === 'teacher') {
      const teacherAllowedTargets = new Set(['student', 'parent']);
      if (!teacherAllowedTargets.has(roleTarget)) {
        throw new ApiError('Teachers can only delete teacher-created student/parent notifications', 403, 'FORBIDDEN');
      }
    }

    const broadcastId = typeof meta.broadcast_id === 'string' ? meta.broadcast_id : '';
    if (broadcastId) {
      const affectedUserIds = await NotificationRepository.findUserIdsByBroadcastId(params.instituteId, broadcastId);
      const result = await NotificationRepository.removeByBroadcastId(params.instituteId, broadcastId);
      const { emitUnreadCount, emitInstituteDashboardSync } = await import('../../config/socket');
      await Promise.all(
        affectedUserIds.map(async (userId) => {
          const count = await NotificationRepository.getUnreadCount(params.instituteId, userId);
          emitUnreadCount(params.instituteId, userId, count);
        }),
      );
      emitInstituteDashboardSync(params.instituteId, 'notification_deleted', {
        notification_id: params.notificationId,
        global: true,
        scope: 'broadcast',
        affected_users: affectedUserIds.length,
      });
      return { deleted: result.count, scope: 'broadcast' };
    }

    const announcementId = typeof meta.announcement_id === 'string' ? meta.announcement_id : '';
    if (announcementId) {
      const affectedUserIds = await NotificationRepository.findUserIdsByAnnouncementId(params.instituteId, announcementId);
      const result = await NotificationRepository.removeByAnnouncementId(params.instituteId, announcementId);
      const { emitUnreadCount, emitInstituteDashboardSync } = await import('../../config/socket');
      await Promise.all(
        affectedUserIds.map(async (userId) => {
          const count = await NotificationRepository.getUnreadCount(params.instituteId, userId);
          emitUnreadCount(params.instituteId, userId, count);
        }),
      );
      emitInstituteDashboardSync(params.instituteId, 'notification_deleted', {
        notification_id: params.notificationId,
        global: true,
        scope: 'announcement',
        affected_users: affectedUserIds.length,
      });
      return { deleted: result.count, scope: 'announcement' };
    }

    const affectedUserIds = await NotificationRepository.findUserIdsByNotificationId(params.instituteId, notification.id);
    const fallback = await NotificationRepository.removeById(params.instituteId, notification.id);
    const { emitUnreadCount, emitInstituteDashboardSync } = await import('../../config/socket');
    await Promise.all(
      affectedUserIds.map(async (userId) => {
        const count = await NotificationRepository.getUnreadCount(params.instituteId, userId);
        emitUnreadCount(params.instituteId, userId, count);
      }),
    );
    emitInstituteDashboardSync(params.instituteId, 'notification_deleted', {
      notification_id: notification.id,
      global: true,
      scope: 'single',
      affected_users: affectedUserIds.length,
    });
    return { deleted: fallback.count, scope: 'single' };
  }

  static async deleteByAnnouncement(params: { instituteId: string; announcementId: string }) {
    const result = await NotificationRepository.removeByAnnouncementId(params.instituteId, params.announcementId);
    return { deleted: result.count };
  }

  static async getHealth(instituteId: string) {
    const [activeTokens, latestFailure] = await Promise.all([
      NotificationRepository.countActiveDeviceTokensByInstitute(instituteId),
      NotificationRepository.getLatestDeliveryFailure(instituteId),
    ]);

    return {
      firebaseConfigured: Boolean(firebaseMessaging()),
      activeDeviceTokens: activeTokens,
      latestFailure: latestFailure
        ? {
            id: latestFailure.id,
            notificationId: latestFailure.notification_id,
            userId: latestFailure.user_id,
            token: latestFailure.token,
            errorMessage: latestFailure.error_message,
            createdAt: latestFailure.created_at,
          }
        : null,
    };
  }

  static async getUnreadCount(instituteId: string, userId: string) {
    return NotificationRepository.getUnreadCount(instituteId, userId);
  }
}

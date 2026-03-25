import { Router } from 'express';
import { authenticateJWT, requireRole } from '../../middleware/auth.middleware';
import { tenantMiddleware } from '../../middleware/tenant.middleware';
import { validate } from '../../middleware/validate.middleware';
import { NotificationController } from './notification.controller';
import {
  listNotificationsQuerySchema,
  markNotificationReadSchema,
  registerDeviceTokenSchema,
  sendNotificationSchema,
  unregisterDeviceTokenSchema,
} from './notification.validator';

const router = Router();

router.use(authenticateJWT);
router.use(tenantMiddleware);

router.get('/', validate(listNotificationsQuerySchema), NotificationController.listMy);
router.patch('/read-all', NotificationController.markAllRead);
router.patch('/:id/read', validate(markNotificationReadSchema), NotificationController.markRead);
router.delete('/:id', NotificationController.deleteMine);
router.delete('/:id/global', requireRole('admin', 'teacher'), NotificationController.deleteGlobal);

router.post('/register-token', validate(registerDeviceTokenSchema), NotificationController.registerToken);
router.delete('/register-token', validate(unregisterDeviceTokenSchema), NotificationController.unregisterToken);

router.post('/send', requireRole('admin', 'teacher'), validate(sendNotificationSchema), NotificationController.sendManual);
router.post('/trigger/fee-reminders', requireRole('admin'), NotificationController.triggerFeeReminders);
router.post('/trigger/class-reminders', requireRole('admin'), NotificationController.triggerClassReminders);
router.post('/trigger/daily-revenue-summary', requireRole('admin'), NotificationController.triggerDailyRevenueSummary);

export default router;

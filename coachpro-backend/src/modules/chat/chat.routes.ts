import { Router } from 'express';
import { ChatController } from './chat.controller';
import { authenticateJWT, requireRole } from '../../middleware/auth.middleware';
import { tenantMiddleware } from '../../middleware/tenant.middleware';

const router = Router();

router.use(authenticateJWT);
router.use(tenantMiddleware);

// Chat rooms (batch-based conversations)
router.get('/rooms', ChatController.getRooms);

// Messages within a batch chat room
router.get('/batch/:batchId/history', requireRole('admin', 'teacher', 'student'), ChatController.getHistory);
router.post('/batch/:batchId/messages', requireRole('admin', 'teacher', 'student'), ChatController.sendMessage);

// Message management
router.delete('/message/:id', requireRole('admin', 'teacher'), ChatController.deleteMessage);

export default router;

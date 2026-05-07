import { Router } from 'express';
import { YoutubeController } from './youtube.controller';
import { authenticateJWT, requireRole } from '../../middleware/auth.middleware';
import { tenantMiddleware } from '../../middleware/tenant.middleware';

const router = Router();
const controller = new YoutubeController();

// 1. Generate Auth URL
router.get('/auth', authenticateJWT, tenantMiddleware, requireRole('admin'), controller.getAuthUrl);

// 2. The Google Callback
// Notice: We don't use requireAuth here because Google hits it directly.
router.get('/callback', controller.handleCallback);

// 3. Create a Live Stream (Admin or Teacher)
router.post('/live', authenticateJWT, tenantMiddleware, requireRole('teacher', 'admin'), controller.createStream);

export default router;

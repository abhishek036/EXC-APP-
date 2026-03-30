import { Router } from 'express';
import { UploadController } from './upload.controller';
import { generalUpload } from '../../middleware/upload';
import { authenticateJWT, requireRole } from '../../middleware/auth.middleware';

const router = Router();
const controller = new UploadController();

// Publicly readable file proxy (since bucket is private)
router.get('/file/:key(*)', (req, res, next) => controller.downloadFile(req, res).catch(next));

// Protect actual uploads
router.use(authenticateJWT);

// Only admins and teachers should upload study materials
router.post('/', requireRole('admin', 'teacher'), generalUpload.single('file'), (req, res, next) => controller.uploadFile(req, res).catch(next));

export default router;

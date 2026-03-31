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

// Students need to upload for doubts, Admins/Teachers for materials
router.post('/', requireRole('admin', 'teacher', 'student'), generalUpload.single('file'), (req, res, next) => controller.uploadFile(req, res).catch(next));

export default router;

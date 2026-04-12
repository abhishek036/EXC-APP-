import { Router } from 'express';
import { AppUpdateController } from './app-update.controller';

const router = Router();
const controller = new AppUpdateController();

router.get('/policy', controller.getPolicy);

export default router;

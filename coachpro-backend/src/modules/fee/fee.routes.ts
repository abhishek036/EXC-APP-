import { Router } from 'express';
import { FeeController } from './fee.controller';
import { validate } from '../../middleware/validate.middleware';
import { defineFeeStructureSchema, generateMonthlyFeesSchema, recordFeePaymentSchema } from './fee.validator';
import { authenticateJWT, requireRole } from '../../middleware/auth.middleware';
import { tenantMiddleware } from '../../middleware/tenant.middleware';

const router = Router();
const controller = new FeeController();

router.use(authenticateJWT, tenantMiddleware);

// Config API
router.post('/structure', requireRole('admin'), validate(defineFeeStructureSchema), controller.defineStructure);
router.get('/structure/:batchId', requireRole('admin', 'teacher'), controller.getStructure);

// Records and Generation API
router.post('/generate', requireRole('admin'), validate(generateMonthlyFeesSchema), controller.generateMonthly);
router.get('/records', requireRole('admin', 'student', 'parent'), controller.getRecords);

// Payment Logging
// Allow students and parents to record payments (not only admin)
router.post('/pay', requireRole(['admin','student','parent']), validate(recordFeePaymentSchema), controller.recordPayment);

export default router;

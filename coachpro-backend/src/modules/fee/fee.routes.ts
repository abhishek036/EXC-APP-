import { Router } from 'express';
import { FeeController } from './fee.controller';
import { validate } from '../../middleware/validate.middleware';
import {
	defineFeeStructureSchema,
	generateMonthlyFeesSchema,
	recordFeePaymentSchema,
	submitFeeProofSchema,
	reviewFeePaymentSchema,
} from './fee.validator';
import { authenticateJWT, requireRole } from '../../middleware/auth.middleware';
import { tenantMiddleware } from '../../middleware/tenant.middleware';

const router = Router();
const controller = new FeeController();

router.use(authenticateJWT, tenantMiddleware);

// Config API
router.post('/structure', requireRole('admin'), validate(defineFeeStructureSchema), controller.defineStructure);
router.get('/structure/:batchId', requireRole('admin', 'teacher', 'sub_admin'), controller.getStructure);

// Records and Generation API
router.post('/generate', requireRole('admin'), validate(generateMonthlyFeesSchema), controller.generateMonthly);
router.get('/records', requireRole('admin', 'sub_admin'), controller.getRecords);

// Payment Logging (admin-verified)
router.post('/pay', requireRole('admin'), validate(recordFeePaymentSchema), controller.recordPayment);

// Student manual QR flow
router.post('/payments/proof', requireRole('student'), validate(submitFeeProofSchema), controller.submitPaymentProof);
router.get('/payments/my', requireRole('student'), controller.getMyPaymentProofs);

// Admin review flow
router.get('/payments/review', requireRole('admin', 'sub_admin'), controller.getPaymentsForReview);
router.post('/payments/:paymentId/approve', requireRole('admin'), validate(reviewFeePaymentSchema), controller.approvePaymentProof);
router.post('/payments/:paymentId/reject', requireRole('admin'), validate(reviewFeePaymentSchema), controller.rejectPaymentProof);

export default router;

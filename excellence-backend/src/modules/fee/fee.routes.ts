import { Router } from 'express';
import rateLimit from 'express-rate-limit';
import { FeeController } from './fee.controller';
import { validate } from '../../middleware/validate.middleware';
import {
	defineFeeStructureSchema,
	generateMonthlyFeesSchema,
	recordFeePaymentSchema,
	submitFeeProofSchema,
	reviewFeePaymentSchema,
	adjustFeeRecordSchema,
} from './fee.validator';
import { authenticateJWT, requireRole } from '../../middleware/auth.middleware';
import { tenantMiddleware } from '../../middleware/tenant.middleware';

const router = Router();
const controller = new FeeController();

const paymentProofLimiter = rateLimit({
	windowMs: 60 * 60 * 1000,
	max: Number.parseInt(process.env.PAYMENT_PROOF_RATE_LIMIT || '5', 10),
	standardHeaders: true,
	legacyHeaders: false,
	validate: false,
	keyGenerator: (req) => `${req.instituteId || 'unknown'}:${req.user?.userId || req.ip}`,
	handler: (req, res) => {
		res.status(429).json({
			success: false,
			error: {
				code: 'RATE_LIMITED',
				message: 'Too many payment proof submissions. Please try again later.',
				ref: req.requestId,
			},
		});
	},
});

router.use(authenticateJWT, tenantMiddleware);

// Config API
router.post('/structure', requireRole('admin'), validate(defineFeeStructureSchema), controller.defineStructure);
router.get('/structure/:batchId', requireRole('admin', 'teacher', 'sub_admin'), controller.getStructure);

// Records and Generation API
router.post('/generate', requireRole('admin'), validate(generateMonthlyFeesSchema), controller.generateMonthly);
router.get('/records', requireRole('admin', 'sub_admin'), controller.getRecords);

// Payment Logging (admin-verified)
router.post('/pay', requireRole('admin'), validate(recordFeePaymentSchema), controller.recordPayment);
router.post('/adjust', requireRole('admin'), validate(adjustFeeRecordSchema), controller.adjustFeeRecord);

// Student manual QR flow
router.post('/payments/proof', requireRole('student', 'parent'), paymentProofLimiter, validate(submitFeeProofSchema), controller.submitPaymentProof);
router.get('/payments/my', requireRole('student', 'parent'), controller.getMyPaymentProofs);

// Admin review flow
router.get('/payments/review', requireRole('admin', 'sub_admin'), controller.getPaymentsForReview);
router.post('/payments/:paymentId/approve', requireRole('admin'), validate(reviewFeePaymentSchema), controller.approvePaymentProof);
router.post('/payments/:paymentId/reject', requireRole('admin'), validate(reviewFeePaymentSchema), controller.rejectPaymentProof);

export default router;

import { Router } from 'express';
import { AuthController } from './auth.controller';
import { validate } from '../../middleware/validate.middleware';
import { sendOtpSchema, verifyOtpSchema, loginSchema, passwordChangeSchema, passwordResetSchema, updateMeSchema } from './auth.validator';
import { authenticateJWT } from '../../middleware/auth.middleware';

const router = Router();
const authController = new AuthController();

// Public Routes
router.post('/otp/send', validate(sendOtpSchema), authController.sendOtp);
router.post('/otp/verify', validate(verifyOtpSchema), authController.verifyOtp);
router.post('/login', validate(loginSchema), authController.login);
router.post('/password/reset', validate(passwordResetSchema), authController.resetPassword);

// Refresh Token (can sometimes be public if refresh token is in body, but often relies on cookie/authorization)
router.post('/refresh', authController.refreshToken);

// Protected Routes
router.post('/logout', authenticateJWT, authController.logout);
router.get('/me', authenticateJWT, authController.getMe);
router.patch('/me', authenticateJWT, validate(updateMeSchema), authController.updateMe);
router.post('/password/change', authenticateJWT, validate(passwordChangeSchema), authController.changePassword);
router.patch('/me/name', authenticateJWT, authController.updateName);

export default router;

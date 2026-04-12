import { Request, Response, NextFunction } from 'express';
import { AuthService } from './auth.service';
import { sendResponse } from '../../utils/response';
import { UploadController } from '../upload/upload.controller';

export class AuthController {
  private authService: AuthService;
  private uploadController: UploadController;

  constructor() {
    this.authService = new AuthService();
    this.uploadController = new UploadController();
  }

  sendOtp = async (req: Request, res: Response, next: NextFunction) => {
    console.log(`[CONTROLLER] Received sendOtp request: ${req.method} ${req.url}`);
    try {
      const { phone, purpose, joinCode } = req.body;
      const data = await this.authService.sendOtp(phone, purpose, joinCode);
      return sendResponse({ res, data, message: 'OTP sent successfully' });
    } catch (error) {
      next(error);
    }
  };

  verifyOtp = async (req: Request, res: Response, next: NextFunction) => {
    console.log(`[CONTROLLER] Received verifyOtp request for phone: "${req.body.phone}", otp: "${req.body.otp}"`);
    try {
      const { phone, otp, purpose, joinCode, role } = req.body;
      const data = await this.authService.verifyOtp(phone, otp, purpose, joinCode, role);
      return sendResponse({ res, data, message: 'OTP verified successfully' });
    } catch (error) {
      next(error);
    }
  };

  login = async (req: Request, res: Response, next: NextFunction) => {
    try {
      const { phone, password, joinCode } = req.body;
      const data = await this.authService.loginWithPassword(phone, password, joinCode);
      return sendResponse({ res, data, message: 'Logged in successfully' });
    } catch (error) {
      next(error);
    }
  };

  refreshToken = async (req: Request, res: Response, next: NextFunction) => {
    try {
      // Typically taken from Authorization header (Bearer refresh_token) or req.body
      const refreshToken = req.body.refreshToken || req.headers.authorization?.split(' ')[1];
      const data = await this.authService.refreshToken(refreshToken);
      return sendResponse({ res, data, message: 'Token refreshed successfully' });
    } catch (error) {
      next(error);
    }
  };

  logout = async (req: Request, res: Response, next: NextFunction) => {
    try {
      const refreshToken = req.body.refreshToken;
      await this.authService.logout(req.user!.userId, refreshToken);
      return sendResponse({ res, data: null, message: 'Logged out successfully' });
    } catch (error) {
      next(error);
    }
  };

  getMe = async (req: Request, res: Response, next: NextFunction) => {
    try {
      const user = await this.authService.getUserProfile(req.user!.userId);
      return sendResponse({ res, data: user, message: 'User profile fetched successfully' });
    } catch (error) {
      next(error);
    }
  };

  changePassword = async (req: Request, res: Response, next: NextFunction) => {
    try {
      const { oldPassword, newPassword } = req.body;
      await this.authService.changePassword(req.user!.userId, oldPassword, newPassword);
      return sendResponse({ res, data: null, message: 'Password changed successfully' });
    } catch (error) {
      next(error);
    }
  };

  resetPassword = async (req: Request, res: Response, next: NextFunction) => {
    try {
      const { phone, otp, newPassword, joinCode } = req.body;
      await this.authService.resetPassword(phone, otp, newPassword, joinCode);
      return sendResponse({ res, data: null, message: 'Password reset successfully' });
    } catch (error) {
      next(error);
    }
  };

  updateName = async (req: Request, res: Response, next: NextFunction) => {
    try {
      const { name } = req.body;
      if (!name || name.trim().length < 2) {
        return next({ message: 'Name must be at least 2 characters', statusCode: 400 });
      }
      const userId = req.user!.userId;
      const role = req.user!.role;
      const data = await this.authService.updateMe(userId, role, { name: name.trim() });
      return sendResponse({ res, data, message: 'Name updated successfully' });
    } catch (error) {
      next(error);
    }
  };

  updateMe = async (req: Request, res: Response, next: NextFunction) => {
    try {
      const userId = req.user!.userId;
      const role = req.user!.role;
      const { name, email, phone } = req.body;

      if (email != null) {
        const trimmedEmail = String(email).trim();
        if (trimmedEmail.length > 0 && !/^\S+@\S+\.\S+$/.test(trimmedEmail)) {
          return next({ message: 'Enter a valid email address', statusCode: 400 });
        }
      }

      const data = await this.authService.updateMe(userId, role, { name, email, phone });
      return sendResponse({ res, data, message: 'Profile updated successfully' });
    } catch (error) {
      next(error);
    }
  };

  updateAvatar = async (req: Request, res: Response, next: NextFunction) => {
    try {
      if (!req.file) {
        return next({ message: 'No image file provided', statusCode: 400 });
      }

      const userId = req.user!.userId;
      const role = req.user!.role;

      const uploadResult = await this.uploadController.uploadSingleFile({
        file: req.file,
        destination: 'avatars',
        origin: `${req.protocol}://${req.get('host')}`,
      });

      const avatarUrl = uploadResult.fileUrl;

      // Persist in DB
      const data = await this.authService.updateAvatar(userId, role, avatarUrl);
      return sendResponse({ res, data, message: 'Avatar updated successfully' });
    } catch (error) {
      next(error);
    }
  };
}

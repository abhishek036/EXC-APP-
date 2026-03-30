import { Request, Response, NextFunction } from 'express';
import { AuthService } from './auth.service';
import { sendResponse } from '../../utils/response';
import { S3Client } from '@aws-sdk/client-s3';
import { Upload } from '@aws-sdk/lib-storage';
import { v4 as uuidv4 } from 'uuid';
import { extname } from 'path';

const s3 = new S3Client({
  region: process.env.B2_REGION || 'us-east-005',
  endpoint: process.env.B2_ENDPOINT || 'https://s3.us-east-005.backblazeb2.com',
  credentials: {
    accessKeyId: process.env.B2_KEY_ID!,
    secretAccessKey: process.env.B2_APP_KEY!,
  },
});

export class AuthController {
  private authService: AuthService;

  constructor() {
    this.authService = new AuthService();
  }

  sendOtp = async (req: Request, res: Response, next: NextFunction) => {
    console.log(`[CONTROLLER] Received sendOtp request: ${req.method} ${req.url}`);
    try {
      const { phone, purpose, joinCode, role } = req.body;
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
      const { phone, otp, newPassword } = req.body;
      await this.authService.resetPassword(phone, otp, newPassword);
      return sendResponse({ res, data: null, message: 'Password reset successfully' });
    } catch (error) {
      next(error);
    }
  };

  updateName = async (req: Request, res: Response, next: NextFunction) => {
    try {
      const { name } = req.body;
      if (!name || name.trim().length < 2) {
        return next({ message: 'Name must be at least 2 characters', status: 400 });
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
          return next({ message: 'Enter a valid email address', status: 400 });
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
        return next({ message: 'No image file provided', status: 400 });
      }

      const userId = req.user!.userId;
      const role = req.user!.role;

      // Upload to B2
      const bucketName = process.env.B2_BUCKET_NAME!;
      const ext = extname(req.file.originalname) || '.jpg';
      const fileKey = `avatars/${userId}${ext}`;

      const uploader = new Upload({
        client: s3,
        params: {
          Bucket: bucketName,
          Key: fileKey,
          Body: req.file.buffer,
          ContentType: req.file.mimetype,
        },
      });

      await uploader.done();

      // Build proxied URL
      const avatarUrl = `${req.protocol}://${req.get('host')}/api/upload/file/${encodeURIComponent(fileKey)}`;

      // Persist in DB
      const data = await this.authService.updateAvatar(userId, role, avatarUrl);
      return sendResponse({ res, data, message: 'Avatar updated successfully' });
    } catch (error) {
      next(error);
    }
  };
}

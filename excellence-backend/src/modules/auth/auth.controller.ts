import { Request, Response, NextFunction } from 'express';
import { AuthService } from './auth.service';
import { sendResponse } from '../../utils/response';
import { UploadController } from '../upload/upload.controller';

const parseDurationToMs = (value: string, fallbackMs: number): number => {
  const raw = String(value || '').trim();
  const match = raw.match(/^(\d+)\s*([smhd])?$/i);
  if (!match) return fallbackMs;

  const amount = Number.parseInt(match[1], 10);
  if (!Number.isFinite(amount) || amount <= 0) return fallbackMs;

  const unit = (match[2] || 's').toLowerCase();
  const unitMs: Record<string, number> = {
    s: 1000,
    m: 60 * 1000,
    h: 60 * 60 * 1000,
    d: 24 * 60 * 60 * 1000,
  };

  return amount * (unitMs[unit] || 1000);
};

const refreshCookieMaxAgeMs = (() => {
  const fallback = 14 * 24 * 60 * 60 * 1000;
  const parsed = parseDurationToMs(process.env.JWT_REFRESH_EXPIRES_IN || '14d', fallback);
  const minMs = 7 * 24 * 60 * 60 * 1000;
  const maxMs = 30 * 24 * 60 * 60 * 1000;
  return Math.max(minMs, Math.min(maxMs, parsed));
})();

const buildRefreshCookieOptions = () => ({
  httpOnly: true,
  secure: process.env.NODE_ENV === 'production',
  sameSite: 'strict' as const,
  path: '/api/auth',
  maxAge: refreshCookieMaxAgeMs,
});

const readCookie = (req: Request, key: string): string | undefined => {
  const header = String(req.headers.cookie || '');
  if (!header) return undefined;

  const encodedKey = `${encodeURIComponent(key)}=`;
  const parts = header.split(';').map((part) => part.trim());
  for (const part of parts) {
    if (!part.startsWith(encodedKey)) continue;
    const rawValue = part.slice(encodedKey.length);
    try {
      return decodeURIComponent(rawValue);
    } catch {
      return rawValue;
    }
  }

  return undefined;
};

const maskPhone = (value: string): string => {
  const raw = String(value || '').replace(/\D/g, '');
  if (raw.length <= 4) return raw;
  return `${raw.slice(0, 2)}******${raw.slice(-2)}`;
};

export class AuthController {
  private authService: AuthService;
  private uploadController: UploadController;

  constructor() {
    this.authService = new AuthService();
    this.uploadController = new UploadController();
  }

  sendOtp = async (req: Request, res: Response, next: NextFunction) => {
    console.log(`[AUTH] sendOtp request: ${req.method} ${req.url} phone=${maskPhone(req.body?.phone)}`);
    try {
      const { phone, purpose, joinCode } = req.body;
      const data = await this.authService.sendOtp(phone, purpose, joinCode);
      return sendResponse({ res, data, message: 'OTP sent successfully' });
    } catch (error) {
      next(error);
    }
  };

  verifyOtp = async (req: Request, res: Response, next: NextFunction) => {
    console.log(`[AUTH] verifyOtp request received for phone: "${maskPhone(req.body?.phone)}"`);
    try {
      const { phone, otp, purpose, joinCode, role } = req.body;
      const data = await this.authService.verifyOtp(phone, otp, purpose, joinCode, role);
      if ((data as any)?.refreshToken) {
        res.cookie('refreshToken', (data as any).refreshToken, buildRefreshCookieOptions());
      }
      return sendResponse({ res, data, message: 'OTP verified successfully' });
    } catch (error) {
      next(error);
    }
  };

  login = async (req: Request, res: Response, next: NextFunction) => {
    try {
      const { phone, password, joinCode } = req.body;
      const data = await this.authService.loginWithPassword(phone, password, joinCode);
      if ((data as any)?.refreshToken) {
        res.cookie('refreshToken', (data as any).refreshToken, buildRefreshCookieOptions());
      }
      return sendResponse({ res, data, message: 'Logged in successfully' });
    } catch (error) {
      next(error);
    }
  };

  refreshToken = async (req: Request, res: Response, next: NextFunction) => {
    try {
      const refreshToken =
        readCookie(req, 'refreshToken') ||
        req.body.refreshToken ||
        req.headers.authorization?.split(' ')[1];
      const data = await this.authService.refreshToken(refreshToken);
      if ((data as any)?.refreshToken) {
        res.cookie('refreshToken', (data as any).refreshToken, buildRefreshCookieOptions());
      }
      return sendResponse({ res, data, message: 'Token refreshed successfully' });
    } catch (error) {
      next(error);
    }
  };

  logout = async (req: Request, res: Response, next: NextFunction) => {
    try {
      const refreshToken = req.body.refreshToken || readCookie(req, 'refreshToken');
      await this.authService.logout(req.user!.userId, refreshToken);
      res.clearCookie('refreshToken', {
        httpOnly: true,
        secure: process.env.NODE_ENV === 'production',
        sameSite: 'strict',
        path: '/api/auth',
      });
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

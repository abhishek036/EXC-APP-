import { Request, Response, NextFunction } from 'express';
import { AuthService } from './auth.service';
import { sendResponse } from '../../utils/response';

export class AuthController {
  private authService: AuthService;

  constructor() {
    this.authService = new AuthService();
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
      const { phone, otp, purpose, joinCode } = req.body;
      const data = await this.authService.verifyOtp(phone, otp, purpose, joinCode);
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
      const { prisma } = require('../../server');
      const userId = req.user!.userId;
      const role = req.user!.role;
      // Update the name on the role-specific profile
      if (role === 'student') {
        await prisma.student.updateMany({ where: { user_id: userId }, data: { name: name.trim() } });
      } else if (role === 'teacher') {
        await prisma.teacher.updateMany({ where: { user_id: userId }, data: { name: name.trim() } });
      } else if (role === 'parent') {
        await prisma.parent.updateMany({ where: { user_id: userId }, data: { name: name.trim() } });
      }
      return sendResponse({ res, data: { name: name.trim() }, message: 'Name updated successfully' });
    } catch (error) {
      next(error);
    }
  };

  updateMe = async (req: Request, res: Response, next: NextFunction) => {
    try {
      const userId = req.user!.userId;
      const role = req.user!.role;
      const { name, email, phone } = req.body;
      const data = await this.authService.updateMe(userId, role, { name, email, phone });
      return sendResponse({ res, data, message: 'Profile updated successfully' });
    } catch (error) {
      next(error);
    }
  };
}

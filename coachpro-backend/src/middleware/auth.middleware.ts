import { Request, Response, NextFunction } from 'express';
import jwt from 'jsonwebtoken';
import { ApiError } from './error.middleware';
import { prisma } from '../server';

interface JwtPayload {
  userId: string;
  role: string;
  instituteId: string;
  phone: string;
  iat?: number;
}

declare global {
  namespace Express {
    interface Request {
      user?: JwtPayload;
      instituteId?: string;
    }
  }
}

export const authenticateJWT = async (req: Request, res: Response, next: NextFunction) => {
  const authHeader = req.headers.authorization;

  const jwtSecret = process.env.JWT_SECRET;
  if (!jwtSecret || jwtSecret.trim().length < 16) {
    return next(new ApiError('Server auth configuration missing', 500, 'AUTH_CONFIG_MISSING'));
  }

  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    return next(new ApiError('No token provided', 401, 'UNAUTHORIZED'));
  }

  const token = authHeader.split(' ')[1];

  try {
    const decoded = jwt.verify(token, jwtSecret) as JwtPayload;
    
    // Check if user still exists and is active (Optional but recommended)
    const activeUser = await prisma.user.findFirst({
        where: { id: decoded.userId, is_active: true }
    });

    if (!activeUser) {
        return next(new ApiError('User no longer exists or is inactive', 401, 'USER_INACTIVE'));
    }

    const latestSession = await prisma.refreshToken.findFirst({
      where: {
        user_id: decoded.userId,
        revoked_at: null,
        expires_at: { gt: new Date() },
      },
      orderBy: { created_at: 'desc' },
      select: { created_at: true },
    });

    if (latestSession?.created_at && decoded.iat) {
      const tokenIssuedAtSec = decoded.iat;
      const latestSessionSec = Math.floor(new Date(latestSession.created_at).getTime() / 1000);
      if (tokenIssuedAtSec < latestSessionSec) {
        return next(new ApiError('Session expired due to login on another device', 401, 'SESSION_REVOKED'));
      }
    }

    req.user = decoded;
    next();
  } catch (error: any) {
    if (error?.name === 'TokenExpiredError') {
      return next(new ApiError('Token expired', 401, 'TOKEN_EXPIRED'));
    }
    next(new ApiError('Invalid or expired token', 401, 'INVALID_TOKEN'));
  }
};

// Role Checking Middleware — accepts either a spread or an array
export const requireRole = (rolesOrFirst: string | string[], ...rest: string[]) => {
    const roles: string[] = Array.isArray(rolesOrFirst) ? rolesOrFirst : [rolesOrFirst, ...rest];
    return (req: Request, res: Response, next: NextFunction) => {
        if (!req.user) {
            return next(new ApiError('No user found in request', 401, 'UNAUTHORIZED'));
        }

        if (!roles.includes(req.user.role)) {
            return next(new ApiError('You do not have permission to perform this action', 403, 'FORBIDDEN'));
        }

        next();
    }
}


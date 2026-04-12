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

type ActiveUserAuthSnapshot = {
  id: string;
  role: string;
  institute_id: string;
  phone: string;
  last_login_at: Date | null;
};

const JWT_VERIFY_ALGORITHMS: jwt.Algorithm[] = ['HS256'];
const JWT_CLOCK_TOLERANCE_SECONDS = Number.parseInt(process.env.JWT_CLOCK_TOLERANCE_SECONDS || '300', 10);

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
  if (!jwtSecret || jwtSecret.trim().length < 32) {
    return next(new ApiError('Server auth configuration missing', 500, 'AUTH_CONFIG_MISSING'));
  }

  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    return next(new ApiError('No token provided', 401, 'UNAUTHORIZED'));
  }

  const token = authHeader.split(' ')[1];

  try {
    const decoded = jwt.verify(token, jwtSecret, {
      algorithms: JWT_VERIFY_ALGORITHMS,
      clockTolerance: Number.isFinite(JWT_CLOCK_TOLERANCE_SECONDS) ? JWT_CLOCK_TOLERANCE_SECONDS : 300,
    }) as JwtPayload;

    if (!decoded || typeof decoded.userId !== 'string' || typeof decoded.role !== 'string') {
      return next(new ApiError('Invalid token payload', 401, 'INVALID_TOKEN'));
    }
    
    // Check if user still exists and is active (Optional but recommended)
    const activeUser = await prisma.user.findFirst({
      where: { id: decoded.userId, is_active: true },
      select: {
        id: true,
        role: true,
        institute_id: true,
        phone: true,
        last_login_at: true,
      },
    }) as ActiveUserAuthSnapshot | null;

    if (!activeUser) {
        return next(new ApiError('User no longer exists or is inactive', 401, 'USER_INACTIVE'));
    }

    if (activeUser?.last_login_at && decoded.iat) {
      const tokenIssuedAtSec = decoded.iat;
      const lastLoginSec = Math.floor(new Date(activeUser.last_login_at).getTime() / 1000);
      const allowedClockSkewSec = 10;
      if (tokenIssuedAtSec + allowedClockSkewSec < lastLoginSec) {
        return next(new ApiError('Session expired due to login on another device', 401, 'SESSION_REVOKED'));
      }
    }

    req.user = {
      ...decoded,
      role: (activeUser.role || decoded.role).toLowerCase(),
      instituteId: activeUser.institute_id || decoded.instituteId,
      phone: activeUser.phone || decoded.phone,
    };
    req.instituteId = req.user.instituteId;
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
    const allowedRoles = roles.map(r => r.trim().toLowerCase());

    return (req: Request, res: Response, next: NextFunction) => {
        if (!req.user) {
            return next(new ApiError('No user found in request', 401, 'UNAUTHORIZED'));
        }

        const userRole = req.user.role.trim().toLowerCase();
        const canAccessAsSuperAdmin = userRole === 'super_admin' && allowedRoles.includes('admin');

        if (!allowedRoles.includes(userRole) && !canAccessAsSuperAdmin) {
            return next(new ApiError('You do not have permission to perform this action', 403, 'FORBIDDEN'));
        }
        next();
    };
};

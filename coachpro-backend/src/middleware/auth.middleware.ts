import { Request, Response, NextFunction } from 'express';
import jwt from 'jsonwebtoken';
import { ApiError } from './error.middleware';
import { prisma } from '../server';

interface JwtPayload {
  userId: string;
  role: string;
  instituteId: string;
  phone: string;
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

  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    return next(new ApiError('No token provided', 401, 'UNAUTHORIZED'));
  }

  const token = authHeader.split(' ')[1];

  try {
    const decoded = jwt.verify(token, process.env.JWT_SECRET as string) as JwtPayload;
    
    // Check if user still exists and is active (Optional but recommended)
    const activeUser = await prisma.user.findFirst({
        where: { id: decoded.userId, is_active: true }
    });

    if (!activeUser) {
        return next(new ApiError('User no longer exists or is inactive', 401, 'USER_INACTIVE'));
    }

    req.user = decoded;
    next();
  } catch (error) {
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


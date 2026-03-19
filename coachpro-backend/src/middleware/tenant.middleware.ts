import { Request, Response, NextFunction } from 'express';
import { ApiError } from './error.middleware';
import { prisma } from '../server';

export const tenantMiddleware = async (req: Request, res: Response, next: NextFunction) => {
  if (!req.user) {
      return next(new ApiError('Authentication required before tenant middleware', 401, 'UNAUTHORIZED'));
  }

  const instituteId = req.user.instituteId;
  
  // Example of deep tenant isolation check based on dynamic route params if we were doing generic multi-tenant checks
  // Let's implement specific module checks inside the controllers or repositories.
  // Here we just attach it safely.
  
  req.instituteId = instituteId;
  next();
};

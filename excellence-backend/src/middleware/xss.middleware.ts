import { Request, Response, NextFunction } from 'express';
import xss from 'xss';

const sanitizeObj = (obj: any): any => {
  if (!obj || typeof obj !== 'object') {
    return obj;
  }
  
  if (Array.isArray(obj)) {
    return obj.map((item) => {
      if (typeof item === 'string') {
        return xss(item);
      }
      if (typeof item === 'object' && item !== null) {
        return sanitizeObj(item);
      }
      return item;
    });
  }

  const sanitized: any = {};
  for (const key of Object.keys(obj)) {
    const value = obj[key];
    if (typeof value === 'string') {
      sanitized[key] = xss(value);
    } else if (typeof value === 'object' && value !== null) {
      sanitized[key] = sanitizeObj(value);
    } else {
      sanitized[key] = value;
    }
  }
  return sanitized;
};

export const xssMiddleware = (req: Request, _res: Response, next: NextFunction) => {
  if (req.body) {
    req.body = sanitizeObj(req.body);
  }
  if (req.query) {
    req.query = sanitizeObj(req.query);
  }
  if (req.params) {
    req.params = sanitizeObj(req.params);
  }
  next();
};

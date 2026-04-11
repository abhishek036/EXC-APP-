import { Request, Response, NextFunction } from 'express';

// Standard Error Interface
export interface AppError extends Error {
  statusCode: number;
  code: string;
  isOperational: boolean;
  fields?: Record<string, string>;
}

// Custom Error Class
export class ApiError extends Error implements AppError {
  public statusCode: number;
  public code: string;
  public isOperational: boolean;
  public fields?: Record<string, string>;

  constructor(message: string, statusCode: number, code: string = 'INTERNAL_ERROR', fields?: Record<string, string>) {
    super(message);
    this.statusCode = statusCode;
    this.code = code;
    this.isOperational = true;
    this.fields = fields;

    Error.captureStackTrace(this, this.constructor);
  }
}

// Global Error Handler Middleware
export const errorHandler = (
  err: Error | AppError,
  req: Request,
  res: Response,
  _next: NextFunction
) => {
  let statusCode = 500;
  let code = 'INTERNAL_ERROR';
  let message = 'An unexpected error occurred';
  let fields;

  // Check specific error types first (most specific → least specific)
  if (err.name === 'JsonWebTokenError') {
    code = 'UNAUTHORIZED';
    statusCode = 401;
    message = 'Invalid token. Please log in again.';
  } else if (err.name === 'TokenExpiredError') {
    code = 'TOKEN_EXPIRED';
    statusCode = 401;
    message = 'Your token has expired. Please log in again.';
  } else if (err.name === 'PrismaClientKnownRequestError') {
    // Only set to 400 if not already wrapped in an ApiError with a specific status
    code = 'DATABASE_ERROR';
    statusCode = ('statusCode' in err) ? err.statusCode : 400;
    message = err.message;
  } else if ('statusCode' in err) {
    // AppError / ApiError
    statusCode = err.statusCode;
    code = err.code;
    message = err.message;
    fields = err.fields;
  } else if (err?.message) {
    // Preserve non-operational error message so debugging is possible from client logs.
    message = err.message;
  }

  console.error(
    `[ERROR] ${req.method} ${req.originalUrl} -> ${statusCode} ${code}: ${message}`,
    err,
  );

  res.status(statusCode).json({
    success: false,
    error: {
      code,
      message,
      ...(fields && { fields }),
      ...(process.env.NODE_ENV === 'development' && { stack: err.stack })
    }
  });
};

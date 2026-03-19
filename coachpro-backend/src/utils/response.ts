import { Response } from 'express';

interface SuccessResponse<T> {
  res: Response;
  data: T;
  message?: string;
  statusCode?: number;
  meta?: {
    page: number;
    perPage: number;
    total: number;
    totalPages: number;
  };
}

export const sendResponse = <T>({
  res,
  data,
  message = 'Success',
  statusCode = 200,
  meta,
}: SuccessResponse<T>) => {
  return res.status(statusCode).json({
    success: true,
    data,
    message,
    ...(meta && { meta }),
  });
};

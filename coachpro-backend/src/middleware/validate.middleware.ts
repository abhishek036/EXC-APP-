import { Request, Response, NextFunction } from 'express';
import { AnyZodObject, ZodError } from 'zod';
import { ApiError } from './error.middleware';

export const validate = (schema: AnyZodObject) => {
  return async (req: Request, res: Response, next: NextFunction) => {
    try {
      await schema.parseAsync({
        body: req.body,
        query: req.query,
        params: req.params,
      });
      next();
    } catch (error) {
      if (error instanceof ZodError) {
        const fields: Record<string, string> = {};
        error.errors.forEach((e) => {
          if (e.path.length > 1) {
             fields[e.path[1] as string] = e.message;
          } else {
             fields[e.path[0] as string] = e.message;
          }
        });

        const apiError = new ApiError('Validation failed', 400, 'VALIDATION_ERROR', fields);
        console.error("Validation Error: ", fields, "Body:", req.body);
        next(apiError);
      } else {
        next(error);
      }
    }
  };
};

import type { Context } from 'hono';
import type { Env } from '../types/env';
import { AppError } from '../lib/errors';

export function errorHandler(err: Error, c: Context<{ Bindings: Env }>): Response {
  if (err instanceof AppError) {
    return c.json(
      {
        error: {
          code: err.code,
          message: err.message,
          ...(err.details ? { details: err.details } : {}),
        },
      },
      err.statusCode as 400 | 401 | 403 | 404 | 409 | 413 | 422 | 429 | 500
    );
  }

  const errWithStatus = err as Error & { statusCode?: number; code?: string; status?: number };
  const status = errWithStatus.statusCode || errWithStatus.status || 500;
  const code = errWithStatus.code || 'INTERNAL_ERROR';

  if (status < 500) {
    return c.json(
      {
        error: {
          code,
          message: err.message || 'Request error',
        },
      },
      status as 400 | 401 | 403 | 404 | 409 | 413 | 422 | 429
    );
  }

  // Hide internal database or runtime stack traces from clients
  console.error('[UNCAUGHT EXCEPTION]', err);
  return c.json(
    {
      error: {
        code: 'INTERNAL_ERROR',
        message: 'An unexpected internal error occurred.',
      },
    },
    500
  );
}

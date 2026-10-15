export class AppError extends Error {
  statusCode: number;
  code: string;
  details?: Record<string, unknown>;

  constructor(statusCode: number, code: string, message: string, details?: Record<string, unknown>) {
    super(message);
    this.statusCode = statusCode;
    this.code = code;
    this.details = details;
    this.name = 'AppError';
  }
}

export const Errors = {
  badRequest: (message: string, details?: Record<string, unknown>) =>
    new AppError(400, 'BAD_REQUEST', message, details),
  unauthorized: (message = 'Authentication required.') =>
    new AppError(401, 'UNAUTHORIZED', message),
  forbidden: (message = 'You do not have permission to perform this action.') =>
    new AppError(403, 'FORBIDDEN', message),
  notFound: (resource = 'Resource') =>
    new AppError(404, 'NOT_FOUND', `${resource} not found.`),
  conflict: (message: string) =>
    new AppError(409, 'CONFLICT', message),
  payloadTooLarge: (message = 'File size exceeds the allowed limit.') =>
    new AppError(413, 'PAYLOAD_TOO_LARGE', message),
  unprocessable: (message: string, details?: Record<string, unknown>) =>
    new AppError(422, 'UNPROCESSABLE', message, details),
  tooManyRequests: (message = 'Too many requests. Please try again later.') =>
    new AppError(429, 'TOO_MANY_REQUESTS', message),
  internal: (message = 'An internal error occurred.') =>
    new AppError(500, 'INTERNAL_ERROR', message),
};

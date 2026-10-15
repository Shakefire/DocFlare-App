import { Hono } from 'hono';
import { cors } from 'hono/cors';
import { logger } from 'hono/logger';
import { secureHeaders } from 'hono/secure-headers';
import type { Env } from './types/env';
import { authRoutes } from './routes/auth';
import { organizationRoutes } from './routes/organizations';
import { folderRoutes } from './routes/folders';
import { documentRoutes } from './routes/documents';
import { uploadRoutes } from './routes/uploads';
import { searchRoutes } from './routes/search';
import { adminRoutes } from './routes/admin';
import { scheduledCleanup } from './jobs/cleanup';
import { errorHandler } from './middleware/error';

const app = new Hono<{ Bindings: Env }>();

// Global middleware
app.use('*', logger());
app.use('*', secureHeaders());
app.use('/api/*', async (c, next) => {
  const corsMiddleware = cors({
    origin: c.env.CORS_ORIGIN || '*',
    allowMethods: ['GET', 'POST', 'PUT', 'PATCH', 'DELETE', 'OPTIONS'],
    allowHeaders: ['Content-Type', 'Authorization'],
    exposeHeaders: ['X-Request-Id'],
    maxAge: 86400,
    credentials: true,
  });
  return corsMiddleware(c, next);
});

// Health check
app.get('/health', (c) => c.json({ status: 'ok', timestamp: new Date().toISOString() }));

// API routes
const api = app.basePath('/api/v1');
api.route('/auth', authRoutes);
api.route('/', organizationRoutes);
api.route('/', folderRoutes);
api.route('/', documentRoutes);
api.route('/', uploadRoutes);
api.route('/', searchRoutes);
api.route('/', adminRoutes);

// 404 handler
app.notFound((c) => {
  return c.json({ error: { code: 'NOT_FOUND', message: 'Route not found.' } }, 404);
});

// Error handler
app.onError(errorHandler);

export default {
  fetch: app.fetch,
  async scheduled(_event: ScheduledEvent, env: Env, ctx: ExecutionContext) {
    ctx.waitUntil(scheduledCleanup(env));
  },
};

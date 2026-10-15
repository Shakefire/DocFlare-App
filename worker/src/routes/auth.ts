import { Hono } from 'hono';
import type { Env } from '../types/env';
import { generateId } from '../lib/id';
import {
  hashPassword,
  verifyPassword,
  generateToken,
  hashToken,
  createSessionToken,
  verifySessionToken,
} from '../lib/auth';
import { Errors } from '../lib/errors';
import { validateEmail, validatePassword, normalizeEmail } from '../lib/validation';
import { sendEmail, makeVerificationEmail, makePasswordResetEmail } from '../lib/email';
import { checkRateLimit, RATE_LIMITS } from '../lib/ratelimit';

const authRoutes = new Hono<{ Bindings: Env }>();

// POST /api/v1/auth/register
authRoutes.post('/register', async (c) => {
  const clientIp = c.req.header('CF-Connecting-IP') || 'unknown';
  const { allowed } = checkRateLimit(`auth:register:${clientIp}`, RATE_LIMITS.auth);
  if (!allowed) throw Errors.tooManyRequests();

  const body = await c.req.json().catch(() => null);
  if (!body) throw Errors.badRequest('Invalid JSON body.');

  const { email, password } = body as { email?: string; password?: string };
  if (!email || !password) throw Errors.unprocessable('Email and password are required.');
  if (!validateEmail(email)) throw Errors.unprocessable('Invalid email address.');
  const pwCheck = validatePassword(password);
  if (!pwCheck.valid) throw Errors.unprocessable(pwCheck.message!);

  const emailNormalized = normalizeEmail(email);
  const existing = await c.env.DB
    .prepare('SELECT id FROM users WHERE email_normalized = ? LIMIT 1')
    .bind(emailNormalized)
    .first();
  if (existing) throw Errors.conflict('An account with that email already exists.');

  const userId = generateId();
  const passwordHash = await hashPassword(password);
  const now = new Date().toISOString();

  await c.env.DB
    .prepare(
      `INSERT INTO users (id, email, email_normalized, password_hash, created_at, updated_at)
       VALUES (?, ?, ?, ?, ?, ?)`
    )
    .bind(userId, email.trim(), emailNormalized, passwordHash, now, now)
    .run();

  const verifyToken = await generateToken();
  const verifyTokenHash = await hashToken(verifyToken);
  const verifyId = generateId();
  const verifyExpiry = new Date(Date.now() + 24 * 60 * 60 * 1000).toISOString();

  await c.env.DB
    .prepare(
      `INSERT INTO email_verifications (id, user_id, token_hash, expires_at, created_at)
       VALUES (?, ?, ?, ?, ?)`
    )
    .bind(verifyId, userId, verifyTokenHash, verifyExpiry, now)
    .run();

  await sendEmail(
    c.env.EMAIL_API_KEY,
    c.env.EMAIL_FROM,
    makeVerificationEmail(email, verifyToken, c.env.APP_NAME || 'Docflare')
  );

  return c.json(
    {
      data: {
        userId,
        email,
        message: 'Account created. Please verify your email address.',
        // Return verificationToken in test/dev environment only to facilitate automated tests
        ...(c.env.ENVIRONMENT === 'test' || c.env.ENVIRONMENT === 'development'
          ? { debugVerificationToken: verifyToken }
          : {}),
      },
    },
    201
  );
});

// POST /api/v1/auth/verify-email
authRoutes.post('/verify-email', async (c) => {
  const body = await c.req.json().catch(() => null);
  if (!body) throw Errors.badRequest('Invalid JSON body.');
  const { token } = body as { token?: string };
  if (!token) throw Errors.unprocessable('Verification token is required.');

  const tokenHash = await hashToken(token);
  const now = new Date().toISOString();
  const record = await c.env.DB
    .prepare(
      `SELECT id, user_id, expires_at, used_at
       FROM email_verifications
       WHERE token_hash = ? LIMIT 1`
    )
    .bind(tokenHash)
    .first<{ id: string; user_id: string; expires_at: string; used_at: string | null }>();

  if (!record) throw Errors.badRequest('Invalid or expired verification token.');
  if (record.used_at) throw Errors.conflict('Verification token has already been used.');
  if (record.expires_at < now) throw Errors.badRequest('Verification token has expired.');

  await c.env.DB.batch([
    c.env.DB.prepare('UPDATE users SET email_verified_at = ?, updated_at = ? WHERE id = ?').bind(now, now, record.user_id),
    c.env.DB.prepare('UPDATE email_verifications SET used_at = ? WHERE id = ?').bind(now, record.id),
  ]);

  return c.json({ data: { message: 'Email address verified successfully.' } });
});

// POST /api/v1/auth/resend-verification
authRoutes.post('/resend-verification', async (c) => {
  const clientIp = c.req.header('CF-Connecting-IP') || 'unknown';
  const { allowed } = checkRateLimit(`auth:resend:${clientIp}`, { windowMs: 60_000, maxRequests: 5 });
  if (!allowed) throw Errors.tooManyRequests();

  const body = await c.req.json().catch(() => null);
  if (!body) throw Errors.badRequest('Invalid JSON body.');
  const { email } = body as { email?: string };
  if (!email) throw Errors.unprocessable('Email is required.');

  const user = await c.env.DB
    .prepare('SELECT id, email, email_verified_at FROM users WHERE email_normalized = ? LIMIT 1')
    .bind(normalizeEmail(email))
    .first<{ id: string; email: string; email_verified_at: string | null }>();

  if (user && !user.email_verified_at) {
    const token = await generateToken();
    const tokenHash = await hashToken(token);
    const id = generateId();
    const expiry = new Date(Date.now() + 24 * 60 * 60 * 1000).toISOString();
    const now = new Date().toISOString();
    await c.env.DB
      .prepare('INSERT INTO email_verifications (id, user_id, token_hash, expires_at, created_at) VALUES (?, ?, ?, ?, ?)')
      .bind(id, user.id, tokenHash, expiry, now)
      .run();
    await sendEmail(c.env.EMAIL_API_KEY, c.env.EMAIL_FROM, makeVerificationEmail(user.email, token, c.env.APP_NAME || 'Docflare'));
  }

  return c.json({ data: { message: 'If that email address exists and is unverified, a verification link has been sent.' } });
});

// POST /api/v1/auth/login
authRoutes.post('/login', async (c) => {
  const clientIp = c.req.header('CF-Connecting-IP') || 'unknown';
  const { allowed } = checkRateLimit(`auth:login:${clientIp}`, RATE_LIMITS.auth);
  if (!allowed) throw Errors.tooManyRequests();

  const body = await c.req.json().catch(() => null);
  if (!body) throw Errors.badRequest('Invalid JSON body.');
  const { email, password } = body as { email?: string; password?: string };
  if (!email || !password) throw Errors.unprocessable('Email and password are required.');

  const user = await c.env.DB
    .prepare(
      `SELECT id, email, email_normalized, password_hash, email_verified_at, disabled_at
       FROM users WHERE email_normalized = ? LIMIT 1`
    )
    .bind(normalizeEmail(email))
    .first<{ id: string; email: string; email_normalized: string; password_hash: string; email_verified_at: string | null; disabled_at: string | null }>();

  if (!user) throw Errors.unauthorized('Invalid email or password.');
  if (user.disabled_at) throw Errors.forbidden('This user account has been disabled.');

  const valid = await verifyPassword(password, user.password_hash);
  if (!valid) throw Errors.unauthorized('Invalid email or password.');

  const token = await createSessionToken(
    { userId: user.id, email: user.email, emailVerified: !!user.email_verified_at },
    c.env.JWT_SECRET
  );

  return c.json({
    data: {
      token,
      user: {
        id: user.id,
        email: user.email,
        email_verified: !!user.email_verified_at,
      },
    },
  });
});

// POST /api/v1/auth/logout
authRoutes.post('/logout', async (c) => {
  const authHeader = c.req.header('Authorization');
  if (authHeader && authHeader.startsWith('Bearer ')) {
    const token = authHeader.slice(7).trim();
    const auth = await verifySessionToken(token, c.env.JWT_SECRET);
    if (auth) {
      const tokenHash = await hashToken(token);
      const now = new Date().toISOString();
      const expiry = new Date(Date.now() + 7 * 24 * 60 * 60 * 1000).toISOString();
      const id = generateId();
      await c.env.DB
        .prepare('INSERT OR IGNORE INTO revoked_tokens (id, token_hash, user_id, expires_at, created_at) VALUES (?, ?, ?, ?, ?)')
        .bind(id, tokenHash, auth.userId, expiry, now)
        .run();
    }
  }
  return c.json({ data: { message: 'Successfully logged out.' } });
});

// GET /api/v1/auth/me
authRoutes.get('/me', async (c) => {
  const authHeader = c.req.header('Authorization');
  if (!authHeader?.startsWith('Bearer ')) throw Errors.unauthorized();
  const token = authHeader.slice(7).trim();
  const auth = await verifySessionToken(token, c.env.JWT_SECRET);
  if (!auth) throw Errors.unauthorized('Session expired or invalid.');

  const user = await c.env.DB
    .prepare('SELECT id, email, email_verified_at, created_at FROM users WHERE id = ? AND disabled_at IS NULL LIMIT 1')
    .bind(auth.userId)
    .first<{ id: string; email: string; email_verified_at: string | null; created_at: string }>();

  if (!user) throw Errors.unauthorized();

  const memberships = await c.env.DB
    .prepare(
      `SELECT om.organization_id, om.role, om.status, o.name, o.slug, o.storage_quota_bytes, o.storage_used_bytes
       FROM organization_members om
       JOIN organizations o ON o.id = om.organization_id
       WHERE om.user_id = ? AND om.status = 'active'
       ORDER BY o.name ASC`
    )
    .bind(auth.userId)
    .all<{ organization_id: string; role: string; status: string; name: string; slug: string; storage_quota_bytes: number; storage_used_bytes: number }>();

  return c.json({
    data: {
      id: user.id,
      email: user.email,
      email_verified: !!user.email_verified_at,
      created_at: user.created_at,
      organizations: memberships.results,
    },
  });
});

// POST /api/v1/auth/forgot-password
authRoutes.post('/forgot-password', async (c) => {
  const clientIp = c.req.header('CF-Connecting-IP') || 'unknown';
  const { allowed } = checkRateLimit(`auth:forgot:${clientIp}`, { windowMs: 60_000, maxRequests: 5 });
  if (!allowed) throw Errors.tooManyRequests();

  const body = await c.req.json().catch(() => null);
  if (!body) throw Errors.badRequest('Invalid JSON body.');
  const { email } = body as { email?: string };
  if (!email) throw Errors.unprocessable('Email is required.');

  const user = await c.env.DB
    .prepare('SELECT id, email FROM users WHERE email_normalized = ? AND disabled_at IS NULL LIMIT 1')
    .bind(normalizeEmail(email))
    .first<{ id: string; email: string }>();

  if (user) {
    const token = await generateToken();
    const tokenHash = await hashToken(token);
    const now = new Date().toISOString();
    const expiry = new Date(Date.now() + 60 * 60 * 1000).toISOString();
    const id = generateId();
    await c.env.DB
      .prepare('INSERT INTO password_resets (id, user_id, token_hash, expires_at, created_at) VALUES (?, ?, ?, ?, ?)')
      .bind(id, user.id, tokenHash, expiry, now)
      .run();
    await sendEmail(c.env.EMAIL_API_KEY, c.env.EMAIL_FROM, makePasswordResetEmail(user.email, token, c.env.APP_NAME || 'Docflare'));
  }

  return c.json({ data: { message: 'If that email address exists, a password reset link has been sent.' } });
});

// POST /api/v1/auth/reset-password
authRoutes.post('/reset-password', async (c) => {
  const clientIp = c.req.header('CF-Connecting-IP') || 'unknown';
  const { allowed } = checkRateLimit(`auth:reset:${clientIp}`, RATE_LIMITS.auth);
  if (!allowed) throw Errors.tooManyRequests();

  const body = await c.req.json().catch(() => null);
  if (!body) throw Errors.badRequest('Invalid JSON body.');
  const { token, new_password } = body as { token?: string; new_password?: string };
  if (!token || !new_password) throw Errors.unprocessable('Reset token and new password are required.');

  const pwCheck = validatePassword(new_password);
  if (!pwCheck.valid) throw Errors.unprocessable(pwCheck.message!);

  const tokenHash = await hashToken(token);
  const now = new Date().toISOString();
  const record = await c.env.DB
    .prepare('SELECT id, user_id, expires_at, used_at FROM password_resets WHERE token_hash = ? LIMIT 1')
    .bind(tokenHash)
    .first<{ id: string; user_id: string; expires_at: string; used_at: string | null }>();

  if (!record || record.used_at || record.expires_at < now) {
    throw Errors.badRequest('Invalid or expired password reset token.');
  }

  const passwordHash = await hashPassword(new_password);
  await c.env.DB.batch([
    c.env.DB.prepare('UPDATE users SET password_hash = ?, updated_at = ? WHERE id = ?').bind(passwordHash, now, record.user_id),
    c.env.DB.prepare('UPDATE password_resets SET used_at = ? WHERE id = ?').bind(now, record.id),
  ]);

  return c.json({ data: { message: 'Password has been updated. You may now log in with your new password.' } });
});

export { authRoutes };

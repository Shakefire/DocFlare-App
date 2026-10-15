import { createMiddleware } from 'hono/factory';
import type { Env } from '../types/env';
import type { AuthContext, MemberContext } from '../types/api';
import { verifySessionToken, hashToken } from '../lib/auth';
import { Errors } from '../lib/errors';

export type AuthVariables = {
  auth: AuthContext;
  member?: MemberContext;
};

export const requireAuth = createMiddleware<{ Bindings: Env; Variables: AuthVariables }>(async (c, next) => {
  const authHeader = c.req.header('Authorization');
  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    throw Errors.unauthorized('Authentication token missing or invalid format.');
  }

  const token = authHeader.slice(7).trim();
  const auth = await verifySessionToken(token, c.env.JWT_SECRET);
  if (!auth) {
    throw Errors.unauthorized('Session expired or invalid.');
  }

  const tokenHash = await hashToken(token);
  const now = new Date().toISOString();
  const revoked = await c.env.DB
    .prepare('SELECT id FROM revoked_tokens WHERE token_hash = ? AND expires_at > ? LIMIT 1')
    .bind(tokenHash, now)
    .first();

  if (revoked) {
    throw Errors.unauthorized('Session has been revoked.');
  }

  c.set('auth', auth);
  await next();
});

export const requireVerifiedEmail = createMiddleware<{ Bindings: Env; Variables: AuthVariables }>(async (c, next) => {
  const auth = c.get('auth');
  if (!auth) {
    throw Errors.unauthorized();
  }
  if (!auth.emailVerified) {
    throw Errors.forbidden('Your email address must be verified before accessing this resource.');
  }
  await next();
});

export async function resolveOrgMembership(
  db: D1Database,
  userId: string,
  organizationId: string
): Promise<MemberContext | null> {
  const row = await db
    .prepare(
      `SELECT om.id AS member_id, om.role, om.status, u.email, u.email_verified_at
       FROM organization_members om
       JOIN users u ON u.id = om.user_id
       WHERE om.organization_id = ? AND om.user_id = ? AND om.status = 'active'
       LIMIT 1`
    )
    .bind(organizationId, userId)
    .first<{ member_id: string; role: string; status: string; email: string; email_verified_at: string | null }>();

  if (!row) return null;

  return {
    userId,
    email: row.email,
    emailVerified: !!row.email_verified_at,
    memberId: row.member_id,
    organizationId,
    role: row.role as import('../types/models').Role,
  };
}

import { Hono } from 'hono';
import type { Env } from '../types/env';
import { requireAuth, requireVerifiedEmail, resolveOrgMembership, type AuthVariables } from '../middleware/auth';
import { requireCapability } from '../lib/permissions';
import { generateId } from '../lib/id';
import { Errors } from '../lib/errors';
import { sanitizeSlug, normalizeEmail } from '../lib/validation';
import { generateToken, hashToken } from '../lib/auth';
import { sendEmail, makeInvitationEmail } from '../lib/email';
import { writeAuditLog } from '../lib/audit';

const organizationRoutes = new Hono<{ Bindings: Env; Variables: AuthVariables }>();

// POST /api/v1/organizations
organizationRoutes.post('/organizations', requireAuth, requireVerifiedEmail, async (c) => {
  const auth = c.get('auth');
  const body = await c.req.json().catch(() => null);
  if (!body) throw Errors.badRequest('Invalid JSON body.');
  const { name } = body as { name?: string };
  if (!name || name.trim().length < 2) throw Errors.unprocessable('Organization name must be at least 2 characters.');
  if (name.trim().length > 100) throw Errors.unprocessable('Organization name must be at most 100 characters.');

  let slug = sanitizeSlug(name.trim());
  if (!slug) slug = 'org-' + generateId().slice(0, 8);

  const existing = await c.env.DB.prepare('SELECT id FROM organizations WHERE slug = ? LIMIT 1').bind(slug).first();
  if (existing) {
    slug = `${slug}-${generateId().slice(0, 6)}`;
  }

  const orgId = generateId();
  const memberId = generateId();
  const now = new Date().toISOString();
  const quota = parseInt(c.env.DEFAULT_ORG_QUOTA_BYTES || '10737418240', 10);

  await c.env.DB.batch([
    c.env.DB.prepare(
      `INSERT INTO organizations (id, name, slug, created_by, created_at, updated_at, storage_quota_bytes, storage_used_bytes, status)
       VALUES (?, ?, ?, ?, ?, ?, ?, 0, 'active')`
    ).bind(orgId, name.trim(), slug, auth.userId, now, now, quota),
    c.env.DB.prepare(
      `INSERT INTO organization_members (id, organization_id, user_id, role, status, created_at, updated_at)
       VALUES (?, ?, ?, 'admin', 'active', ?, ?)`
    ).bind(memberId, orgId, auth.userId, now, now),
  ]);

  await writeAuditLog(c.env.DB, {
    organizationId: orgId,
    actorUserId: auth.userId,
    action: 'organization.created',
    resourceType: 'organization',
    resourceId: orgId,
    metadata: { name: name.trim(), slug },
  });

  return c.json({ data: { id: orgId, name: name.trim(), slug, role: 'admin' } }, 201);
});

// GET /api/v1/organizations
organizationRoutes.get('/organizations', requireAuth, async (c) => {
  const auth = c.get('auth');
  const results = await c.env.DB
    .prepare(
      `SELECT o.id, o.name, o.slug, o.status, o.storage_quota_bytes, o.storage_used_bytes, om.role
       FROM organizations o
       JOIN organization_members om ON om.organization_id = o.id
       WHERE om.user_id = ? AND om.status = 'active'
       ORDER BY o.name ASC`
    )
    .bind(auth.userId)
    .all();

  return c.json({ data: results.results });
});

// GET /api/v1/organizations/:organizationId
organizationRoutes.get('/organizations/:organizationId', requireAuth, async (c) => {
  const auth = c.get('auth');
  const { organizationId } = c.req.param();
  const member = await resolveOrgMembership(c.env.DB, auth.userId, organizationId);
  if (!member) throw Errors.notFound('Organization');

  const org = await c.env.DB
    .prepare('SELECT id, name, slug, status, storage_quota_bytes, storage_used_bytes, created_at FROM organizations WHERE id = ? LIMIT 1')
    .bind(organizationId)
    .first();

  if (!org) throw Errors.notFound('Organization');

  return c.json({ data: { ...org, your_role: member.role } });
});

// GET /api/v1/organizations/:organizationId/members
organizationRoutes.get('/organizations/:organizationId/members', requireAuth, async (c) => {
  const auth = c.get('auth');
  const { organizationId } = c.req.param();
  const member = await resolveOrgMembership(c.env.DB, auth.userId, organizationId);
  if (!member) throw Errors.notFound('Organization');

  const members = await c.env.DB
    .prepare(
      `SELECT om.id, om.user_id, om.role, om.status, om.created_at, u.email
       FROM organization_members om
       JOIN users u ON u.id = om.user_id
       WHERE om.organization_id = ?
       ORDER BY om.created_at ASC`
    )
    .bind(organizationId)
    .all();

  return c.json({ data: members.results });
});

// POST /api/v1/organizations/:organizationId/invitations
organizationRoutes.post('/organizations/:organizationId/invitations', requireAuth, requireVerifiedEmail, async (c) => {
  const auth = c.get('auth');
  const { organizationId } = c.req.param();
  const member = await resolveOrgMembership(c.env.DB, auth.userId, organizationId);
  if (!member) throw Errors.notFound('Organization');
  requireCapability(member.role, 'active', 'member.manage');

  const body = await c.req.json().catch(() => null);
  if (!body) throw Errors.badRequest('Invalid JSON body.');
  const { email, role } = body as { email?: string; role?: string };
  if (!email || !role) throw Errors.unprocessable('Email and role are required.');
  if (!['admin', 'manager', 'viewer'].includes(role)) {
    throw Errors.unprocessable('Role must be admin, manager, or viewer.');
  }

  const emailNormalized = normalizeEmail(email);

  // Check if target user is already an active member of this organization
  const existingMember = await c.env.DB
    .prepare(
      `SELECT om.id FROM users u
       JOIN organization_members om ON om.user_id = u.id
       WHERE u.email_normalized = ? AND om.organization_id = ? AND om.status = 'active'
       LIMIT 1`
    )
    .bind(emailNormalized, organizationId)
    .first();

  if (existingMember) {
    throw Errors.conflict('That user is already an active member of this organization.');
  }

  const now = new Date().toISOString();
  await c.env.DB
    .prepare(
      `UPDATE organization_invitations
       SET revoked_at = ?
       WHERE organization_id = ? AND email_normalized = ? AND accepted_at IS NULL AND revoked_at IS NULL`
    )
    .bind(now, organizationId, emailNormalized)
    .run();

  const token = await generateToken();
  const tokenHash = await hashToken(token);
  const invId = generateId();
  const ttl = parseInt(c.env.INVITATION_TTL_SECONDS || '604800', 10);
  const expiry = new Date(Date.now() + ttl * 1000).toISOString();

  await c.env.DB
    .prepare(
      `INSERT INTO organization_invitations (id, organization_id, email_normalized, role, token_hash, invited_by, expires_at, created_at)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?)`
    )
    .bind(invId, organizationId, emailNormalized, role, tokenHash, auth.userId, expiry, now)
    .run();

  const org = await c.env.DB.prepare('SELECT name FROM organizations WHERE id = ? LIMIT 1').bind(organizationId).first<{ name: string }>();

  await sendEmail(
    c.env.EMAIL_API_KEY,
    c.env.EMAIL_FROM,
    makeInvitationEmail(email, token, org?.name || 'the organization', role, c.env.APP_NAME || 'Docflare')
  );

  await writeAuditLog(c.env.DB, {
    organizationId,
    actorUserId: auth.userId,
    action: 'member.invited',
    resourceType: 'invitation',
    resourceId: invId,
    metadata: { email_normalized: emailNormalized, role },
  });

  return c.json(
    {
      data: {
        id: invId,
        email,
        role,
        expires_at: expiry,
        token,
        invitation_url: `docflare://accept-invitation?token=${token}`,
        message: 'Invitation created. In development/testing, copy and share the invitation token.',
      },
    },
    201
  );
});

// GET /api/v1/organizations/:organizationId/invitations
// List pending invitations for the organization
organizationRoutes.get('/organizations/:organizationId/invitations', requireAuth, async (c) => {
  const auth = c.get('auth');
  const { organizationId } = c.req.param();
  const member = await resolveOrgMembership(c.env.DB, auth.userId, organizationId);
  if (!member) throw Errors.notFound('Organization');
  requireCapability(member.role, 'active', 'member.manage');

  const pending = await c.env.DB
    .prepare(
      `SELECT id, organization_id, email_normalized, role, expires_at, created_at
       FROM organization_invitations
       WHERE organization_id = ? AND accepted_at IS NULL AND revoked_at IS NULL
       ORDER BY created_at DESC`
    )
    .bind(organizationId)
    .all();

  return c.json({ data: pending.results });
});

// POST /api/v1/organizations/:organizationId/members
// Directly add an existing registered user to the organization
organizationRoutes.post('/organizations/:organizationId/members', requireAuth, requireVerifiedEmail, async (c) => {
  const auth = c.get('auth');
  const { organizationId } = c.req.param();
  const actor = await resolveOrgMembership(c.env.DB, auth.userId, organizationId);
  if (!actor) throw Errors.notFound('Organization');
  requireCapability(actor.role, 'active', 'member.manage');

  const body = await c.req.json().catch(() => null);
  if (!body) throw Errors.badRequest('Invalid JSON body.');
  const { email, role } = body as { email?: string; role?: string };
  if (!email || !role) throw Errors.unprocessable('Email and role are required.');
  if (!['admin', 'manager', 'viewer'].includes(role)) {
    throw Errors.unprocessable('Role must be admin, manager, or viewer.');
  }

  const emailNormalized = normalizeEmail(email);
  const targetUser = await c.env.DB
    .prepare('SELECT id, email FROM users WHERE email_normalized = ? LIMIT 1')
    .bind(emailNormalized)
    .first<{ id: string; email: string }>();

  if (!targetUser) {
    throw Errors.notFound(`No registered user found with email "${email}". Please ask them to create an account first, or use Send Invitation.`);
  }

  const existingMember = await c.env.DB
    .prepare('SELECT id FROM organization_members WHERE organization_id = ? AND user_id = ? LIMIT 1')
    .bind(organizationId, targetUser.id)
    .first();

  if (existingMember) {
    throw Errors.conflict('That user is already a member of this organization.');
  }

  const memberId = generateId();
  const now = new Date().toISOString();
  await c.env.DB
    .prepare('INSERT INTO organization_members (id, organization_id, user_id, role, status, created_at, updated_at) VALUES (?, ?, ?, ?, ?, ?, ?)')
    .bind(memberId, organizationId, targetUser.id, role, 'active', now, now)
    .run();

  await writeAuditLog(c.env.DB, {
    organizationId,
    actorUserId: auth.userId,
    action: 'member.role_changed',
    resourceType: 'member',
    resourceId: memberId,
    metadata: { added_user_email: emailNormalized, role },
  });

  return c.json({ data: { id: memberId, user_id: targetUser.id, email: targetUser.email, role, status: 'active' } }, 201);
});

// POST /api/v1/invitations/accept
organizationRoutes.post('/invitations/accept', requireAuth, requireVerifiedEmail, async (c) => {
  const auth = c.get('auth');
  const body = await c.req.json().catch(() => null);
  if (!body) throw Errors.badRequest('Invalid JSON body.');
  const { token } = body as { token?: string };
  if (!token) throw Errors.unprocessable('Invitation token is required.');

  const now = new Date().toISOString();
  const tokenHash = await hashToken(token);
  const inv = await c.env.DB
    .prepare(
      `SELECT id, organization_id, email_normalized, role, expires_at, accepted_at, revoked_at
       FROM organization_invitations WHERE token_hash = ? LIMIT 1`
    )
    .bind(tokenHash)
    .first<{ id: string; organization_id: string; email_normalized: string; role: string; expires_at: string; accepted_at: string | null; revoked_at: string | null }>();

  if (!inv) throw Errors.badRequest('Invalid or expired invitation token.');
  if (inv.accepted_at) throw Errors.conflict('This invitation has already been accepted.');
  if (inv.revoked_at) throw Errors.badRequest('This invitation has been revoked.');
  if (inv.expires_at < now) throw Errors.badRequest('This invitation has expired.');

  const user = await c.env.DB
    .prepare('SELECT email_normalized FROM users WHERE id = ? LIMIT 1')
    .bind(auth.userId)
    .first<{ email_normalized: string }>();

  if (!user || user.email_normalized !== inv.email_normalized) {
    throw Errors.forbidden('This invitation was sent to a different email address.');
  }

  const existingMember = await c.env.DB
    .prepare('SELECT id, status FROM organization_members WHERE organization_id = ? AND user_id = ? LIMIT 1')
    .bind(inv.organization_id, auth.userId)
    .first<{ id: string; status: string }>();

  const memberId = existingMember ? existingMember.id : generateId();

  if (existingMember) {
    await c.env.DB.batch([
      c.env.DB.prepare('UPDATE organization_members SET role = ?, status = \'active\', updated_at = ? WHERE id = ?')
        .bind(inv.role, now, memberId),
      c.env.DB.prepare('UPDATE organization_invitations SET accepted_at = ? WHERE id = ?')
        .bind(now, inv.id),
    ]);
  } else {
    await c.env.DB.batch([
      c.env.DB.prepare(
        `INSERT INTO organization_members (id, organization_id, user_id, role, status, created_at, updated_at)
         VALUES (?, ?, ?, ?, 'active', ?, ?)`
      ).bind(memberId, inv.organization_id, auth.userId, inv.role, now, now),
      c.env.DB.prepare('UPDATE organization_invitations SET accepted_at = ? WHERE id = ?')
        .bind(now, inv.id),
    ]);
  }

  await writeAuditLog(c.env.DB, {
    organizationId: inv.organization_id,
    actorUserId: auth.userId,
    action: 'member.invitation_accepted',
    resourceType: 'invitation',
    resourceId: inv.id,
    metadata: { role: inv.role },
  });

  return c.json({ data: { organization_id: inv.organization_id, role: inv.role } });
});

// PATCH /api/v1/organizations/:organizationId/members/:memberId
organizationRoutes.patch('/organizations/:organizationId/members/:memberId', requireAuth, async (c) => {
  const auth = c.get('auth');
  const { organizationId, memberId } = c.req.param();
  const actor = await resolveOrgMembership(c.env.DB, auth.userId, organizationId);
  if (!actor) throw Errors.notFound('Organization');
  requireCapability(actor.role, 'active', 'member.manage');

  const body = await c.req.json().catch(() => null);
  if (!body) throw Errors.badRequest('Invalid JSON body.');
  const { role } = body as { role?: string };
  if (!role || !['admin', 'manager', 'viewer'].includes(role)) {
    throw Errors.unprocessable('Role must be admin, manager, or viewer.');
  }

  const target = await c.env.DB
    .prepare('SELECT id, user_id, role FROM organization_members WHERE id = ? AND organization_id = ? LIMIT 1')
    .bind(memberId, organizationId)
    .first<{ id: string; user_id: string; role: string }>();

  if (!target) throw Errors.notFound('Member');

  if (target.role === 'admin' && role !== 'admin') {
    const adminCount = await c.env.DB
      .prepare(`SELECT COUNT(*) as cnt FROM organization_members WHERE organization_id = ? AND role = 'admin' AND status = 'active'`)
      .bind(organizationId)
      .first<{ cnt: number }>();
    if ((adminCount?.cnt ?? 0) <= 1) {
      throw Errors.conflict('Cannot demote the last administrator of the organization.');
    }
  }

  const now = new Date().toISOString();
  await c.env.DB
    .prepare('UPDATE organization_members SET role = ?, updated_at = ? WHERE id = ?')
    .bind(role, now, memberId)
    .run();

  await writeAuditLog(c.env.DB, {
    organizationId,
    actorUserId: auth.userId,
    action: 'member.role_changed',
    resourceType: 'member',
    resourceId: memberId,
    metadata: { old_role: target.role, new_role: role },
  });

  return c.json({ data: { message: 'Member role successfully updated.' } });
});

// DELETE /api/v1/organizations/:organizationId/members/:memberId
organizationRoutes.delete('/organizations/:organizationId/members/:memberId', requireAuth, async (c) => {
  const auth = c.get('auth');
  const { organizationId, memberId } = c.req.param();
  const actor = await resolveOrgMembership(c.env.DB, auth.userId, organizationId);
  if (!actor) throw Errors.notFound('Organization');

  const target = await c.env.DB
    .prepare('SELECT id, user_id, role FROM organization_members WHERE id = ? AND organization_id = ? LIMIT 1')
    .bind(memberId, organizationId)
    .first<{ id: string; user_id: string; role: string }>();

  if (!target) throw Errors.notFound('Member');

  if (target.user_id !== auth.userId) {
    requireCapability(actor.role, 'active', 'member.manage');
  }

  if (target.role === 'admin') {
    const adminCount = await c.env.DB
      .prepare(`SELECT COUNT(*) as cnt FROM organization_members WHERE organization_id = ? AND role = 'admin' AND status = 'active'`)
      .bind(organizationId)
      .first<{ cnt: number }>();
    if ((adminCount?.cnt ?? 0) <= 1) {
      throw Errors.conflict('Cannot remove the last administrator of the organization.');
    }
  }

  const now = new Date().toISOString();
  await c.env.DB
    .prepare('UPDATE organization_members SET status = \'suspended\', updated_at = ? WHERE id = ?')
    .bind(now, memberId)
    .run();

  await writeAuditLog(c.env.DB, {
    organizationId,
    actorUserId: auth.userId,
    action: 'member.removed',
    resourceType: 'member',
    resourceId: memberId,
    metadata: { removed_user_id: target.user_id },
  });

  return c.json({ data: { message: 'Member removed successfully.' } });
});

export { organizationRoutes };

import type { Role, MemberStatus } from '../types/models';
import type { Capability } from '../types/api';
import { Errors } from './errors';

export const ROLE_CAPABILITIES: Record<Role, Capability[]> = {
  admin: [
    'document.read',
    'document.upload',
    'document.update',
    'document.delete',
    'document.restore',
    'document.download',
    'document.share',
    'folder.create',
    'folder.update',
    'folder.delete',
    'member.manage',
    'organization.manage',
    'audit.read',
  ],
  manager: [
    'document.read',
    'document.upload',
    'document.update',
    'document.delete',
    'document.restore',
    'document.download',
    'document.share',
    'folder.create',
    'folder.update',
    'folder.delete',
  ],
  viewer: [
    'document.read',
    'document.download',
  ],
};

export function hasCapability(role: Role, status: MemberStatus, capability: Capability): boolean {
  if (status !== 'active') return false;
  return ROLE_CAPABILITIES[role]?.includes(capability) ?? false;
}

export function requireCapability(
  role: Role,
  status: MemberStatus,
  capability: Capability
): void {
  if (!hasCapability(role, status, capability)) {
    throw Errors.forbidden(`You do not have permission to perform this action (${capability}).`);
  }
}

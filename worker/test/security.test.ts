import { describe, it, expect } from 'vitest';
import { hasCapability, requireCapability } from '../src/lib/permissions';

describe('Security & Access Control Invariants', () => {
  it('enforces deny-by-default for unknown roles or actions', () => {
    // @ts-expect-error Testing invalid role
    expect(hasCapability('guest', 'active', 'document.read')).toBe(false);
    // @ts-expect-error Testing invalid capability
    expect(hasCapability('viewer', 'active', 'system.admin')).toBe(false);
  });

  it('prohibits viewer from writing or modifying any resources', () => {
    const forbiddenCapabilities = [
      'document.upload',
      'document.update',
      'document.delete',
      'document.restore',
      'document.share',
      'folder.create',
      'folder.update',
      'folder.delete',
      'member.manage',
      'organization.manage',
      'audit.read',
    ] as const;

    for (const cap of forbiddenCapabilities) {
      expect(hasCapability('viewer', 'active', cap)).toBe(false);
      expect(() => requireCapability('viewer', 'active', cap)).toThrowError();
    }
  });

  it('prohibits manager from administrative member or audit actions', () => {
    expect(hasCapability('manager', 'active', 'member.manage')).toBe(false);
    expect(hasCapability('manager', 'active', 'organization.manage')).toBe(false);
    expect(hasCapability('manager', 'active', 'audit.read')).toBe(false);

    expect(() => requireCapability('manager', 'active', 'member.manage')).toThrowError();
    expect(() => requireCapability('manager', 'active', 'organization.manage')).toThrowError();
    expect(() => requireCapability('manager', 'active', 'audit.read')).toThrowError();
  });
});

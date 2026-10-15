import { describe, it, expect } from 'vitest';
import { hasCapability, requireCapability } from '../src/lib/permissions';

describe('Role and Permission System', () => {
  it('admin has all permissions', () => {
    expect(hasCapability('admin', 'active', 'document.read')).toBe(true);
    expect(hasCapability('admin', 'active', 'document.upload')).toBe(true);
    expect(hasCapability('admin', 'active', 'document.update')).toBe(true);
    expect(hasCapability('admin', 'active', 'document.delete')).toBe(true);
    expect(hasCapability('admin', 'active', 'document.restore')).toBe(true);
    expect(hasCapability('admin', 'active', 'document.download')).toBe(true);
    expect(hasCapability('admin', 'active', 'folder.create')).toBe(true);
    expect(hasCapability('admin', 'active', 'folder.update')).toBe(true);
    expect(hasCapability('admin', 'active', 'folder.delete')).toBe(true);
    expect(hasCapability('admin', 'active', 'member.manage')).toBe(true);
    expect(hasCapability('admin', 'active', 'organization.manage')).toBe(true);
    expect(hasCapability('admin', 'active', 'audit.read')).toBe(true);
  });

  it('manager has document and folder CRUD but cannot manage members, org, or view audit logs', () => {
    expect(hasCapability('manager', 'active', 'document.read')).toBe(true);
    expect(hasCapability('manager', 'active', 'document.upload')).toBe(true);
    expect(hasCapability('manager', 'active', 'document.update')).toBe(true);
    expect(hasCapability('manager', 'active', 'document.delete')).toBe(true);
    expect(hasCapability('manager', 'active', 'document.restore')).toBe(true);
    expect(hasCapability('manager', 'active', 'document.download')).toBe(true);
    expect(hasCapability('manager', 'active', 'folder.create')).toBe(true);

    // Forbidden for manager
    expect(hasCapability('manager', 'active', 'member.manage')).toBe(false);
    expect(hasCapability('manager', 'active', 'organization.manage')).toBe(false);
    expect(hasCapability('manager', 'active', 'audit.read')).toBe(false);
  });

  it('viewer can only read and download documents', () => {
    expect(hasCapability('viewer', 'active', 'document.read')).toBe(true);
    expect(hasCapability('viewer', 'active', 'document.download')).toBe(true);

    // Forbidden for viewer
    expect(hasCapability('viewer', 'active', 'document.upload')).toBe(false);
    expect(hasCapability('viewer', 'active', 'document.update')).toBe(false);
    expect(hasCapability('viewer', 'active', 'document.delete')).toBe(false);
    expect(hasCapability('viewer', 'active', 'document.restore')).toBe(false);
    expect(hasCapability('viewer', 'active', 'folder.create')).toBe(false);
    expect(hasCapability('viewer', 'active', 'member.manage')).toBe(false);
    expect(hasCapability('viewer', 'active', 'organization.manage')).toBe(false);
  });

  it('suspended member has no capabilities regardless of role', () => {
    expect(hasCapability('admin', 'suspended', 'document.read')).toBe(false);
    expect(hasCapability('manager', 'suspended', 'document.read')).toBe(false);
    expect(hasCapability('viewer', 'suspended', 'document.read')).toBe(false);
  });

  it('requireCapability throws 403 on forbidden action', () => {
    expect(() => requireCapability('viewer', 'active', 'document.upload')).toThrowError();
    expect(() => requireCapability('manager', 'active', 'member.manage')).toThrowError();
    expect(() => requireCapability('admin', 'suspended', 'document.read')).toThrowError();
  });
});

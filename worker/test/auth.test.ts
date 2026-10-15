import { describe, it, expect } from 'vitest';
import {
  hashPassword,
  verifyPassword,
  generateToken,
  hashToken,
  createSessionToken,
  verifySessionToken,
} from '../src/lib/auth';

describe('Authentication and Crypto Utilities', () => {
  it('hashes and verifies passwords securely using PBKDF2', async () => {
    const password = 'CorrectHorseBatteryStaple123!';
    const hash = await hashPassword(password);

    expect(hash).toContain('pbkdf2_sha256:310000:');
    const isValid = await verifyPassword(password, hash);
    expect(isValid).toBe(true);

    const isInvalid = await verifyPassword('WrongPassword', hash);
    expect(isInvalid).toBe(false);
  });

  it('generates secure random tokens and consistent SHA-256 hashes', async () => {
    const token = await generateToken();
    expect(token).toHaveLength(64); // 32 bytes hex = 64 chars

    const hash1 = await hashToken(token);
    const hash2 = await hashToken(token);
    expect(hash1).toBe(hash2);
    expect(hash1).not.toBe(token);
  });

  it('creates and verifies valid JWT session tokens', async () => {
    const secret = 'super-secret-key-that-is-at-least-32-bytes-long';
    const payload = {
      userId: 'user_123',
      email: 'test@example.com',
      emailVerified: true,
    };

    const token = await createSessionToken(payload, secret);
    expect(token.split('.')).toHaveLength(3);

    const decoded = await verifySessionToken(token, secret);
    expect(decoded).not.toBeNull();
    expect(decoded?.userId).toBe(payload.userId);
    expect(decoded?.email).toBe(payload.email);
    expect(decoded?.emailVerified).toBe(true);
  });

  it('rejects tampered or forged JWT session tokens', async () => {
    const secret = 'super-secret-key-that-is-at-least-32-bytes-long';
    const wrongSecret = 'different-secret-key-that-is-at-least-32-chars';
    const payload = {
      userId: 'user_123',
      email: 'test@example.com',
      emailVerified: true,
    };

    const token = await createSessionToken(payload, secret);

    // Wrong secret rejection
    const wrongSecretDecoded = await verifySessionToken(token, wrongSecret);
    expect(wrongSecretDecoded).toBeNull();

    // Tampered payload rejection
    const parts = token.split('.');
    const tamperedToken = `${parts[0]}.eyJob21lIjoidHJ1ZSJ9.${parts[2]}`;
    const tamperedDecoded = await verifySessionToken(tamperedToken, secret);
    expect(tamperedDecoded).toBeNull();
  });
});

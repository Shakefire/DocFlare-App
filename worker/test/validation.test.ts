import { describe, it, expect } from 'vitest';
import {
  validateEmail,
  validatePassword,
  validateMimeType,
  isPreviewable,
  sanitizeSlug,
  getExtension,
} from '../src/lib/validation';

describe('Validation and Allowlisting', () => {
  it('validates email addresses correctly', () => {
    expect(validateEmail('test@example.com')).toBe(true);
    expect(validateEmail('user.name+tag@sub.domain.org')).toBe(true);
    expect(validateEmail('invalid-email')).toBe(false);
    expect(validateEmail('@domain.com')).toBe(false);
    expect(validateEmail('test@')).toBe(false);
  });

  it('validates password requirements', () => {
    expect(validatePassword('short').valid).toBe(false);
    expect(validatePassword('1234567').valid).toBe(false);
    expect(validatePassword('securePassword123').valid).toBe(true);
  });

  it('validates allowed MIME types', () => {
    expect(validateMimeType('application/pdf')).toBe(true);
    expect(validateMimeType('image/png')).toBe(true);
    expect(validateMimeType('image/jpeg')).toBe(true);
    expect(validateMimeType('video/mp4')).toBe(true);
    expect(validateMimeType('text/plain')).toBe(true);

    // Disallowed executable or dangerous types
    expect(validateMimeType('application/x-msdownload')).toBe(false);
    expect(validateMimeType('application/javascript')).toBe(false);
    expect(validateMimeType('text/html')).toBe(false);
    expect(validateMimeType('application/x-sh')).toBe(false);
  });

  it('identifies previewable vs non-previewable formats', () => {
    expect(isPreviewable('image/jpeg')).toBe(true);
    expect(isPreviewable('image/png')).toBe(true);
    expect(isPreviewable('application/pdf')).toBe(true);
    expect(isPreviewable('video/mp4')).toBe(true);
    expect(isPreviewable('text/plain')).toBe(true);

    // Office documents are downloadable, but not directly previewable inline
    expect(isPreviewable('application/vnd.openxmlformats-officedocument.wordprocessingml.document')).toBe(false);
  });

  it('sanitizes slugs cleanly', () => {
    expect(sanitizeSlug('Acme Corp Inc.')).toBe('acme-corp-inc');
    expect(sanitizeSlug('Special & Characters % Here')).toBe('special-characters-here');
    expect(sanitizeSlug('   leading-trailing   ')).toBe('leading-trailing');
  });

  it('extracts extensions reliably', () => {
    expect(getExtension('report.pdf')).toBe('pdf');
    expect(getExtension('archive.tar.gz')).toBe('gz');
    expect(getExtension('noextension')).toBe('');
    expect(getExtension('IMAGE.PNG')).toBe('png');
  });
});

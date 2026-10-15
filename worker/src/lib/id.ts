import { createId } from '@paralleldrive/cuid2';

export function generateId(): string {
  return createId();
}

export function generateObjectKey(orgId: string, fileExt: string): string {
  const id = createId();
  const ts = Date.now();
  const cleanExt = fileExt ? `.${fileExt.replace(/^\./, '').toLowerCase()}` : '';
  return `orgs/${orgId}/${ts}-${id}${cleanExt}`;
}

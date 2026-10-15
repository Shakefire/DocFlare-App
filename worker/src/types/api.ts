export interface ApiError {
  error: {
    code: string;
    message: string;
    details?: Record<string, unknown>;
  };
}

export interface ApiSuccess<T> {
  data: T;
  meta?: {
    total?: number;
    page?: number;
    per_page?: number;
    has_more?: boolean;
  };
}

export type Capability =
  | 'document.read'
  | 'document.upload'
  | 'document.update'
  | 'document.delete'
  | 'document.restore'
  | 'document.download'
  | 'document.share'
  | 'folder.create'
  | 'folder.update'
  | 'folder.delete'
  | 'member.manage'
  | 'organization.manage'
  | 'audit.read';

export interface AuthContext {
  userId: string;
  email: string;
  emailVerified: boolean;
}

export interface MemberContext extends AuthContext {
  memberId: string;
  organizationId: string;
  role: import('./models').Role;
}

# Role-Based Access Control (RBAC) Matrix

Docflare enforces strict backend authorization on every API endpoint and R2 operation. Hiding UI components on mobile does not substitute for server authorization.

## Roles

1. **Administrator (`admin`)**: Full administrative authority over organization settings, members, role assignments, document management, trash recovery, permanent deletion, storage usage, and audit inspection.
2. **Manager / Editor (`manager`)**: Can upload documents, create/rename/move folders, soft-delete and restore permitted documents, and download/preview files. Cannot manage members, demote administrators, change organization quota, or access audit logs.
3. **Viewer (`viewer`)**: Read-only access to authorized documents and folders. Can browse, search, preview, and download documents. Cannot upload, edit, move, delete, restore, or invite members.

---

## Role-Permission Capability Matrix

| Capability | Description | Administrator | Manager | Viewer |
|---|---|:---:|:---:|:---:|
| `document.read` | Browse and view document metadata | ✅ | ✅ | ✅ |
| `document.download` | Download file contents from R2 | ✅ | ✅ | ✅ |
| `document.upload` | Initiate and complete file uploads | ✅ | ✅ | ❌ |
| `document.update` | Rename, edit metadata, or move document | ✅ | ✅ | ❌ |
| `document.delete` | Soft-delete document (move to trash) | ✅ | ✅ | ❌ |
| `document.restore` | Restore soft-deleted document from trash | ✅ | ✅ | ❌ |
| `document.share` | Manage internal document access grants | ✅ | ✅ | ❌ |
| `folder.create` | Create new organization folders | ✅ | ✅ | ❌ |
| `folder.update` | Rename or re-parent folders | ✅ | ✅ | ❌ |
| `folder.delete` | Delete folders (empty or recursive) | ✅ | ✅ | ❌ |
| `member.manage` | Invite members, modify roles, remove members | ✅ | ❌ | ❌ |
| `organization.manage` | Organization settings & permanent purge | ✅ | ❌ | ❌ |
| `audit.read` | View organization security audit logs | ✅ | ❌ | ❌ |

---

## Safety Invariants

- **Deny-by-Default**: Any capability not explicitly granted is denied with `403 Forbidden`.
- **Last Administrator Protection**: An administrator cannot demote themselves or be removed if they are the sole remaining active administrator of the organization.
- **Suspended Membership**: If an organization member's status is `suspended`, all capabilities are immediately revoked regardless of their assigned role.
- **Privilege Escalation Prevention**: Managers cannot grant administrative privileges or assign roles higher than their own.

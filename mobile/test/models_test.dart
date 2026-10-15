import 'package:flutter_test/flutter_test.dart';
import 'package:docflare/features/auth/models/user_model.dart';
import 'package:docflare/features/organization/models/organization_model.dart';
import 'package:docflare/features/documents/models/document_model.dart';
import 'package:docflare/features/documents/models/folder_model.dart';
import 'package:docflare/features/admin/models/member_model.dart';

void main() {
  group('Models Serialization Tests', () {
    test('UserModel deserializes from JSON', () {
      final json = {
        'id': 'usr_1',
        'email': 'user@docflare.app',
        'email_verified': true,
        'created_at': '2026-10-15T12:00:00Z',
      };
      final user = UserModel.fromJson(json);
      expect(user.id, 'usr_1');
      expect(user.email, 'user@docflare.app');
      expect(user.emailVerified, true);
    });

    test('OrganizationModel evaluates permissions by role', () {
      final adminOrg = OrganizationModel.fromJson({
        'id': 'org_1',
        'name': 'Acme Corp',
        'slug': 'acme-corp',
        'role': 'admin',
        'storage_quota_bytes': 1000000,
        'storage_used_bytes': 200000,
      });

      expect(adminOrg.isAdmin, true);
      expect(adminOrg.canUpload, true);
      expect(adminOrg.canManageMembers, true);

      final viewerOrg = OrganizationModel.fromJson({
        'id': 'org_2',
        'name': 'Acme Viewer',
        'slug': 'acme-viewer',
        'role': 'viewer',
      });

      expect(viewerOrg.isViewer, true);
      expect(viewerOrg.canUpload, false);
      expect(viewerOrg.canManageMembers, false);
    });

    test('DocumentModel detects preview capabilities', () {
      final imgDoc = DocumentModel.fromJson({
        'id': 'doc_1',
        'organization_id': 'org_1',
        'owner_id': 'usr_1',
        'uploaded_by': 'usr_1',
        'display_name': 'receipt.jpg',
        'content_type': 'image/jpeg',
        'file_size_bytes': 1024,
        'upload_status': 'completed',
        'created_at': '2026-10-15T12:00:00Z',
        'updated_at': '2026-10-15T12:00:00Z',
      });

      expect(imgDoc.isImage, true);
      expect(imgDoc.isPreviewable, true);
      expect(imgDoc.isDeleted, false);
    });

    test('FolderModel deserializes properly', () {
      final folder = FolderModel.fromJson({
        'id': 'fld_1',
        'organization_id': 'org_1',
        'parent_folder_id': null,
        'name': 'Projects',
        'created_at': '2026-10-15T12:00:00Z',
        'updated_at': '2026-10-15T12:00:00Z',
      });

      expect(folder.id, 'fld_1');
      expect(folder.name, 'Projects');
      expect(folder.parentFolderId, isNull);
    });

    test('MemberModel deserializes properly', () {
      final member = MemberModel.fromJson({
        'id': 'mem_1',
        'user_id': 'usr_1',
        'email': 'admin@test.com',
        'role': 'admin',
        'status': 'active',
        'created_at': '2026-10-15T12:00:00Z',
      });

      expect(member.isAdmin, true);
      expect(member.isActive, true);
    });
  });
}

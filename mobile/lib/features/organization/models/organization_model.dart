class OrganizationModel {
  final String id;
  final String name;
  final String slug;
  final String role; // 'admin', 'manager', 'viewer'
  final String status;
  final int storageQuotaBytes;
  final int storageUsedBytes;

  OrganizationModel({
    required this.id,
    required this.name,
    required this.slug,
    required this.role,
    this.status = 'active',
    this.storageQuotaBytes = 10737418240,
    this.storageUsedBytes = 0,
  });

  bool get isAdmin => role == 'admin';
  bool get isManager => role == 'manager';
  bool get isViewer => role == 'viewer';
  bool get canUpload => role == 'admin' || role == 'manager';
  bool get canManageMembers => role == 'admin';

  factory OrganizationModel.fromJson(Map<String, dynamic> json) {
    return OrganizationModel(
      id: json['id'] ?? json['organization_id'] ?? '',
      name: json['name'] ?? '',
      slug: json['slug'] ?? '',
      role: json['role'] ?? json['your_role'] ?? 'viewer',
      status: json['status'] ?? 'active',
      storageQuotaBytes: json['storage_quota_bytes'] ?? 10737418240,
      storageUsedBytes: json['storage_used_bytes'] ?? 0,
    );
  }
}

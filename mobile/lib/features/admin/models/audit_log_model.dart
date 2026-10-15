class AuditLogModel {
  final String id;
  final String organizationId;
  final String actorUserId;
  final String? actorEmail;
  final String action;
  final String resourceType;
  final String resourceId;
  final String? metadataJson;
  final String createdAt;

  AuditLogModel({
    required this.id,
    required this.organizationId,
    required this.actorUserId,
    this.actorEmail,
    required this.action,
    required this.resourceType,
    required this.resourceId,
    this.metadataJson,
    required this.createdAt,
  });

  factory AuditLogModel.fromJson(Map<String, dynamic> json) {
    return AuditLogModel(
      id: json['id'] ?? '',
      organizationId: json['organization_id'] ?? '',
      actorUserId: json['actor_user_id'] ?? '',
      actorEmail: json['actor_email'],
      action: json['action'] ?? '',
      resourceType: json['resource_type'] ?? '',
      resourceId: json['resource_id'] ?? '',
      metadataJson: json['metadata_json'],
      createdAt: json['created_at'] ?? '',
    );
  }
}

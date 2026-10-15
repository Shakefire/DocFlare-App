class FolderModel {
  final String id;
  final String organizationId;
  final String? parentFolderId;
  final String name;
  final String? createdBy;
  final String createdAt;
  final String updatedAt;

  FolderModel({
    required this.id,
    required this.organizationId,
    this.parentFolderId,
    required this.name,
    this.createdBy,
    required this.createdAt,
    required this.updatedAt,
  });

  factory FolderModel.fromJson(Map<String, dynamic> json) {
    return FolderModel(
      id: json['id'] ?? '',
      organizationId: json['organization_id'] ?? '',
      parentFolderId: json['parent_folder_id'],
      name: json['name'] ?? '',
      createdBy: json['created_by'],
      createdAt: json['created_at'] ?? '',
      updatedAt: json['updated_at'] ?? '',
    );
  }
}

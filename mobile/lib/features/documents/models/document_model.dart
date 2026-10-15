import '../../../core/utils/file_utils.dart';

class DocumentModel {
  final String id;
  final String organizationId;
  final String? folderId;
  final String ownerId;
  final String uploadedBy;
  final String displayName;
  final String contentType;
  final int fileSizeBytes;
  final String? checksum;
  final String? description;
  final String uploadStatus;
  final String createdAt;
  final String updatedAt;
  final String? deletedAt;

  DocumentModel({
    required this.id,
    required this.organizationId,
    this.folderId,
    required this.ownerId,
    required this.uploadedBy,
    required this.displayName,
    required this.contentType,
    required this.fileSizeBytes,
    this.checksum,
    this.description,
    required this.uploadStatus,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
  });

  bool get isPreviewable => FileUtils.isPreviewable(contentType);
  bool get isImage => FileUtils.isImage(contentType);
  bool get isPdf => FileUtils.isPdf(contentType);
  bool get isVideo => FileUtils.isVideo(contentType);
  bool get isDeleted => deletedAt != null;

  factory DocumentModel.fromJson(Map<String, dynamic> json) {
    return DocumentModel(
      id: json['id'] ?? '',
      organizationId: json['organization_id'] ?? '',
      folderId: json['folder_id'],
      ownerId: json['owner_id'] ?? '',
      uploadedBy: json['uploaded_by'] ?? '',
      displayName: json['display_name'] ?? '',
      contentType: json['content_type'] ?? 'application/octet-stream',
      fileSizeBytes: json['file_size_bytes'] ?? 0,
      checksum: json['checksum'],
      description: json['description'],
      uploadStatus: json['upload_status'] ?? 'completed',
      createdAt: json['created_at'] ?? '',
      updatedAt: json['updated_at'] ?? '',
      deletedAt: json['deleted_at'],
    );
  }
}

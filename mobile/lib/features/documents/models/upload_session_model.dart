class UploadSessionModel {
  final String uploadSessionId;
  final String documentId;
  final String uploadMode;
  final int expectedSizeBytes;
  final String expiresAt;
  final String uploadUrl;

  UploadSessionModel({
    required this.uploadSessionId,
    required this.documentId,
    required this.uploadMode,
    required this.expectedSizeBytes,
    required this.expiresAt,
    required this.uploadUrl,
  });

  factory UploadSessionModel.fromJson(Map<String, dynamic> json) {
    return UploadSessionModel(
      uploadSessionId: json['upload_session_id'] ?? '',
      documentId: json['document_id'] ?? '',
      uploadMode: json['upload_mode'] ?? 'single',
      expectedSizeBytes: json['expected_size_bytes'] ?? 0,
      expiresAt: json['expires_at'] ?? '',
      uploadUrl: json['upload_url'] ?? '',
    );
  }
}

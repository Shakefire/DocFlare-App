class MemberModel {
  final String id;
  final String userId;
  final String email;
  final String role;
  final String status;
  final String createdAt;

  MemberModel({
    required this.id,
    required this.userId,
    required this.email,
    required this.role,
    required this.status,
    required this.createdAt,
  });

  bool get isAdmin => role == 'admin';
  bool get isManager => role == 'manager';
  bool get isViewer => role == 'viewer';
  bool get isActive => status == 'active';

  factory MemberModel.fromJson(Map<String, dynamic> json) {
    return MemberModel(
      id: json['id'] ?? '',
      userId: json['user_id'] ?? '',
      email: json['email'] ?? '',
      role: json['role'] ?? 'viewer',
      status: json['status'] ?? 'active',
      createdAt: json['created_at'] ?? '',
    );
  }
}

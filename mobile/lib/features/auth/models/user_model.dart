class UserModel {
  final String id;
  final String email;
  final bool emailVerified;
  final String? createdAt;

  UserModel({
    required this.id,
    required this.email,
    required this.emailVerified,
    this.createdAt,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] ?? '',
      email: json['email'] ?? '',
      emailVerified: json['email_verified'] == true,
      createdAt: json['created_at'],
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'email': email,
        'email_verified': emailVerified,
        'created_at': createdAt,
      };
}

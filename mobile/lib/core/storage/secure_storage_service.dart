import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorageService {
  static const String _keyToken = 'docflare_session_token';
  static const String _keyActiveOrgId = 'docflare_active_org_id';
  static const String _keyUserEmail = 'docflare_user_email';

  final FlutterSecureStorage _storage;

  SecureStorageService({FlutterSecureStorage? storage})
      : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(),
              iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
            );

  Future<void> saveToken(String token) async {
    await _storage.write(key: _keyToken, value: token);
  }

  Future<String?> getToken() async {
    return await _storage.read(key: _keyToken);
  }

  Future<void> deleteToken() async {
    await _storage.delete(key: _keyToken);
  }

  Future<void> saveActiveOrgId(String orgId) async {
    await _storage.write(key: _keyActiveOrgId, value: orgId);
  }

  Future<String?> getActiveOrgId() async {
    return await _storage.read(key: _keyActiveOrgId);
  }

  Future<void> deleteActiveOrgId() async {
    await _storage.delete(key: _keyActiveOrgId);
  }

  Future<void> saveUserEmail(String email) async {
    await _storage.write(key: _keyUserEmail, value: email);
  }

  Future<String?> getUserEmail() async {
    return await _storage.read(key: _keyUserEmail);
  }

  Future<void> clearAll() async {
    await _storage.deleteAll();
  }
}

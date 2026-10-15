import 'package:flutter/material.dart';
import '../../../core/network/api_client.dart';
import '../../../core/storage/secure_storage_service.dart';
import '../models/user_model.dart';
import '../../organization/models/organization_model.dart';

enum AuthStatus { initial, loading, authenticated, unauthenticated, error }

class AuthProvider extends ChangeNotifier {
  final ApiClient _api;
  final SecureStorageService _storage;

  AuthStatus _status = AuthStatus.initial;
  UserModel? _user;
  List<OrganizationModel> _organizations = [];
  String? _errorMessage;

  AuthStatus get status => _status;
  UserModel? get user => _user;
  List<OrganizationModel> get organizations => _organizations;
  String? get errorMessage => _errorMessage;
  bool get isAuthenticated => _status == AuthStatus.authenticated && _user != null;

  AuthProvider({ApiClient? api, SecureStorageService? storage})
      : _api = api ?? ApiClient(),
        _storage = storage ?? SecureStorageService() {
    _api.onSessionExpired = () {
      logout();
    };
  }

  Future<void> checkAuthStatus() async {
    _status = AuthStatus.loading;
    notifyListeners();

    final token = await _storage.getToken();
    if (token == null || token.isEmpty) {
      _status = AuthStatus.unauthenticated;
      notifyListeners();
      return;
    }

    try {
      final res = await _api.get('/auth/me');
      final data = res['data'];
      _user = UserModel.fromJson(data);

      if (data['organizations'] is List) {
        _organizations = (data['organizations'] as List)
            .map((e) => OrganizationModel.fromJson(e))
            .toList();
      }

      _status = AuthStatus.authenticated;
      _errorMessage = null;
    } catch (e) {
      await _storage.deleteToken();
      _status = AuthStatus.unauthenticated;
    }
    notifyListeners();
  }

  Future<bool> login(String email, String password) async {
    _status = AuthStatus.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      final res = await _api.post('/auth/login', body: {
        'email': email.trim(),
        'password': password,
      });

      final token = res['data']['token'];
      final userData = res['data']['user'];

      await _storage.saveToken(token);
      await _storage.saveUserEmail(email.trim());

      _user = UserModel.fromJson(userData);
      _status = AuthStatus.authenticated;

      // Load full profile & organizations
      await checkAuthStatus();
      return true;
    } catch (e) {
      _status = AuthStatus.error;
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> register(String email, String password) async {
    _status = AuthStatus.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      await _api.post('/auth/register', body: {
        'email': email.trim(),
        'password': password,
      });
      _status = AuthStatus.unauthenticated;
      notifyListeners();
      return true;
    } catch (e) {
      _status = AuthStatus.error;
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> verifyEmail(String token) async {
    _status = AuthStatus.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      await _api.post('/auth/verify-email', body: {'token': token.trim()});
      await checkAuthStatus();
      return true;
    } catch (e) {
      _status = AuthStatus.error;
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> resendVerification(String email) async {
    try {
      await _api.post('/auth/resend-verification', body: {'email': email.trim()});
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> forgotPassword(String email) async {
    _status = AuthStatus.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      await _api.post('/auth/forgot-password', body: {'email': email.trim()});
      _status = AuthStatus.unauthenticated;
      notifyListeners();
      return true;
    } catch (e) {
      _status = AuthStatus.error;
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> resetPassword(String token, String newPassword) async {
    _status = AuthStatus.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      await _api.post('/auth/reset-password', body: {
        'token': token.trim(),
        'new_password': newPassword,
      });
      _status = AuthStatus.unauthenticated;
      notifyListeners();
      return true;
    } catch (e) {
      _status = AuthStatus.error;
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<void> logout() async {
    try {
      await _api.post('/auth/logout');
    } catch (_) {}

    await _storage.clearAll();
    _user = null;
    _organizations = [];
    _status = AuthStatus.unauthenticated;
    _errorMessage = null;
    notifyListeners();
  }
}

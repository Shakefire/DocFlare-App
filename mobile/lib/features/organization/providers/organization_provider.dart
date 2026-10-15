import 'package:flutter/material.dart';
import '../../../core/network/api_client.dart';
import '../../../core/storage/secure_storage_service.dart';
import '../models/organization_model.dart';

class OrganizationProvider extends ChangeNotifier {
  final ApiClient _api;
  final SecureStorageService _storage;

  List<OrganizationModel> _organizations = [];
  OrganizationModel? _activeOrganization;
  bool _isLoading = false;
  String? _errorMessage;

  List<OrganizationModel> get organizations => _organizations;
  OrganizationModel? get activeOrganization => _activeOrganization;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  OrganizationProvider({ApiClient? api, SecureStorageService? storage})
      : _api = api ?? ApiClient(),
        _storage = storage ?? SecureStorageService();

  Future<void> loadOrganizations() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final res = await _api.get('/organizations');
      final list = res['data'] as List;
      _organizations = list.map((e) => OrganizationModel.fromJson(e)).toList();

      final savedOrgId = await _storage.getActiveOrgId();
      if (savedOrgId != null) {
        _activeOrganization = _organizations.firstWhere(
          (o) => o.id == savedOrgId,
          orElse: () => _organizations.isNotEmpty ? _organizations.first : null as dynamic,
        );
      } else if (_organizations.isNotEmpty) {
        _activeOrganization = _organizations.first;
        await _storage.saveActiveOrgId(_activeOrganization!.id);
      }

      _isLoading = false;
    } catch (e) {
      _isLoading = false;
      _errorMessage = e.toString();
    }
    notifyListeners();
  }

  Future<void> selectOrganization(OrganizationModel org) async {
    _activeOrganization = org;
    await _storage.saveActiveOrgId(org.id);
    notifyListeners();
  }

  Future<OrganizationModel?> createOrganization(String name) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final res = await _api.post('/organizations', body: {'name': name.trim()});
      final orgData = res['data'];
      final newOrg = OrganizationModel(
        id: orgData['id'],
        name: orgData['name'],
        slug: orgData['slug'],
        role: orgData['role'] ?? 'admin',
      );

      _organizations.add(newOrg);
      await selectOrganization(newOrg);

      _isLoading = false;
      notifyListeners();
      return newOrg;
    } catch (e) {
      _isLoading = false;
      _errorMessage = e.toString();
      notifyListeners();
      return null;
    }
  }

  Future<bool> inviteMember(String email, String role) async {
    if (_activeOrganization == null) return false;
    try {
      await _api.post('/organizations/${_activeOrganization!.id}/invitations', body: {
        'email': email.trim(),
        'role': role,
      });
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> acceptInvitation(String token) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final res = await _api.post('/invitations/accept', body: {'token': token.trim()});
      final orgId = res['data']['organization_id'];
      await loadOrganizations();

      final matching = _organizations.where((o) => o.id == orgId);
      if (matching.isNotEmpty) {
        await selectOrganization(matching.first);
      }

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isLoading = false;
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }
}

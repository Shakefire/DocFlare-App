import 'package:flutter/material.dart';
import '../../../core/network/api_client.dart';
import '../models/member_model.dart';
import '../models/audit_log_model.dart';
import '../../documents/models/document_model.dart';

class AdminProvider extends ChangeNotifier {
  final ApiClient _api;

  List<MemberModel> _members = [];
  List<DocumentModel> _trashDocuments = [];
  List<AuditLogModel> _auditLogs = [];
  Map<String, dynamic>? _storageUsage;

  bool _isLoading = false;
  String? _errorMessage;

  List<MemberModel> get members => _members;
  List<DocumentModel> get trashDocuments => _trashDocuments;
  List<AuditLogModel> get auditLogs => _auditLogs;
  Map<String, dynamic>? get storageUsage => _storageUsage;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  AdminProvider({ApiClient? api}) : _api = api ?? ApiClient();

  Future<void> loadMembers(String orgId) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final res = await _api.get('/organizations/$orgId/members');
      final list = res['data'] as List;
      _members = list.map((e) => MemberModel.fromJson(e)).toList();
      _isLoading = false;
    } catch (e) {
      _isLoading = false;
      _errorMessage = e.toString();
    }
    notifyListeners();
  }

  Future<bool> updateMemberRole(String orgId, String memberId, String role) async {
    try {
      await _api.patch('/organizations/$orgId/members/$memberId', body: {'role': role});
      await loadMembers(orgId);
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> removeMember(String orgId, String memberId) async {
    try {
      await _api.delete('/organizations/$orgId/members/$memberId');
      _members.removeWhere((m) => m.id == memberId);
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<void> loadTrash(String orgId) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final res = await _api.get('/organizations/$orgId/trash');
      final list = res['data'] as List;
      _trashDocuments = list.map((e) => DocumentModel.fromJson(e)).toList();
      _isLoading = false;
    } catch (e) {
      _isLoading = false;
      _errorMessage = e.toString();
    }
    notifyListeners();
  }

  Future<bool> permanentDelete(String orgId, String documentId) async {
    try {
      await _api.delete('/organizations/$orgId/trash/$documentId');
      _trashDocuments.removeWhere((d) => d.id == documentId);
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<void> loadAuditLogs(String orgId, {String? action, String? resourceType}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final queryParams = <String, String>{};
      if (action != null && action.isNotEmpty) queryParams['action'] = action;
      if (resourceType != null && resourceType.isNotEmpty) queryParams['resource_type'] = resourceType;

      final res = await _api.get('/organizations/$orgId/audit-logs', queryParams: queryParams);
      final list = res['data'] as List;
      _auditLogs = list.map((e) => AuditLogModel.fromJson(e)).toList();
      _isLoading = false;
    } catch (e) {
      _isLoading = false;
      _errorMessage = e.toString();
    }
    notifyListeners();
  }

  Future<void> loadStorageUsage(String orgId) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final res = await _api.get('/organizations/$orgId/storage-usage');
      _storageUsage = res['data'] as Map<String, dynamic>;
      _isLoading = false;
    } catch (e) {
      _isLoading = false;
      _errorMessage = e.toString();
    }
    notifyListeners();
  }
}

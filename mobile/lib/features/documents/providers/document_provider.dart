import 'package:flutter/material.dart';
import '../../../core/network/api_client.dart';
import '../models/document_model.dart';
import '../models/folder_model.dart';

class DocumentProvider extends ChangeNotifier {
  final ApiClient _api;

  List<DocumentModel> _documents = [];
  List<FolderModel> _folders = [];
  final List<FolderModel> _breadcrumbStack = [];
  FolderModel? _currentFolder;

  bool _isLoading = false;
  String? _errorMessage;

  List<DocumentModel> get documents => _documents;
  List<FolderModel> get folders => _folders;
  List<FolderModel> get breadcrumbs => _breadcrumbStack;
  FolderModel? get currentFolder => _currentFolder;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  DocumentProvider({ApiClient? api}) : _api = api ?? ApiClient();

  Future<void> loadContents(String orgId, {FolderModel? folder}) async {
    _isLoading = true;
    _errorMessage = null;
    _currentFolder = folder;
    notifyListeners();

    try {
      final folderParam = folder != null ? folder.id : 'null';

      // Load folders
      final folderRes = await _api.get(
        '/organizations/$orgId/folders',
        queryParams: {'parent_folder_id': folderParam},
      );
      final folderList = folderRes['data'] as List;
      _folders = folderList.map((e) => FolderModel.fromJson(e)).toList();

      // Load documents
      final docRes = await _api.get(
        '/organizations/$orgId/documents',
        queryParams: {'folder_id': folderParam},
      );
      final docList = docRes['data'] as List;
      _documents = docList.map((e) => DocumentModel.fromJson(e)).toList();

      _isLoading = false;
    } catch (e) {
      _isLoading = false;
      _errorMessage = e.toString();
    }
    notifyListeners();
  }

  void openFolder(String orgId, FolderModel folder) {
    _breadcrumbStack.add(folder);
    loadContents(orgId, folder: folder);
  }

  void navigateUp(String orgId) {
    if (_breadcrumbStack.isNotEmpty) {
      _breadcrumbStack.removeLast();
      final parent = _breadcrumbStack.isNotEmpty ? _breadcrumbStack.last : null;
      loadContents(orgId, folder: parent);
    }
  }

  void resetNavigation(String orgId) {
    _breadcrumbStack.clear();
    loadContents(orgId, folder: null);
  }

  Future<bool> createFolder(String orgId, String name) async {
    try {
      await _api.post('/organizations/$orgId/folders', body: {
        'name': name.trim(),
        'parent_folder_id': _currentFolder?.id,
      });
      await loadContents(orgId, folder: _currentFolder);
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> renameFolder(String orgId, String folderId, String newName) async {
    try {
      await _api.patch('/folders/$folderId', body: {'name': newName.trim()});
      await loadContents(orgId, folder: _currentFolder);
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteFolder(String orgId, String folderId, {bool recursive = false}) async {
    try {
      await _api.delete('/folders/$folderId', queryParams: {'recursive': recursive.toString()});
      await loadContents(orgId, folder: _currentFolder);
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateDocument(
    String orgId,
    String documentId, {
    String? displayName,
    String? description,
    String? folderId,
  }) async {
    try {
      await _api.patch('/documents/$documentId', body: {
        if (displayName != null) 'display_name': displayName.trim(),
        if (description != null) 'description': description.trim(),
        if (folderId != null) 'folder_id': folderId,
      });
      await loadContents(orgId, folder: _currentFolder);
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> softDeleteDocument(String orgId, String documentId) async {
    try {
      await _api.delete('/documents/$documentId');
      _documents.removeWhere((d) => d.id == documentId);
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> restoreDocument(String orgId, String documentId) async {
    try {
      await _api.post('/documents/$documentId/restore');
      await loadContents(orgId, folder: _currentFolder);
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<List<DocumentModel>> searchDocuments(
    String orgId, {
    String query = '',
    String? type,
    String? sortBy,
    String? order,
  }) async {
    final queryParams = <String, String>{};
    if (query.isNotEmpty) queryParams['q'] = query;
    if (type != null && type.isNotEmpty) queryParams['type'] = type;
    if (sortBy != null) queryParams['sort_by'] = sortBy;
    if (order != null) queryParams['order'] = order;

    try {
      final res = await _api.get('/organizations/$orgId/search', queryParams: queryParams);
      final list = res['data'] as List;
      return list.map((e) => DocumentModel.fromJson(e)).toList();
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return [];
    }
  }
}

import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../../../core/network/api_client.dart';
import '../../../core/utils/file_utils.dart';
import '../models/upload_session_model.dart';

enum UploadTaskStatus { pending, uploading, completed, failed, cancelled }

class UploadTask {
  final String id;
  final File? file;
  final List<int>? bytes;
  final String displayName;
  final int fileSize;
  final String contentType;
  final String? folderId;
  final String? description;

  UploadTaskStatus status;
  double progress;
  String? errorMessage;
  String? uploadSessionId;

  UploadTask({
    required this.id,
    this.file,
    this.bytes,
    required this.displayName,
    required this.fileSize,
    required this.contentType,
    this.folderId,
    this.description,
    this.status = UploadTaskStatus.pending,
    this.progress = 0.0,
    this.errorMessage,
    this.uploadSessionId,
  });
}

class UploadProvider extends ChangeNotifier {
  final ApiClient _api;
  final List<UploadTask> _tasks = [];

  List<UploadTask> get tasks => _tasks;
  bool get hasActiveUploads => _tasks.any((t) => t.status == UploadTaskStatus.uploading || t.status == UploadTaskStatus.pending);

  UploadProvider({ApiClient? api}) : _api = api ?? ApiClient();

  Future<void> enqueuePlatformFile(
    PlatformFile platformFile,
    String orgId, {
    String? folderId,
    String? description,
  }) async {
    final fileName = platformFile.name;
    final bytes = await platformFile.readAsBytes();
    final fileSize = platformFile.lengthSync() ?? (await platformFile.length()) ?? bytes.length;
    final contentType = FileUtils.getMimeType(fileName);

    File? file;
    if (platformFile.path != null) {
      try {
        file = File(platformFile.path!);
      } catch (_) {}
    }

    final task = UploadTask(
      id: '${DateTime.now().millisecondsSinceEpoch}_$fileName',
      file: file,
      bytes: bytes,
      displayName: fileName,
      fileSize: fileSize,
      contentType: contentType,
      folderId: folderId,
      description: description,
    );

    _tasks.insert(0, task);
    notifyListeners();

    _processTask(task, orgId);
  }

  Future<void> enqueueFile(
    File file,
    String orgId, {
    String? folderId,
    String? description,
  }) async {
    final fileName = file.path.split(RegExp(r'[\\/]')).last;
    final bytes = await file.readAsBytes();
    final fileSize = bytes.length;
    final contentType = FileUtils.getMimeType(fileName);

    final task = UploadTask(
      id: '${DateTime.now().millisecondsSinceEpoch}_$fileName',
      file: file,
      bytes: bytes,
      displayName: fileName,
      fileSize: fileSize,
      contentType: contentType,
      folderId: folderId,
      description: description,
    );

    _tasks.insert(0, task);
    notifyListeners();

    _processTask(task, orgId);
  }

  Future<void> _processTask(UploadTask task, String orgId) async {
    task.status = UploadTaskStatus.uploading;
    task.progress = 0.05;
    task.errorMessage = null;
    notifyListeners();

    try {
      // Step 1: Initiate upload session with Worker
      final initRes = await _api.post('/organizations/$orgId/uploads', body: {
        'display_name': task.displayName,
        'file_size_bytes': task.fileSize,
        'content_type': task.contentType,
        'folder_id': task.folderId,
        'description': task.description,
      });

      final session = UploadSessionModel.fromJson(initRes['data']);
      task.uploadSessionId = session.uploadSessionId;
      task.progress = 0.15;
      notifyListeners();

      // Step 2: Stream/upload binary file payload to Worker direct R2 endpoint
      final payload = task.bytes ?? await task.file!.readAsBytes();
      await _api.uploadBytes(
        session.uploadUrl,
        payload,
        contentType: task.contentType,
        onProgress: (sent, total) {
          if (total > 0) {
            task.progress = 0.15 + (sent / total) * 0.75;
            notifyListeners();
          }
        },
      );

      // Step 3: Complete upload session with Worker
      task.progress = 0.95;
      notifyListeners();

      await _api.post('/uploads/${session.uploadSessionId}/complete', body: {});

      task.status = UploadTaskStatus.completed;
      task.progress = 1.0;
      notifyListeners();
    } catch (e) {
      task.status = UploadTaskStatus.failed;
      task.errorMessage = e.toString();
      notifyListeners();
    }
  }

  void retryTask(UploadTask task, String orgId) {
    if (task.status == UploadTaskStatus.failed || task.status == UploadTaskStatus.cancelled) {
      _processTask(task, orgId);
    }
  }

  Future<void> cancelTask(UploadTask task) async {
    if (task.uploadSessionId != null && task.status == UploadTaskStatus.uploading) {
      try {
        await _api.post('/uploads/${task.uploadSessionId}/cancel');
      } catch (_) {}
    }
    task.status = UploadTaskStatus.cancelled;
    task.errorMessage = 'Upload cancelled by user';
    notifyListeners();
  }

  void clearCompleted() {
    _tasks.removeWhere((t) => t.status == UploadTaskStatus.completed);
    notifyListeners();
  }
}

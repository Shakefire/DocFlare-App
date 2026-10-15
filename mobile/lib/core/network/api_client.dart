import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../constants/api_constants.dart';
import '../storage/secure_storage_service.dart';

class ApiException implements Exception {
  final int statusCode;
  final String code;
  final String message;
  final Map<String, dynamic>? details;

  ApiException({
    required this.statusCode,
    required this.code,
    required this.message,
    this.details,
  });

  @override
  String toString() => message;
}

class ApiClient {
  final String baseUrl;
  final SecureStorageService _storage;
  final http.Client _client;
  Function()? onSessionExpired;

  ApiClient({
    String? baseUrl,
    SecureStorageService? storage,
    http.Client? client,
    this.onSessionExpired,
  })  : baseUrl = baseUrl ?? ApiConstants.baseUrl,
        _storage = storage ?? SecureStorageService(),
        _client = client ?? http.Client();

  Future<Map<String, String>> _headers({bool isJson = true}) async {
    final headers = <String, String>{};
    if (isJson) {
      headers['Content-Type'] = 'application/json';
    }
    final token = await _storage.getToken();
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  dynamic _handleResponse(http.Response response) {
    if (response.statusCode == 401) {
      onSessionExpired?.call();
    }

    dynamic body;
    try {
      body = jsonDecode(utf8.decode(response.bodyBytes));
    } catch (_) {
      body = null;
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return body;
    }

    if (body is Map<String, dynamic> && body.containsKey('error')) {
      final err = body['error'];
      throw ApiException(
        statusCode: response.statusCode,
        code: err['code'] ?? 'ERROR',
        message: err['message'] ?? 'Request failed',
        details: err['details'] is Map<String, dynamic> ? err['details'] : null,
      );
    }

    throw ApiException(
      statusCode: response.statusCode,
      code: 'HTTP_${response.statusCode}',
      message: 'Request failed with status ${response.statusCode}',
    );
  }

  Uri _buildUri(String path, [Map<String, String>? queryParams]) {
    Uri uri;
    if (path.startsWith('http://') || path.startsWith('https://')) {
      uri = Uri.parse(path);
    } else {
      final cleanBase = baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl;
      String cleanPath = path.startsWith('/') ? path : '/$path';
      if (cleanBase.endsWith('/api/v1') && cleanPath.startsWith('/api/v1/')) {
        cleanPath = cleanPath.substring(7); // strip redundant /api/v1
      }
      uri = Uri.parse('$cleanBase$cleanPath');
    }
    if (queryParams != null && queryParams.isNotEmpty) {
      uri = uri.replace(queryParameters: queryParams);
    }
    return uri;
  }

  Future<dynamic> get(String path, {Map<String, String>? queryParams}) async {
    final uri = _buildUri(path, queryParams);
    final headers = await _headers();
    final response = await _client.get(uri, headers: headers).timeout(ApiConstants.timeout);
    return _handleResponse(response);
  }

  Future<dynamic> post(String path, {dynamic body}) async {
    final uri = _buildUri(path);
    final headers = await _headers();
    final response = await _client
        .post(uri, headers: headers, body: body != null ? jsonEncode(body) : null)
        .timeout(ApiConstants.timeout);
    return _handleResponse(response);
  }

  Future<dynamic> put(String path, {dynamic body}) async {
    final uri = _buildUri(path);
    final headers = await _headers();
    final response = await _client
        .put(uri, headers: headers, body: body != null ? jsonEncode(body) : null)
        .timeout(ApiConstants.timeout);
    return _handleResponse(response);
  }

  Future<dynamic> patch(String path, {dynamic body}) async {
    final uri = _buildUri(path);
    final headers = await _headers();
    final response = await _client
        .patch(uri, headers: headers, body: body != null ? jsonEncode(body) : null)
        .timeout(ApiConstants.timeout);
    return _handleResponse(response);
  }

  Future<dynamic> delete(String path, {Map<String, String>? queryParams}) async {
    final uri = _buildUri(path, queryParams);
    final headers = await _headers();
    final response = await _client.delete(uri, headers: headers).timeout(ApiConstants.timeout);
    return _handleResponse(response);
  }

  /// Direct binary upload of byte payload (Universal Web + Mobile)
  Future<dynamic> uploadBytes(
    String path,
    List<int> bytes, {
    String contentType = 'application/octet-stream',
    Function(int sent, int total)? onProgress,
  }) async {
    final uri = _buildUri(path);
    final token = await _storage.getToken();

    final headers = <String, String>{
      'Content-Type': contentType,
    };
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }

    onProgress?.call(0, bytes.length);
    final response = await _client
        .put(uri, headers: headers, body: bytes)
        .timeout(ApiConstants.uploadTimeout);
    onProgress?.call(bytes.length, bytes.length);
    return _handleResponse(response);
  }

  /// Download file to destination path
  Future<File> downloadFile(String path, String savePath, {Function(int received, int total)? onProgress}) async {
    final uri = Uri.parse('$baseUrl$path');
    final headers = await _headers(isJson: false);

    final request = http.Request('GET', uri)..headers.addAll(headers);
    final streamedResponse = await _client.send(request).timeout(ApiConstants.uploadTimeout);

    if (streamedResponse.statusCode >= 400) {
      final res = await http.Response.fromStream(streamedResponse);
      _handleResponse(res);
    }

    final totalBytes = streamedResponse.contentLength ?? -1;
    var receivedBytes = 0;
    final file = File(savePath);
    final sink = file.openWrite();

    await for (final chunk in streamedResponse.stream) {
      sink.add(chunk);
      receivedBytes += chunk.length;
      onProgress?.call(receivedBytes, totalBytes);
    }

    await sink.flush();
    await sink.close();
    return file;
  }
}

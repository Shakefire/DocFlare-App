import 'package:mime/mime.dart';

class FileUtils {
  static String getMimeType(String filePath) {
    return lookupMimeType(filePath) ?? 'application/octet-stream';
  }

  static bool isImage(String mimeType) {
    return mimeType.startsWith('image/');
  }

  static bool isPdf(String mimeType) {
    return mimeType == 'application/pdf';
  }

  static bool isVideo(String mimeType) {
    return mimeType.startsWith('video/');
  }

  static bool isPreviewable(String mimeType) {
    final lower = mimeType.toLowerCase();
    return lower.startsWith('image/') ||
        lower == 'application/pdf' ||
        lower == 'text/plain' ||
        lower.startsWith('video/');
  }

  static String getFileExtension(String filename) {
    final parts = filename.split('.');
    return parts.length > 1 ? parts.last.toLowerCase() : '';
  }
}

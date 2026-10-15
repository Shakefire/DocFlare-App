import 'package:flutter_test/flutter_test.dart';
import 'package:docflare/core/utils/file_utils.dart';

void main() {
  group('FileUtils Unit Tests', () {
    test('extracts file extensions correctly', () {
      expect(FileUtils.getFileExtension('document.pdf'), 'pdf');
      expect(FileUtils.getFileExtension('PHOTO.PNG'), 'png');
      expect(FileUtils.getFileExtension('archive.tar.gz'), 'gz');
      expect(FileUtils.getFileExtension('noextension'), '');
    });

    test('detects previewable types', () {
      expect(FileUtils.isImage('image/jpeg'), true);
      expect(FileUtils.isImage('image/png'), true);
      expect(FileUtils.isPdf('application/pdf'), true);
      expect(FileUtils.isVideo('video/mp4'), true);

      expect(FileUtils.isPreviewable('image/webp'), true);
      expect(FileUtils.isPreviewable('application/pdf'), true);
      expect(FileUtils.isPreviewable('text/plain'), true);
      expect(FileUtils.isPreviewable('video/quicktime'), true);

      // Office files require downloading first
      expect(FileUtils.isPreviewable('application/msword'), false);
    });
  });
}

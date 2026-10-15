import 'package:flutter_test/flutter_test.dart';
import 'package:docflare/core/utils/formatters.dart';

void main() {
  group('Formatters Unit Tests', () {
    test('formats bytes to human-readable strings', () {
      expect(Formatters.formatBytes(0), '0 B');
      expect(Formatters.formatBytes(500), '500.0 B');
      expect(Formatters.formatBytes(1024), '1.0 KB');
      expect(Formatters.formatBytes(1024 * 1024), '1.0 MB');
      expect(Formatters.formatBytes(1024 * 1024 * 1024), '1.0 GB');
      expect(Formatters.formatBytes(1024 * 1024 * 1024 * 2), '2.0 GB');
    });

    test('formats dates gracefully', () {
      expect(Formatters.formatDate(null), '-');
      expect(Formatters.formatDate(''), '-');
      expect(Formatters.formatDateShort(null), '-');
    });
  });
}

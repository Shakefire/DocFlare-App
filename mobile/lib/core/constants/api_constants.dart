class ApiConstants {
  // Default to local Cloudflare Worker dev URL
  // Can be overridden via --dart-define=API_BASE_URL=https://your-worker.workers.dev
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://127.0.0.1:8787/api/v1',
  );

  static const Duration timeout = Duration(seconds: 30);
  static const Duration uploadTimeout = Duration(minutes: 10);
}

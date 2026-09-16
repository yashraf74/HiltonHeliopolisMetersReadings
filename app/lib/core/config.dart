/// Build-time configuration. Override with
/// `flutter build apk --dart-define=API_BASE_URL=https://...`.
class BuildConfig {
  static const apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://hilton-heliopolis-meters-api.y-ashraf74.workers.dev',
  );

  static const requestTimeout = Duration(seconds: 20);
}

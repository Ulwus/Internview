/// API Gateway kök URL'i.
///
/// Android emülatör: `--dart-define=API_BASE_URL=http://10.0.2.2:8080`
/// iOS simülatör: `--dart-define=API_BASE_URL=http://localhost:8080`
class Env {
  Env._();

  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:8080',
  );
}

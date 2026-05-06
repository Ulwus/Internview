import 'dart:io';

/// Android emülatörde backend `localhost` ise WebSocket/ICE için `10.0.2.2` kullanılır.
String replaceLocalhostForAndroid(String url) {
  if (!Platform.isAndroid) return url;
  return url
      .replaceAll('://localhost', '://10.0.2.2')
      .replaceAll('://127.0.0.1', '://10.0.2.2');
}

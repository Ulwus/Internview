class ApiException implements Exception {
  ApiException({
    this.code,
    required this.message,
    this.statusCode,
  });

  final String? code;
  final String message;
  final int? statusCode;

  @override
  String toString() => 'ApiException($code, $message, status=$statusCode)';
}

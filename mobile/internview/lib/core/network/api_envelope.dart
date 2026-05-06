import 'api_exception.dart';

/// Auth / User / Booking servislerinin `{ success, data, timestamp }` zarfı.
class ApiEnvelope {
  ApiEnvelope._();

  static T parseData<T>(
    dynamic responseBody,
    T Function(Object? json) fromData,
  ) {
    if (responseBody is! Map) {
      throw ApiException(message: 'Beklenmeyen yanıt biçimi');
    }
    final map = Map<String, dynamic>.from(responseBody);
    final success = map['success'] as bool?;
    if (success == true) {
      return fromData(map['data']);
    }
    final err = map['error'];
    if (err is Map) {
      final code = err['code'] as String?;
      final message = err['message'] as String? ?? 'İstek başarısız';
      throw ApiException(code: code, message: message);
    }
    throw ApiException(message: map['message'] as String? ?? 'İstek başarısız');
  }

  static void ensureSuccess(dynamic responseBody) {
    final err = tryParseError(responseBody);
    if (err != null) throw err;
  }

  /// `success == false` ise hata; aksi halde null.
  static ApiException? tryParseError(dynamic responseBody) {
    if (responseBody is! Map) return null;
    final map = Map<String, dynamic>.from(responseBody);
    if (map['success'] != false) return null;
    final err = map['error'];
    if (err is Map) {
      final code = err['code'] as String?;
      final message = err['message'] as String? ?? 'İstek başarısız';
      return ApiException(code: code, message: message);
    }
    return ApiException(message: map['message'] as String? ?? 'İstek başarısız');
  }
}

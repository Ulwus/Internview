import 'package:dio/dio.dart';

import '../../../core/models/domain_models.dart';
import '../../../core/network/api_envelope.dart';
import '../../../core/network/api_exception.dart';

class AuthTokens {
  AuthTokens({required this.accessToken, required this.refreshToken});

  final String accessToken;
  final String refreshToken;
}

class AuthRemoteDataSource {
  AuthRemoteDataSource(this._dio);

  final Dio _dio;

  ApiException _fromDio(DioException e) {
    final code = e.response?.statusCode;
    final data = e.response?.data;
    if (data is Map) {
      final ae = ApiEnvelope.tryParseError(data);
      if (ae != null) {
        return ApiException(code: ae.code, message: ae.message, statusCode: code);
      }
    }
    return ApiException(
      message: e.message ?? 'Ağ hatası',
      statusCode: code,
    );
  }

  Future<AuthTokens> login(String email, String password) async {
    try {
      final r = await _dio.post<Map<String, dynamic>>(
        '/auth/login',
        data: {'email': email, 'password': password},
      );
      final data = ApiEnvelope.parseData<Map<String, dynamic>>(
        r.data,
        (j) => Map<String, dynamic>.from(j! as Map),
      );
      final access = data['access_token'] as String?;
      final refresh = data['refresh_token'] as String?;
      if (access == null || refresh == null) {
        throw ApiException(message: 'Giriş yanıtı eksik');
      }
      return AuthTokens(accessToken: access, refreshToken: refresh);
    } on DioException catch (e) {
      throw _fromDio(e);
    }
  }

  Future<AuthTokens> register({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    required String role,
  }) async {
    try {
      final r = await _dio.post<Map<String, dynamic>>(
        '/auth/register',
        data: {
          'email': email,
          'password': password,
          'first_name': firstName,
          'last_name': lastName,
          'role': role,
        },
      );
      final data = ApiEnvelope.parseData<Map<String, dynamic>>(
        r.data,
        (j) => Map<String, dynamic>.from(j! as Map),
      );
      final access = data['access_token'] as String?;
      final refresh = data['refresh_token'] as String?;
      if (access == null || refresh == null) {
        throw ApiException(message: 'Kayıt yanıtı eksik');
      }
      return AuthTokens(accessToken: access, refreshToken: refresh);
    } on DioException catch (e) {
      throw _fromDio(e);
    }
  }

  Future<MeData> me() async {
    try {
      final r = await _dio.get<Map<String, dynamic>>('/auth/me');
      return ApiEnvelope.parseData(
        r.data,
        (j) => MeData.fromJson(Map<String, dynamic>.from(j! as Map)),
      );
    } on DioException catch (e) {
      throw _fromDio(e);
    }
  }
}

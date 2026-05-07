import 'package:dio/dio.dart';

import '../../../core/models/domain_models.dart';
import '../../../core/network/api_envelope.dart';

class ProfileRemoteDataSource {
  ProfileRemoteDataSource(this._dio);

  final Dio _dio;

  Future<UserProfile> getProfile() async {
    final r = await _dio.get<Map<String, dynamic>>('/users/profile');
    return ApiEnvelope.parseData(
      r.data,
      (j) => UserProfile.fromJson(Map<String, dynamic>.from(j! as Map)),
    );
  }

  Future<UserProfile> getUserById(String id) async {
    final r = await _dio.get<Map<String, dynamic>>('/users/$id');
    return ApiEnvelope.parseData(
      r.data,
      (j) => UserProfile.fromJson(Map<String, dynamic>.from(j! as Map)),
    );
  }

  Future<UserProfile> updateProfile({
    required String firstName,
    required String lastName,
    String? avatarUrl,
  }) async {
    final r = await _dio.put<Map<String, dynamic>>(
      '/users/profile',
      data: {
        'firstName': firstName,
        'lastName': lastName,
        ...? (avatarUrl != null) ? {'avatarUrl': avatarUrl} : null,
      },
    );
    return ApiEnvelope.parseData(
      r.data,
      (j) => UserProfile.fromJson(Map<String, dynamic>.from(j! as Map)),
    );
  }

  Future<String> uploadAvatar({required String filePath}) async {
    final form = FormData.fromMap({
      'file': await MultipartFile.fromFile(filePath),
    });

    final r = await _dio.post<Map<String, dynamic>>(
      '/media/uploads/avatar',
      data: form,
      options: Options(contentType: 'multipart/form-data'),
    );

    final data = r.data ?? const <String, dynamic>{};
    final url = data['url'] as String?;
    if (url == null || url.isEmpty) {
      throw Exception('Avatar yükleme başarısız (url boş).');
    }
    return url;
  }
}

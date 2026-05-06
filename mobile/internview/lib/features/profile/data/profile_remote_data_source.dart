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
}

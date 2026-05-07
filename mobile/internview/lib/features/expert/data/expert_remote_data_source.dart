import 'package:dio/dio.dart';

import '../../../core/models/domain_models.dart';
import '../../../core/models/page_response.dart';
import '../../../core/network/api_envelope.dart';

class ExpertRemoteDataSource {
  ExpertRemoteDataSource(this._dio);

  final Dio _dio;

  Future<PageResponse<ExpertSummary>> searchExperts({
    String? industry,
    Set<String>? skillSlugs,
    double? minRating,
    bool? isAvailable,
    String? search,
    int page = 0,
    int size = 20,
  }) async {
    final skillList = skillSlugs?.toList() ?? const <String>[];
    final r = await _dio.get<Map<String, dynamic>>(
      '/experts',
      queryParameters: {
        'page': page,
        'size': size,
        ...? (industry != null && industry.isNotEmpty) ? {'industry': industry} : null,
        ...? (minRating != null) ? {'min_rating': minRating} : null,
        ...? (isAvailable != null) ? {'is_available': isAvailable} : null,
        ...? (search != null && search.isNotEmpty) ? {'search': search} : null,
        ...? (skillList.isNotEmpty) ? {'skill': skillList} : null,
      },
    );
    return ApiEnvelope.parseData(
      r.data,
      (j) => PageResponse.fromJson(
        Map<String, dynamic>.from(j! as Map),
        (e) => ExpertSummary.fromJson(Map<String, dynamic>.from(e as Map)),
      ),
    );
  }

  Future<ExpertDetail> getExpert(String id) async {
    final r = await _dio.get<Map<String, dynamic>>('/experts/$id');
    return ApiEnvelope.parseData(
      r.data,
      (j) => ExpertDetail.fromJson(Map<String, dynamic>.from(j! as Map)),
    );
  }

  Future<ExpertDetail> getExpertByUserId(String userId) async {
    final r = await _dio.get<Map<String, dynamic>>('/experts/by-user/$userId');
    return ApiEnvelope.parseData(
      r.data,
      (j) => ExpertDetail.fromJson(Map<String, dynamic>.from(j! as Map)),
    );
  }

  Future<ExpertDetail> getExpertMe() async {
    final r = await _dio.get<Map<String, dynamic>>('/experts/me');
    return ApiEnvelope.parseData(
      r.data,
      (j) => ExpertDetail.fromJson(Map<String, dynamic>.from(j! as Map)),
    );
  }

  Future<ExpertDetail> updateExpertMe(Map<String, dynamic> body) async {
    final r = await _dio.put<Map<String, dynamic>>('/experts/me', data: body);
    return ApiEnvelope.parseData(
      r.data,
      (j) => ExpertDetail.fromJson(Map<String, dynamic>.from(j! as Map)),
    );
  }

  Future<List<IndustryDto>> listIndustries() async {
    final r = await _dio.get<Map<String, dynamic>>('/industries');
    return ApiEnvelope.parseData(
      r.data,
      (j) => (j as List<dynamic>)
          .map((e) => IndustryDto.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
    );
  }

  Future<List<SkillDto>> listSkills() async {
    final r = await _dio.get<Map<String, dynamic>>('/skills');
    return ApiEnvelope.parseData(
      r.data,
      (j) => (j as List<dynamic>)
          .map((e) => SkillDto.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
    );
  }
}

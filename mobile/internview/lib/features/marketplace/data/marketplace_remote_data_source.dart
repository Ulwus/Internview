import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/page_response.dart';
import '../../../core/models/shop_models.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/network/api_envelope.dart';
import '../../../core/network/dio_client.dart';

final marketplaceRemoteProvider = Provider<MarketplaceRemoteDataSource>(
  (ref) => MarketplaceRemoteDataSource(ref.watch(dioProvider)),
);

class MarketplaceRemoteDataSource {
  MarketplaceRemoteDataSource(this._dio);

  final Dio _dio;

  Future<PageResponse<ShopSummaryDto>> listShops({
    int page = 0,
    int size = 20,
    String? industrySlug,
    Set<String>? skillSlugs,
    double? minRating,
    double? minPrice,
    double? maxPrice,
    bool? isAvailable,
    bool publishedOnly = true,
  }) async {
    try {
      final r = await _dio.get<Map<String, dynamic>>(
        '/shops',
        queryParameters: {
          'page': page,
          'size': size,
          ...? (industrySlug != null && industrySlug.isNotEmpty) ? {'industry': industrySlug} : null,
          ...? (skillSlugs != null && skillSlugs.isNotEmpty) ? {'skill': skillSlugs.toList()} : null,
          ...? (minRating != null) ? {'min_rating': minRating} : null,
          ...? (minPrice != null) ? {'min_price': minPrice} : null,
          ...? (maxPrice != null) ? {'max_price': maxPrice} : null,
          ...? (isAvailable != null) ? {'is_available': isAvailable} : null,
          'published_only': publishedOnly,
        },
      );
      return ApiEnvelope.parseData(
        r.data,
        (j) => PageResponse.fromJson(
          Map<String, dynamic>.from(j! as Map),
          (e) => ShopSummaryDto.fromJson(Map<String, dynamic>.from(e as Map)),
        ),
      );
    } on DioException catch (e) {
      throw _fromDio(e);
    }
  }

  Future<ShopSummaryDto> getShop(String id) async {
    try {
      final r = await _dio.get<Map<String, dynamic>>('/shops/$id');
      return ApiEnvelope.parseData(
        r.data,
        (j) => ShopSummaryDto.fromJson(Map<String, dynamic>.from(j! as Map)),
      );
    } on DioException catch (e) {
      throw _fromDio(e);
    }
  }

  Future<ShopSummaryDto?> getMyShop() async {
    try {
      final r = await _dio.get<Map<String, dynamic>>('/shops/me');
      return ApiEnvelope.parseData(
        r.data,
        (j) => j == null ? null : ShopSummaryDto.fromJson(Map<String, dynamic>.from(j as Map)),
      );
    } on DioException catch (e) {
      throw _fromDio(e);
    }
  }

  Future<ShopSummaryDto> upsertMyShop({
    required String description,
    required int yearsOfExperience,
    required double hourlyRate,
    required String currency,
    String? industrySlug,
    required Set<String> skillSlugs,
    required bool isPublished,
  }) async {
    try {
      final r = await _dio.put<Map<String, dynamic>>(
        '/shops/me',
        data: {
          'description': description,
          'yearsOfExperience': yearsOfExperience,
          'hourlyRate': hourlyRate,
          'currency': currency,
          'industrySlug': industrySlug ?? '',
          'skillSlugs': skillSlugs.toList(),
          'isPublished': isPublished,
        },
      );
      return ApiEnvelope.parseData(
        r.data,
        (j) => ShopSummaryDto.fromJson(Map<String, dynamic>.from(j! as Map)),
      );
    } on DioException catch (e) {
      throw _fromDio(e);
    }
  }

  Future<ExpertStatsDto> getExpertStats(String expertUserId) async {
    try {
      final r = await _dio.get<Map<String, dynamic>>('/experts/$expertUserId/stats');
      return ApiEnvelope.parseData(
        r.data,
        (j) => ExpertStatsDto.fromJson(Map<String, dynamic>.from(j! as Map)),
      );
    } on DioException catch (e) {
      throw _fromDio(e);
    }
  }

  Future<PageResponse<ExpertReviewDto>> getExpertReviews({
    required String expertUserId,
    int page = 0,
    int size = 20,
  }) async {
    try {
      final r = await _dio.get<Map<String, dynamic>>(
        '/experts/$expertUserId/reviews',
        queryParameters: {'page': page, 'size': size},
      );
      return ApiEnvelope.parseData(
        r.data,
        (j) => PageResponse.fromJson(
          Map<String, dynamic>.from(j! as Map),
          (e) => ExpertReviewDto.fromJson(Map<String, dynamic>.from(e as Map)),
        ),
      );
    } on DioException catch (e) {
      throw _fromDio(e);
    }
  }

  ApiException _fromDio(DioException e) {
    final code = e.response?.statusCode;
    final data = e.response?.data;
    if (data is Map) {
      final ae = ApiEnvelope.tryParseError(data);
      if (ae != null) return ApiException(code: ae.code, message: ae.message, statusCode: code);
    }
    return ApiException(message: e.message ?? 'Ağ hatası', statusCode: code);
  }
}


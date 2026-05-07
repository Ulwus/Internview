import 'domain_models.dart';

class ShopSummaryDto {
  ShopSummaryDto({
    required this.id,
    required this.expertUserId,
    required this.expertFirstName,
    required this.expertLastName,
    required this.expertAvatarUrl,
    required this.industry,
    required this.skills,
    required this.description,
    required this.yearsOfExperience,
    required this.hourlyRate,
    required this.currency,
    required this.isPublished,
    required this.averageRating,
    required this.isAvailable,
  });

  final String id;
  final String expertUserId;
  final String expertFirstName;
  final String expertLastName;
  final String? expertAvatarUrl;
  final IndustryDto? industry;
  final List<SkillDto> skills;
  final String? description;
  final int yearsOfExperience;
  final double? hourlyRate;
  final String? currency;
  final bool isPublished;
  final double? averageRating;
  final bool? isAvailable;

  String get expertFullName => '$expertFirstName $expertLastName'.trim();

  factory ShopSummaryDto.fromJson(Map<String, dynamic> j) {
    return ShopSummaryDto(
      id: j['id'].toString(),
      expertUserId: j['expertUserId'].toString(),
      expertFirstName: j['expertFirstName'] as String? ?? '',
      expertLastName: j['expertLastName'] as String? ?? '',
      expertAvatarUrl: normalizeAvatarUrl(j['expertAvatarUrl'] as String?),
      industry: j['industry'] != null ? IndustryDto.fromJson(Map<String, dynamic>.from(j['industry'] as Map)) : null,
      skills: (j['skills'] as List<dynamic>?)
              ?.map((e) => SkillDto.fromJson(Map<String, dynamic>.from(e as Map)))
              .toList() ??
          const [],
      description: j['description'] as String?,
      yearsOfExperience: (j['yearsOfExperience'] as num?)?.toInt() ?? 0,
      hourlyRate: (j['hourlyRate'] as num?)?.toDouble(),
      currency: j['currency'] as String?,
      isPublished: j['isPublished'] as bool? ?? false,
      averageRating: (j['averageRating'] as num?)?.toDouble(),
      isAvailable: j['isAvailable'] as bool?,
    );
  }
}

class ExpertStatsDto {
  ExpertStatsDto({
    required this.expertUserId,
    required this.averageRating,
    required this.totalRated,
    required this.completedCount,
    required this.cancelledCount,
  });

  final String expertUserId;
  final double? averageRating;
  final int totalRated;
  final int completedCount;
  final int cancelledCount;

  factory ExpertStatsDto.fromJson(Map<String, dynamic> j) {
    return ExpertStatsDto(
      expertUserId: j['expertUserId'].toString(),
      averageRating: (j['averageRating'] as num?)?.toDouble(),
      totalRated: (j['totalRated'] as num?)?.toInt() ?? 0,
      completedCount: (j['completedCount'] as num?)?.toInt() ?? 0,
      cancelledCount: (j['cancelledCount'] as num?)?.toInt() ?? 0,
    );
  }
}

class ExpertReviewDto {
  ExpertReviewDto({
    required this.bookingId,
    required this.rating,
    required this.comment,
    required this.scheduledEnd,
  });

  final String bookingId;
  final int? rating;
  final String? comment;
  final DateTime? scheduledEnd;

  factory ExpertReviewDto.fromJson(Map<String, dynamic> j) {
    return ExpertReviewDto(
      bookingId: j['bookingId'].toString(),
      rating: (j['rating'] as num?)?.toInt(),
      comment: j['comment'] as String?,
      scheduledEnd: j['scheduledEnd'] != null ? DateTime.tryParse(j['scheduledEnd'].toString()) : null,
    );
  }
}


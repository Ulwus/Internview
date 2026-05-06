import 'dart:convert';

/// JWT `sub` (UUID string).
String? decodeJwtSub(String token) {
  try {
    final parts = token.split('.');
    if (parts.length != 3) return null;
    final payload = utf8.decode(base64Url.decode(base64Url.normalize(parts[1])));
    final m = jsonDecode(payload) as Map<String, dynamic>;
    return m['sub'] as String?;
  } catch (_) {
    return null;
  }
}

/// JWT `role` claim (CANDIDATE / EXPERT / ADMIN).
String? decodeJwtRole(String token) {
  try {
    final parts = token.split('.');
    if (parts.length != 3) return null;
    final payload = utf8.decode(base64Url.decode(base64Url.normalize(parts[1])));
    final m = jsonDecode(payload) as Map<String, dynamic>;
    return m['role'] as String?;
  } catch (_) {
    return null;
  }
}

class MeData {
  MeData({
    required this.userId,
    required this.email,
    required this.firstName,
    required this.lastName,
    required this.roles,
  });

  final String userId;
  final String email;
  final String firstName;
  final String lastName;
  final List<String> roles;

  String get primaryRole => roles.isNotEmpty ? roles.first : 'CANDIDATE';

  factory MeData.fromJson(Map<String, dynamic> j) {
    return MeData(
      userId: (j['user_id'] ?? j['userId']).toString(),
      email: j['email'] as String? ?? '',
      firstName: j['first_name'] as String? ?? j['firstName'] as String? ?? '',
      lastName: j['last_name'] as String? ?? j['lastName'] as String? ?? '',
      roles: (j['roles'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? const [],
    );
  }
}

class UserProfile {
  UserProfile({
    required this.id,
    required this.email,
    required this.firstName,
    required this.lastName,
    this.avatarUrl,
    required this.role,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String email;
  final String firstName;
  final String lastName;
  final String? avatarUrl;
  final String role;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory UserProfile.fromJson(Map<String, dynamic> j) {
    return UserProfile(
      id: j['id'].toString(),
      email: j['email'] as String? ?? '',
      firstName: j['firstName'] as String? ?? '',
      lastName: j['lastName'] as String? ?? '',
      avatarUrl: j['avatarUrl'] as String?,
      role: j['role']?.toString() ?? 'CANDIDATE',
      createdAt: _parseInstant(j['createdAt']),
      updatedAt: _parseInstant(j['updatedAt']),
    );
  }
}

class IndustryDto {
  IndustryDto({required this.id, required this.name, required this.slug});

  final String id;
  final String name;
  final String slug;

  factory IndustryDto.fromJson(Map<String, dynamic> j) => IndustryDto(
        id: j['id'].toString(),
        name: j['name'] as String? ?? '',
        slug: j['slug'] as String? ?? '',
      );
}

class SkillDto {
  SkillDto({required this.id, required this.name, required this.slug});

  final String id;
  final String name;
  final String slug;

  factory SkillDto.fromJson(Map<String, dynamic> j) => SkillDto(
        id: j['id'].toString(),
        name: j['name'] as String? ?? '',
        slug: j['slug'] as String? ?? '',
      );
}

class ExpertSummary {
  ExpertSummary({
    required this.id,
    required this.userId,
    required this.firstName,
    required this.lastName,
    this.avatarUrl,
    this.headline,
    this.company,
    this.industry,
    required this.skills,
    this.yearsOfExperience,
    this.hourlyRate,
    this.currency,
    this.averageRating,
    this.totalSessions,
    this.isVerified,
    this.isAvailable,
  });

  final String id;
  final String userId;
  final String firstName;
  final String lastName;
  final String? avatarUrl;
  final String? headline;
  final String? company;
  final IndustryDto? industry;
  final List<SkillDto> skills;
  final int? yearsOfExperience;
  final double? hourlyRate;
  final String? currency;
  final double? averageRating;
  final int? totalSessions;
  final bool? isVerified;
  final bool? isAvailable;

  factory ExpertSummary.fromJson(Map<String, dynamic> j) {
    return ExpertSummary(
      id: j['id'].toString(),
      userId: j['userId'].toString(),
      firstName: j['firstName'] as String? ?? '',
      lastName: j['lastName'] as String? ?? '',
      avatarUrl: j['avatarUrl'] as String?,
      headline: j['headline'] as String?,
      company: j['company'] as String?,
      industry: j['industry'] != null
          ? IndustryDto.fromJson(Map<String, dynamic>.from(j['industry'] as Map))
          : null,
      skills: (j['skills'] as List<dynamic>?)
              ?.map((e) => SkillDto.fromJson(Map<String, dynamic>.from(e as Map)))
              .toList() ??
          const [],
      yearsOfExperience: (j['yearsOfExperience'] as num?)?.toInt(),
      hourlyRate: (j['hourlyRate'] as num?)?.toDouble(),
      currency: j['currency'] as String?,
      averageRating: (j['averageRating'] as num?)?.toDouble(),
      totalSessions: (j['totalSessions'] as num?)?.toInt(),
      isVerified: j['isVerified'] as bool?,
      isAvailable: j['isAvailable'] as bool?,
    );
  }
}

class ExpertDetail {
  ExpertDetail({
    required this.id,
    required this.userId,
    this.email,
    required this.firstName,
    required this.lastName,
    this.avatarUrl,
    this.headline,
    this.bio,
    this.company,
    this.industry,
    required this.skills,
    this.yearsOfExperience,
    this.hourlyRate,
    this.currency,
    this.averageRating,
    this.totalSessions,
    this.isVerified,
    this.isAvailable,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String userId;
  final String? email;
  final String firstName;
  final String lastName;
  final String? avatarUrl;
  final String? headline;
  final String? bio;
  final String? company;
  final IndustryDto? industry;
  final List<SkillDto> skills;
  final int? yearsOfExperience;
  final double? hourlyRate;
  final String? currency;
  final double? averageRating;
  final int? totalSessions;
  final bool? isVerified;
  final bool? isAvailable;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory ExpertDetail.fromJson(Map<String, dynamic> j) {
    return ExpertDetail(
      id: j['id'].toString(),
      userId: j['userId'].toString(),
      email: j['email'] as String?,
      firstName: j['firstName'] as String? ?? '',
      lastName: j['lastName'] as String? ?? '',
      avatarUrl: j['avatarUrl'] as String?,
      headline: j['headline'] as String?,
      bio: j['bio'] as String?,
      company: j['company'] as String?,
      industry: j['industry'] != null
          ? IndustryDto.fromJson(Map<String, dynamic>.from(j['industry'] as Map))
          : null,
      skills: (j['skills'] as List<dynamic>?)
              ?.map((e) => SkillDto.fromJson(Map<String, dynamic>.from(e as Map)))
              .toList() ??
          const [],
      yearsOfExperience: (j['yearsOfExperience'] as num?)?.toInt(),
      hourlyRate: (j['hourlyRate'] as num?)?.toDouble(),
      currency: j['currency'] as String?,
      averageRating: (j['averageRating'] as num?)?.toDouble(),
      totalSessions: (j['totalSessions'] as num?)?.toInt(),
      isVerified: j['isVerified'] as bool?,
      isAvailable: j['isAvailable'] as bool?,
      createdAt: _parseInstant(j['createdAt']),
      updatedAt: _parseInstant(j['updatedAt']),
    );
  }
}

DateTime? _parseInstant(dynamic v) {
  if (v == null) return null;
  if (v is String) return DateTime.tryParse(v);
  return null;
}

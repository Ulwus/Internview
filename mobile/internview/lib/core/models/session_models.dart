class IceServerDto {
  IceServerDto({required this.urls, this.username, this.credential});

  final List<String> urls;
  final String? username;
  final String? credential;

  factory IceServerDto.fromJson(Map<String, dynamic> j) {
    final u = j['urls'];
    List<String> list;
    if (u is List) {
      list = u.map((e) => e.toString()).toList();
    } else if (u is String) {
      list = [u];
    } else {
      list = const [];
    }
    return IceServerDto(
      urls: list,
      username: j['username'] as String?,
      credential: j['credential'] as String?,
    );
  }
}

class SessionSummary {
  SessionSummary({
    required this.sessionId,
    required this.bookingId,
    required this.candidateId,
    required this.expertId,
    required this.status,
    required this.signalingWebSocketUrl,
    required this.iceServers,
  });

  final String sessionId;
  final String bookingId;
  final String candidateId;
  final String expertId;
  final String status;
  final String signalingWebSocketUrl;
  final List<IceServerDto> iceServers;

  factory SessionSummary.fromJson(Map<String, dynamic> j) {
    return SessionSummary(
      sessionId: j['sessionId'].toString(),
      bookingId: j['bookingId'].toString(),
      candidateId: j['candidateId'].toString(),
      expertId: j['expertId'].toString(),
      status: j['status'] as String? ?? '',
      signalingWebSocketUrl: j['signalingWebSocketUrl'] as String? ?? '',
      iceServers:
          (j['iceServers'] as List<dynamic>?)
              ?.map(
                (e) =>
                    IceServerDto.fromJson(Map<String, dynamic>.from(e as Map)),
              )
              .toList() ??
          const [],
    );
  }
}

class AnalysisReport {
  AnalysisReport({
    required this.sessionId,
    required this.transcript,
    required this.analysis,
  });

  final String sessionId;
  final String transcript;
  final Map<String, dynamic> analysis;

  AiEvaluation? get aiEvaluation {
    final raw = analysis['aiEvaluation'] ?? analysis['ai_evaluation'];
    if (raw is Map) {
      return AiEvaluation.fromJson(Map<String, dynamic>.from(raw));
    }
    return null;
  }

  factory AnalysisReport.fromJson(Map<String, dynamic> j) {
    return AnalysisReport(
      sessionId: j['sessionId'].toString(),
      transcript: j['transcript']?.toString() ?? '',
      analysis: Map<String, dynamic>.from((j['analysis'] as Map?) ?? const {}),
    );
  }
}

class AiEvaluation {
  AiEvaluation({
    required this.score,
    required this.reason,
    required this.strengths,
    required this.improvements,
    this.model,
    this.source,
  });

  final double? score;
  final String reason;
  final List<String> strengths;
  final List<String> improvements;
  final String? model;
  final String? source;

  factory AiEvaluation.fromJson(Map<String, dynamic> j) {
    return AiEvaluation(
      score: (j['score'] as num?)?.toDouble(),
      reason: j['reason']?.toString() ?? '',
      strengths: _stringList(j['strengths']),
      improvements: _stringList(j['improvements']),
      model: j['model']?.toString(),
      source: j['source']?.toString(),
    );
  }

  static List<String> _stringList(Object? value) {
    if (value is! List) return const [];
    return value
        .map((e) => e.toString())
        .where((e) => e.trim().isNotEmpty)
        .toList();
  }
}

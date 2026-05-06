class IceServerDto {
  IceServerDto({
    required this.urls,
    this.username,
    this.credential,
  });

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
      iceServers: (j['iceServers'] as List<dynamic>?)
              ?.map((e) => IceServerDto.fromJson(Map<String, dynamic>.from(e as Map)))
              .toList() ??
          const [],
    );
  }
}

class MediaTransportInfo {
  MediaTransportInfo({
    required this.id,
    required this.iceParameters,
    required this.iceCandidates,
    required this.dtlsParameters,
  });

  final String id;
  final Map<String, dynamic> iceParameters;
  final List<dynamic> iceCandidates;
  final Map<String, dynamic> dtlsParameters;

  factory MediaTransportInfo.fromJson(Map<String, dynamic> json) {
    return MediaTransportInfo(
      id: json['id'].toString(),
      iceParameters: Map<String, dynamic>.from(json['iceParameters'] as Map),
      iceCandidates: json['iceCandidates'] as List<dynamic>? ?? const [],
      dtlsParameters: Map<String, dynamic>.from(json['dtlsParameters'] as Map),
    );
  }

  Map<String, dynamic> toMediasoupMap() => {
    'id': id,
    'iceParameters': iceParameters,
    'iceCandidates': iceCandidates,
    'dtlsParameters': dtlsParameters,
  };
}

class MediaProducerSummary {
  MediaProducerSummary({required this.id, required this.kind});

  final String id;
  final String kind;

  factory MediaProducerSummary.fromJson(Map<String, dynamic> json) {
    return MediaProducerSummary(
      id: json['id'].toString(),
      kind: json['kind'] as String? ?? '',
    );
  }
}

class MediaConsumeInfo {
  MediaConsumeInfo({
    required this.id,
    required this.producerId,
    required this.kind,
    required this.rtpParameters,
  });

  final String id;
  final String producerId;
  final String kind;
  final Map<String, dynamic> rtpParameters;

  factory MediaConsumeInfo.fromJson(Map<String, dynamic> json) {
    return MediaConsumeInfo(
      id: json['id'].toString(),
      producerId: json['producerId'].toString(),
      kind: json['kind'] as String? ?? '',
      rtpParameters: Map<String, dynamic>.from(json['rtpParameters'] as Map),
    );
  }
}

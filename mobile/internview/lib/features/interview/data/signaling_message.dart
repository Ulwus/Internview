sealed class SignalingMessage {
  const SignalingMessage();

  factory SignalingMessage.fromJson(Map<String, dynamic> j) {
    final type = j['type'] as String?;
    switch (type) {
      case 'OFFER':
        return OfferMessage(
          targetUserId: _uuid(j['targetUserId']),
          fromUserId: _uuid(j['fromUserId']),
          sdp: j['sdp'] as String? ?? '',
        );
      case 'ANSWER':
        return AnswerMessage(
          targetUserId: _uuid(j['targetUserId']),
          fromUserId: _uuid(j['fromUserId']),
          sdp: j['sdp'] as String? ?? '',
        );
      case 'ICE_CANDIDATE':
        return IceCandidateMessage(
          targetUserId: _uuid(j['targetUserId']),
          fromUserId: _uuid(j['fromUserId']),
          candidate: j['candidate'] as String? ?? '',
          sdpMid: j['sdpMid'] as String?,
          sdpMLineIndex: (j['sdpMLineIndex'] as num?)?.toInt(),
        );
      case 'LEAVE_ROOM':
        return const LeaveRoomMessage();
      case 'ROOM_JOINED':
        final peersRaw = j['peers'] as List<dynamic>? ?? const [];
        final peers = peersRaw
            .map((e) => RoomPeerInfo.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
        return RoomJoinedMessage(peers: peers);
      case 'PEER_JOINED':
        return PeerJoinedMessage(
          userId: j['userId'].toString(),
          role: j['role'] as String? ?? '',
        );
      case 'PEER_LEFT':
        return PeerLeftMessage(userId: j['userId'].toString());
      case 'ERROR':
        return ErrorMessage(
          code: j['code'] as String? ?? 'ERROR',
          message: j['message'] as String? ?? '',
        );
      default:
        return ErrorMessage(code: 'UNKNOWN', message: 'Bilinmeyen sinyal: $type');
    }
  }

  static String? _uuid(dynamic v) => v?.toString();
}

class OfferMessage extends SignalingMessage {
  OfferMessage({this.targetUserId, this.fromUserId, required this.sdp});

  final String? targetUserId;
  final String? fromUserId;
  final String sdp;
}

class AnswerMessage extends SignalingMessage {
  AnswerMessage({this.targetUserId, this.fromUserId, required this.sdp});

  final String? targetUserId;
  final String? fromUserId;
  final String sdp;
}

class IceCandidateMessage extends SignalingMessage {
  IceCandidateMessage({
    this.targetUserId,
    this.fromUserId,
    required this.candidate,
    this.sdpMid,
    this.sdpMLineIndex,
  });

  final String? targetUserId;
  final String? fromUserId;
  final String candidate;
  final String? sdpMid;
  final int? sdpMLineIndex;
}

class LeaveRoomMessage extends SignalingMessage {
  const LeaveRoomMessage();
}

class RoomPeerInfo {
  RoomPeerInfo({required this.userId, required this.role});

  final String userId;
  final String role;

  factory RoomPeerInfo.fromJson(Map<String, dynamic> j) => RoomPeerInfo(
        userId: j['userId'].toString(),
        role: j['role'] as String? ?? '',
      );
}

class RoomJoinedMessage extends SignalingMessage {
  RoomJoinedMessage({required this.peers});

  final List<RoomPeerInfo> peers;
}

class PeerJoinedMessage extends SignalingMessage {
  PeerJoinedMessage({required this.userId, required this.role});

  final String userId;
  final String role;
}

class PeerLeftMessage extends SignalingMessage {
  PeerLeftMessage({required this.userId});

  final String userId;
}

class ErrorMessage extends SignalingMessage {
  ErrorMessage({required this.code, required this.message});

  final String code;
  final String message;
}

Map<String, dynamic> offerOut({required String targetUserId, required String sdp}) => {
      'type': 'OFFER',
      'targetUserId': targetUserId,
      'sdp': sdp,
    };

Map<String, dynamic> answerOut({required String targetUserId, required String sdp}) => {
      'type': 'ANSWER',
      'targetUserId': targetUserId,
      'sdp': sdp,
    };

Map<String, dynamic> iceOut({
  required String targetUserId,
  required String candidate,
  String? sdpMid,
  int? sdpMLineIndex,
}) =>
    {
      'type': 'ICE_CANDIDATE',
      'targetUserId': targetUserId,
      'candidate': candidate,
      'sdpMid': sdpMid,
      'sdpMLineIndex': sdpMLineIndex,
    };

const Map<String, dynamic> leaveRoomOut = {'type': 'LEAVE_ROOM'};

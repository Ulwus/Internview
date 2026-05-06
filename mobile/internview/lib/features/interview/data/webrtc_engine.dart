import 'dart:async';

import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../../../core/models/session_models.dart';

typedef IceCandidateHandler = void Function(RTCIceCandidate candidate);

/// Plain WebRTC P2P: tek video track, ICE sunucuları session özetinden.
class WebRtcEngine {
  RTCPeerConnection? _pc;
  MediaStream? _local;
  final _remoteCtrl = StreamController<MediaStream>.broadcast();

  Stream<MediaStream> get remoteStreams => _remoteCtrl.stream;

  MediaStream? get localStream => _local;

  /// [flutter_webrtc] paketindeki üst düzey [createPeerConnection] ile PC oluşturur.
  Future<void> setupPeerConnection(List<IceServerDto> iceServers) async {
    await dispose();
    final config = <String, dynamic>{
      'iceServers': iceServers
          .map(
            (e) => {
              'urls': e.urls.length == 1 ? e.urls.first : e.urls,
              if (e.username != null) 'username': e.username,
              if (e.credential != null) 'credential': e.credential,
            },
          )
          .toList(),
    };
    _pc = await createPeerConnection(config, {});
    _pc!.onTrack = (ev) {
      if (ev.streams.isNotEmpty) {
        _remoteCtrl.add(ev.streams.first);
      }
    };
  }

  Future<void> getUserMedia() async {
    _local = await navigator.mediaDevices.getUserMedia({'audio': true, 'video': true});
    for (final t in _local!.getTracks()) {
      await _pc?.addTrack(t, _local!);
    }
  }

  void onIceCandidate(IceCandidateHandler handler) {
    _pc?.onIceCandidate = (c) {
      if (c.candidate != null) {
        handler(c);
      }
    };
  }

  Future<RTCSessionDescription> createOffer() async {
    final offer = await _pc!.createOffer();
    await _pc!.setLocalDescription(offer);
    return offer;
  }

  Future<void> setRemoteDescription(RTCSessionDescription desc) async {
    await _pc!.setRemoteDescription(desc);
  }

  Future<RTCSessionDescription> createAnswer(RTCSessionDescription offer) async {
    await _pc!.setRemoteDescription(offer);
    final answer = await _pc!.createAnswer({});
    await _pc!.setLocalDescription(answer);
    return answer;
  }

  /// Karşı tarafın offer SDP'si ile answer üretir.
  Future<RTCSessionDescription> applyRemoteOfferCreateAnswer(RTCSessionDescription offer) async {
    return createAnswer(offer);
  }

  Future<void> addIceCandidate(RTCIceCandidate candidate) async {
    await _pc?.addCandidate(candidate);
  }

  Future<void> dispose() async {
    for (final t in _local?.getTracks() ?? const []) {
      await t.stop();
    }
    await _local?.dispose();
    _local = null;
    await _pc?.close();
    _pc = null;
  }

  Future<void> closeRemote() async {
    await _remoteCtrl.close();
  }
}

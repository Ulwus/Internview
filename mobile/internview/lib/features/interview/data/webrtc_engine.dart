import 'dart:async';
import 'dart:io';

import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../../../core/models/session_models.dart';
import '../../../core/network/local_host.dart';

String _rewriteIceUrlForAndroid(String url) {
  if (!Platform.isAndroid) return url;

  // 1) ws/http gibi URL'ler
  final httpLike = replaceLocalhostForAndroid(url);
  if (httpLike != url) return httpLike;

  // 2) ICE URL'leri genelde "stun:host:3478" / "turn:host:3478?transport=udp"
  // Android emülatörde "localhost/127.0.0.1/coturn" cihaz içinde çözümlenemez.
  // Dev ortamında host makineyi işaret etmek için 10.0.2.2 kullan.
  const host = '10.0.2.2';

  String rewriteFor(String scheme) {
    if (!url.startsWith('$scheme:')) return url;
    final rest = url.substring(scheme.length + 1); // after "scheme:"
    // rest = "host:port?..." veya "host?..." olabilir
    final idx = rest.indexOf(':');
    final qIdx = rest.indexOf('?');
    final hostEnd = (() {
      if (idx == -1) return qIdx == -1 ? rest.length : qIdx;
      if (qIdx == -1) return idx;
      return idx < qIdx ? idx : qIdx;
    })();
    final currentHost = rest.substring(0, hostEnd);

    if (currentHost == 'localhost' || currentHost == '127.0.0.1' || currentHost == 'coturn') {
      return '$scheme:$host${rest.substring(hostEnd)}';
    }
    return url;
  }

  final rewrittenStun = rewriteFor('stun');
  if (rewrittenStun != url) return rewrittenStun;
  final rewrittenTurn = rewriteFor('turn');
  if (rewrittenTurn != url) return rewrittenTurn;
  return url;
}

typedef IceCandidateHandler = void Function(RTCIceCandidate candidate);

/// Plain WebRTC P2P: tek video track, ICE sunucuları session özetinden.
class WebRtcEngine {
  RTCPeerConnection? _pc;
  MediaStream? _local;
  final _remoteCtrl = StreamController<MediaStream>.broadcast();

  Stream<MediaStream> get remoteStreams => _remoteCtrl.stream;

  MediaStream? get localStream => _local;
  RTCPeerConnection? get peerConnection => _pc;

  RTCSignalingState? get signalingState => _pc?.signalingState;

  /// [flutter_webrtc] paketindeki üst düzey [createPeerConnection] ile PC oluşturur.
  Future<void> setupPeerConnection(List<IceServerDto> iceServers) async {
    await dispose();

    // Android emulator'de "localhost" cihazın kendisi demek.
    // TURN/STUN URL'leri backend'den localhost ile geliyorsa host'a (10.0.2.2) çevir.
    final rewrittenIceServers = iceServers
        .map(
          (s) => IceServerDto(
            urls: s.urls.map(_rewriteIceUrlForAndroid).toList(),
            username: s.username,
            credential: s.credential,
          ),
        )
        .toList();

    final config = <String, dynamic>{
      'iceServers': rewrittenIceServers
          .map(
            (e) => {
              'urls': e.urls.length == 1 ? e.urls.first : e.urls,
              if (e.username != null) 'username': e.username,
              if (e.credential != null) 'credential': e.credential,
            },
          )
          .toList(),
      'sdpSemantics': 'unified-plan',
    };
    _pc = await createPeerConnection(config, {
      'optional': [{'DtlsSrtpKeyAgreement': true}]
    });

    _pc!.onAddStream = (stream) {
      _remoteCtrl.add(stream);
    };

    _pc!.onAddTrack = (stream, track) {
      _remoteCtrl.add(stream);
    };

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

  /// Gönderilen video track'ini (kamera / ekran) runtime'da değiştirir.
  /// unified-plan'da sender.replaceTrack ile yapılır.
  Future<void> replaceVideoTrack(MediaStreamTrack newVideoTrack) async {
    final pc = _pc;
    if (pc == null) return;

    final senders = await pc.getSenders();
    final videoSender = senders.where((s) => s.track?.kind == 'video').toList();
    if (videoSender.isNotEmpty) {
      await videoSender.first.replaceTrack(newVideoTrack);
    } else {
      // Bazı platformlarda sender listesi boş gelebiliyor; fallback olarak addTrack.
      final stream = _local;
      if (stream != null) {
        await pc.addTrack(newVideoTrack, stream);
      }
    }
  }

  void onIceCandidate(IceCandidateHandler handler) {
    _pc?.onIceCandidate = (c) {
      if (c.candidate != null) {
        handler(c);
      }
    };
  }

  bool _isRemoteSet = false;
  final List<RTCIceCandidate> _queuedCandidates = [];

  Future<RTCSessionDescription> createOffer() async {
    final offer = await _pc!.createOffer();
    await _pc!.setLocalDescription(offer);
    return offer;
  }

  Future<void> setRemoteDescription(RTCSessionDescription desc) async {
    await _pc!.setRemoteDescription(desc);
    _isRemoteSet = true;
    for (final c in _queuedCandidates) {
      await _pc!.addCandidate(c);
    }
    _queuedCandidates.clear();
  }

  Future<RTCSessionDescription> createAnswer(RTCSessionDescription offer) async {
    await setRemoteDescription(offer);
    final answer = await _pc!.createAnswer({});
    await _pc!.setLocalDescription(answer);
    return answer;
  }

  /// Karşı tarafın offer SDP'si ile answer üretir.
  Future<RTCSessionDescription> applyRemoteOfferCreateAnswer(RTCSessionDescription offer) async {
    return createAnswer(offer);
  }

  Future<void> addIceCandidate(RTCIceCandidate candidate) async {
    if (!_isRemoteSet) {
      _queuedCandidates.add(candidate);
    } else {
      await _pc?.addCandidate(candidate);
    }
  }

  Future<void> dispose() async {
    _queuedCandidates.clear();
    _isRemoteSet = false;
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

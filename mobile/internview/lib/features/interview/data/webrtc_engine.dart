import 'dart:async';
import 'dart:developer' as developer;

import 'package:mediasfu_mediasoup_client/mediasfu_mediasoup_client.dart';

import '../../../core/models/session_models.dart';
import 'session_remote_data_source.dart';

typedef IceCandidateHandler = void Function(RTCIceCandidate candidate);

/// Mediasoup SFU engine.
///
/// Eski P2P SignalingMessage offer/answer/ICE yüzeyi UI'da hâlâ durduğu için
/// uyumluluk metodları no-op olarak korunur. Medya artık direkt peer'a değil,
/// Interview Service'in /media proxy endpoint'leri üzerinden Mediasoup'a gider.
class WebRtcEngine {
  WebRtcEngine();

  Device? _device;
  Transport? _sendTransport;
  Transport? _recvTransport;
  MediaStream? _local;
  MediaStream? _remote;
  SessionRemoteDataSource? _remoteDataSource;
  String? _sessionId;

  final Set<String> _localProducerIds = {};
  final Set<String> _consumedProducerIds = {};
  final List<Producer> _producers = [];
  final List<Consumer> _consumers = [];
  final _remoteCtrl = StreamController<MediaStream>.broadcast();

  Stream<MediaStream> get remoteStreams => _remoteCtrl.stream;

  MediaStream? get localStream => _local;

  /// P2P döneminden kalan UI guard'ı için hep stable döner.
  RTCSignalingState? get signalingState =>
      RTCSignalingState.RTCSignalingStateStable;

  Future<void> setupMediasoup({
    required String sessionId,
    required SessionRemoteDataSource remoteDataSource,
  }) async {
    await dispose();
    _sessionId = sessionId;
    _remoteDataSource = remoteDataSource;

    final routerCapabilities = await remoteDataSource.getMediaCapabilities(
      sessionId,
    );
    final device = Device();
    await device.load(
      routerRtpCapabilities: RtpCapabilities.fromMap(routerCapabilities),
    );
    _device = device;

    await _createSendTransport();
    await _createRecvTransport();
  }

  /// Geriye uyumluluk: P2P setup artık kullanılmıyor.
  Future<void> setupPeerConnection(List<IceServerDto> _) async {}

  Future<void> getUserMedia() async {
    final sendTransport = _sendTransport;
    if (sendTransport == null) {
      throw StateError('Mediasoup send transport hazır değil.');
    }

    _local = await navigator.mediaDevices.getUserMedia({
      'audio': true,
      'video': true,
    });

    for (final track in _local!.getAudioTracks()) {
      sendTransport.produce(
        track: track,
        stream: _local!,
        source: 'microphone',
        stopTracks: false,
      );
    }
    for (final track in _local!.getVideoTracks()) {
      sendTransport.produce(
        track: track,
        stream: _local!,
        source: 'camera',
        stopTracks: false,
      );
    }
  }

  Future<void> _createSendTransport() async {
    final sessionId = _requireSessionId();
    final api = _requireApi();
    final transportInfo = await api.createMediaTransport(sessionId);

    _sendTransport = _device!.createSendTransportFromMap(
      transportInfo.toMediasoupMap(),
      producerCallback: (Producer producer) {
        _producers.add(producer);
        _localProducerIds.add(producer.id);
        developer.log(
          'Producer ready: ${producer.id} (${producer.kind})',
          name: 'WebRtcEngine',
        );
      },
    );

    _sendTransport!.on('connect', (Map data) {
      api
          .connectMediaTransport(
            sessionId: sessionId,
            transportId: _sendTransport!.id,
            dtlsParameters: Map<String, dynamic>.from(
              data['dtlsParameters'].toMap(),
            ),
          )
          .then((_) => data['callback']())
          .catchError((error) => data['errback'](error));
    });

    _sendTransport!.on('produce', (Map data) async {
      try {
        final producerId = await api.produceMedia(
          sessionId: sessionId,
          transportId: _sendTransport!.id,
          kind: data['kind'].toString(),
          rtpParameters: Map<String, dynamic>.from(
            data['rtpParameters'].toMap(),
          ),
        );
        data['callback'](producerId);
      } catch (error) {
        data['errback'](error);
      }
    });
  }

  Future<void> _createRecvTransport() async {
    final sessionId = _requireSessionId();
    final api = _requireApi();
    final transportInfo = await api.createMediaTransport(sessionId);

    _recvTransport = _device!.createRecvTransportFromMap(
      transportInfo.toMediasoupMap(),
      consumerCallback: (Consumer consumer, dynamic accept) async {
        _consumers.add(consumer);
        await _attachRemoteTrack(consumer.track);
        if (accept is Function) accept();
        await api.resumeConsumer(sessionId: sessionId, consumerId: consumer.id);
      },
    );

    _recvTransport!.on('connect', (Map data) {
      api
          .connectMediaTransport(
            sessionId: sessionId,
            transportId: _recvTransport!.id,
            dtlsParameters: Map<String, dynamic>.from(
              data['dtlsParameters'].toMap(),
            ),
          )
          .then((_) => data['callback']())
          .catchError((error) => data['errback'](error));
    });
  }

  Future<void> syncRemoteProducers() async {
    final sessionId = _requireSessionId();
    final api = _requireApi();
    final recvTransport = _recvTransport;
    final device = _device;
    if (recvTransport == null || device == null) return;

    final producers = await api.listMediaProducers(sessionId);
    for (final producer in producers) {
      if (_localProducerIds.contains(producer.id) ||
          _consumedProducerIds.contains(producer.id)) {
        continue;
      }
      if (producer.kind != 'audio' && producer.kind != 'video') {
        continue;
      }

      final consumeInfo = await api.consumeMedia(
        sessionId: sessionId,
        transportId: recvTransport.id,
        producerId: producer.id,
        rtpCapabilities: device.rtpCapabilities.toMap(),
      );
      _consumedProducerIds.add(producer.id);
      recvTransport.consume(
        id: consumeInfo.id,
        producerId: consumeInfo.producerId,
        peerId: consumeInfo.producerId,
        kind: RTCRtpMediaTypeExtension.fromString(consumeInfo.kind),
        rtpParameters: RtpParameters.fromMap(consumeInfo.rtpParameters),
      );
    }
  }

  Future<void> _attachRemoteTrack(MediaStreamTrack track) async {
    final remote = _remote ??= await createLocalMediaStream(
      'remote-${DateTime.now().microsecondsSinceEpoch}',
    );
    final trackId = track.id;
    if (trackId == null || remote.getTrackById(trackId) == null) {
      await remote.addTrack(track);
    }
    if (!_remoteCtrl.isClosed) {
      _remoteCtrl.add(remote);
    }
  }

  Future<void> replaceVideoTrack(MediaStreamTrack newVideoTrack) async {
    for (final producer in _producers) {
      if (producer.kind == 'video' && !producer.closed) {
        await producer.replaceTrack(newVideoTrack);
        return;
      }
    }
  }

  void onIceCandidate(IceCandidateHandler _) {}

  Future<RTCSessionDescription> createOffer() async {
    return RTCSessionDescription('', 'offer');
  }

  Future<void> setRemoteDescription(RTCSessionDescription _) async {}

  Future<RTCSessionDescription> createAnswer(RTCSessionDescription _) async {
    return RTCSessionDescription('', 'answer');
  }

  Future<RTCSessionDescription> applyRemoteOfferCreateAnswer(
    RTCSessionDescription offer,
  ) {
    return createAnswer(offer);
  }

  Future<void> addIceCandidate(RTCIceCandidate _) async {}

  Future<void> dispose() async {
    for (final consumer in _consumers) {
      await consumer.close();
    }
    _consumers.clear();
    for (final producer in _producers) {
      producer.close();
    }
    _producers.clear();
    _localProducerIds.clear();
    _consumedProducerIds.clear();
    await _sendTransport?.close();
    await _recvTransport?.close();
    _sendTransport = null;
    _recvTransport = null;
    for (final track in _local?.getTracks() ?? const <MediaStreamTrack>[]) {
      await track.stop();
    }
    await _local?.dispose();
    _local = null;
    await _remote?.dispose();
    _remote = null;
  }

  Future<void> closeRemote() async {
    await _remoteCtrl.close();
  }

  String _requireSessionId() {
    final sessionId = _sessionId;
    if (sessionId == null) throw StateError('Session hazır değil.');
    return sessionId;
  }

  SessionRemoteDataSource _requireApi() {
    final api = _remoteDataSource;
    if (api == null) throw StateError('Media API hazır değil.');
    return api;
  }
}

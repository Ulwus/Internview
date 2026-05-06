import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../core/network/local_host.dart';
import '../../auth/controllers/auth_controller.dart';
import '../data/session_remote_data_source.dart';
import '../data/signaling_client.dart';
import '../data/signaling_message.dart';
import '../data/webrtc_engine.dart';

enum RoomConnState { connecting, connected, disconnected }

class InterviewRoomScreen extends ConsumerStatefulWidget {
  const InterviewRoomScreen({super.key, required this.bookingId});

  final String bookingId;

  @override
  ConsumerState<InterviewRoomScreen> createState() => _InterviewRoomScreenState();
}

class _InterviewRoomScreenState extends ConsumerState<InterviewRoomScreen> {
  RoomConnState _conn = RoomConnState.connecting;
  SignalingClient? _sig;
  WebRtcEngine? _rtc;
  final _localRenderer = RTCVideoRenderer();
  final _remoteRenderer = RTCVideoRenderer();
  StreamSubscription<SignalingMessage>? _sub;
  String? _remoteUserId;
  bool _waitingPeer = false;
  bool _offerSent = false;
  DateTime? _joinedAt;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    await _localRenderer.initialize();
    await _remoteRenderer.initialize();
    final cam = await Permission.camera.request();
    final mic = await Permission.microphone.request();
    if (!cam.isGranted || !mic.isGranted) {
      if (mounted) {
        setState(() => _conn = RoomConnState.disconnected);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Kamera ve mikrofon izni gerekli')),
        );
      }
      return;
    }

    final auth = ref.read(authControllerProvider);
    final token = auth?.accessToken;
    final myId = auth?.userId;
    if (token == null || myId == null) return;

    try {
      final session = await ref.read(sessionRemoteProvider).getSessionByBooking(widget.bookingId);
      final wsRaw = replaceLocalhostForAndroid(session.signalingWebSocketUrl);
      final base = Uri.parse(wsRaw);
      final uri = base.replace(queryParameters: {...base.queryParameters, 'token': token});

      _rtc = WebRtcEngine();
      await _rtc!.setupPeerConnection(session.iceServers);
      await _rtc!.getUserMedia();
      _localRenderer.srcObject = _rtc!.localStream;

      _rtc!.onIceCandidate((c) {
        if (_remoteUserId == null) return;
        _sig?.sendJson(
          iceOut(
            targetUserId: _remoteUserId!,
            candidate: c.candidate ?? '',
            sdpMid: c.sdpMid,
            sdpMLineIndex: c.sdpMLineIndex,
          ),
        );
      });

      _rtc!.remoteStreams.listen((s) {
        _remoteRenderer.srcObject = s;
        if (mounted) setState(() => _conn = RoomConnState.connected);
      });

      _sig = await SignalingClient.connect(uri);
      _joinedAt = DateTime.now();

      _sub = _sig!.messages.listen((msg) async {
        await _onSignal(msg, myId);
      });

      if (mounted) setState(() {});
    } catch (e) {
      if (mounted) {
        setState(() => _conn = RoomConnState.disconnected);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  Future<void> _onSignal(SignalingMessage msg, String myId) async {
    final rtc = _rtc;
    final sig = _sig;
    if (rtc == null || sig == null) return;

    if (msg is RoomJoinedMessage) {
      final others = msg.peers.where((p) => p.userId != myId).toList();
      if (others.isNotEmpty) {
        _remoteUserId = others.first.userId;
        _waitingPeer = false;
        await _maybeSendOffer(rtc, sig);
      } else {
        _waitingPeer = true;
      }
      return;
    }
    if (msg is PeerJoinedMessage) {
      if (msg.userId != myId) {
        _remoteUserId = msg.userId;
        if (_waitingPeer) {
          _waitingPeer = false;
          await _maybeSendOffer(rtc, sig);
        }
      }
      return;
    }
    if (msg is OfferMessage) {
      final from = msg.fromUserId;
      if (from != null && from != myId) {
        _remoteUserId = from;
        final desc = RTCSessionDescription(msg.sdp, 'offer');
        final answer = await rtc.applyRemoteOfferCreateAnswer(desc);
        sig.sendJson(answerOut(targetUserId: from, sdp: answer.sdp ?? ''));
      }
      return;
    }
    if (msg is AnswerMessage) {
      final from = msg.fromUserId;
      if (from != null && from != myId) {
        await rtc.setRemoteDescription(RTCSessionDescription(msg.sdp, 'answer'));
      }
      return;
    }
    if (msg is IceCandidateMessage) {
      final from = msg.fromUserId;
      if (from != null && from != myId) {
        await rtc.addIceCandidate(
          RTCIceCandidate(msg.candidate, msg.sdpMid ?? '', msg.sdpMLineIndex ?? 0),
        );
      }
      return;
    }
    if (msg is ErrorMessage && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg.message)));
    }
  }

  Future<void> _maybeSendOffer(WebRtcEngine rtc, SignalingClient sig) async {
    if (_offerSent || _remoteUserId == null) return;
    _offerSent = true;
    final offer = await rtc.createOffer();
    sig.sendJson(offerOut(targetUserId: _remoteUserId!, sdp: offer.sdp ?? ''));
  }

  Future<void> _cleanup({bool pop = false}) async {
    try {
      _sig?.sendJson(leaveRoomOut);
    } catch (_) {}
    await _sub?.cancel();
    await _sig?.dispose();
    await _rtc?.dispose();
    await _localRenderer.dispose();
    await _remoteRenderer.dispose();
    _sig = null;
    _rtc = null;
    if (pop && mounted) context.pop();
  }

  Future<void> _hangup() => _cleanup(pop: true);

  Future<void> _completeInterview() async {
    final start = _joinedAt ?? DateTime.now();
    final secs = DateTime.now().difference(start).inSeconds;
    try {
      await ref.read(sessionRemoteProvider).completeSession(
            bookingId: widget.bookingId,
            durationSeconds: secs,
            recordedVideoUrl: '',
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Mülakat tamamlandı')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  @override
  void dispose() {
    unawaited(_cleanup(pop: false));
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    final isExpert = auth?.role.toUpperCase() == 'EXPERT';

    return Scaffold(
      appBar: AppBar(
        title: Text('Mülakat ${widget.bookingId.length > 8 ? widget.bookingId.substring(0, 8) : widget.bookingId}…'),
        actions: [
          if (isExpert)
            TextButton(
              onPressed: _completeInterview,
              child: const Text('Tamamla'),
            ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                Icon(
                  _conn == RoomConnState.connected ? Icons.link : Icons.link_off,
                  color: _conn == RoomConnState.connected ? Colors.green : Colors.grey,
                ),
                const SizedBox(width: 8),
                Text(_conn.name),
              ],
            ),
          ),
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                RTCVideoView(_remoteRenderer, objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover),
                Positioned(
                  right: 12,
                  bottom: 12,
                  width: 120,
                  height: 160,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: RTCVideoView(_localRenderer, objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover),
                  ),
                ),
              ],
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              IconButton(
                icon: const Icon(Icons.mic_off),
                onPressed: () {
                  final audios = _rtc?.localStream?.getAudioTracks() ?? [];
                  if (audios.isNotEmpty) audios.first.enabled = !audios.first.enabled;
                },
              ),
              IconButton(
                icon: const Icon(Icons.videocam_off),
                onPressed: () {
                  final vids = _rtc?.localStream?.getVideoTracks() ?? [];
                  if (vids.isNotEmpty) vids.first.enabled = !vids.first.enabled;
                },
              ),
              IconButton(
                icon: const Icon(Icons.call_end, color: Colors.red),
                onPressed: _hangup,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

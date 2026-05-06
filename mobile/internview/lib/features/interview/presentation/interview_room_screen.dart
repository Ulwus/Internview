import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_background/flutter_background.dart';

import '../../../core/network/local_host.dart';
import '../../../core/presentation/widgets/neo/neo_box.dart';
import '../../../core/presentation/widgets/neo/neo_button.dart';
import '../../auth/controllers/auth_controller.dart';
import '../../booking/data/booking_remote_data_source.dart';
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
  bool _isExpert = false;
  bool _waitingPeer = false;
  bool _offerSent = false;
  bool _isOfferer = false;
  DateTime? _joinedAt;
  DateTime? _scheduledEndLocal;
  Timer? _countdownArmTimer;
  Timer? _countdownTicker;
  Timer? _autoCloseTimer;
  int? _remainingSeconds;
  bool _closing = false;
  bool _finishRequested = false;
  bool _finishClosing = false;
  bool _isScreenSharing = false;
  MediaStream? _screenStream;

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
    _isExpert = (auth?.role.toUpperCase() == 'EXPERT');
    _isOfferer = _isExpert; // deterministik: offer'ı sadece uzman üretir

    try {
      final booking = await ref.read(bookingRemoteProvider).getBooking(widget.bookingId);
      if (booking.status.name.toUpperCase() != 'CONFIRMED') {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Mülakat sadece onaylı randevuda açılır')),
          );
          context.pop();
        }
        return;
      }
      final now = DateTime.now();
      final start = booking.scheduledStart.toLocal();
      final end = booking.scheduledEnd.toLocal();
      final inJoinWindow =
          (now.isAfter(start.subtract(const Duration(minutes: 15))) && now.isBefore(end)) ||
              (now.isAfter(start) && now.isBefore(end.add(const Duration(minutes: 5))));
      if (!inJoinWindow) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Mülakat zamanı dışında odaya girilemez')),
          );
          context.pop();
        }
        return;
      }
      _scheduledEndLocal = end;
      _armCountdownAndAutoClose();

      final session = await ref.read(sessionRemoteProvider).getSessionByBooking(widget.bookingId);
      final wsRaw = replaceLocalhostForAndroid(session.signalingWebSocketUrl);
      final base = Uri.parse(wsRaw);
      final uri = base.replace(queryParameters: {...base.queryParameters, 'token': token});

      _rtc = WebRtcEngine();
      await _rtc!.setupPeerConnection(session.iceServers);
      await _rtc!.getUserMedia();
      // Ses yönlendirme: Android'de varsayılan olarak hoparlöre alalım.
      // (Emülatörde/cihazda karşı ses gelmiyor hissini azaltır)
      try {
        await Helper.setSpeakerphoneOn(true);
      } catch (_) {}
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

  void _armCountdownAndAutoClose() {
    _countdownArmTimer?.cancel();
    _countdownTicker?.cancel();
    _autoCloseTimer?.cancel();

    final end = _scheduledEndLocal;
    if (end == null) return;

    final now = DateTime.now();
    final msToEnd = end.difference(now).inMilliseconds;
    if (msToEnd <= 0) {
      unawaited(_closeDueToTime());
      return;
    }

    // Otomatik kapatma
    _autoCloseTimer = Timer(Duration(milliseconds: msToEnd), () {
      unawaited(_closeDueToTime());
    });

    // Kalan süre ekranda hep doğru görünsün (0s değil).
    _startCountdownTicker();
  }

  void _startCountdownTicker() {
    _countdownTicker?.cancel();
    _countdownTicker = Timer.periodic(const Duration(seconds: 1), (_) {
      final end = _scheduledEndLocal;
      if (end == null) return;
      final secs = end.difference(DateTime.now()).inSeconds;
      if (secs <= 0) {
        _remainingSeconds = 0;
        _countdownTicker?.cancel();
        if (mounted) setState(() {});
        return;
      }
      if (mounted) {
        setState(() => _remainingSeconds = secs);
      } else {
        _remainingSeconds = secs;
      }
    });
    // ilk render hemen gelsin
    final end = _scheduledEndLocal;
    if (end != null) {
      final secs = end.difference(DateTime.now()).inSeconds;
      if (mounted) setState(() => _remainingSeconds = secs);
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
        if (_isOfferer) await _maybeSendOffer(rtc, sig);
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
          if (_isOfferer) await _maybeSendOffer(rtc, sig);
        }
      }
      return;
    }
    if (msg is OfferMessage) {
      final from = msg.fromUserId;
      if (from != null && from != myId) {
        _remoteUserId = from;
        // Eğer offerer değilsek (aday), kesinlikle local-offer üretmemeliyiz.
        _offerSent = false;
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
          RTCIceCandidate(msg.candidate, msg.sdpMid, msg.sdpMLineIndex ?? 0),
        );
      }
      return;
    }
    if (msg is ErrorMessage && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg.message)));
    }
    if (msg is FinishRequestMessage) {
      // Candidate sees confirmation modal.
      if (_isExpert) return;
      if (!mounted) return;
      await _showFinishRequestDialog();
      return;
    }
    if (msg is FinishAcceptMessage) {
      // Expert completes + notifies candidate.
      if (!_isExpert || _finishClosing) return;
      _finishClosing = true;
      if (mounted) setState(() => _finishRequested = false);
      await _completeInterview();
      if (_remoteUserId != null) {
        _sig?.sendJson(finishDoneOut(targetUserId: _remoteUserId!));
      }
      if (!mounted) return;
      await _cleanup(pop: false);
      if (!mounted) return;
      context.go('/interview/${widget.bookingId}/result');
      return;
    }
    if (msg is FinishRejectMessage) {
      if (_isExpert && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Aday bitirmeyi reddetti')));
      }
      if (mounted) {
        setState(() => _finishRequested = false);
      } else {
        _finishRequested = false;
      }
      return;
    }
    if (msg is FinishDoneMessage) {
      // Candidate closes when expert completes.
      if (_isExpert) return;
      if (!mounted) return;
      await _cleanup(pop: false);
      if (!mounted) return;
      context.go('/interview/${widget.bookingId}/result');
      return;
    }
  }

  Future<void> _maybeSendOffer(WebRtcEngine rtc, SignalingClient sig) async {
    if (_offerSent || _remoteUserId == null) return;
    _offerSent = true;
    final offer = await rtc.createOffer();
    sig.sendJson(offerOut(targetUserId: _remoteUserId!, sdp: offer.sdp ?? ''));
  }

  Future<void> _renegotiateIfPossible() async {
    final rtc = _rtc;
    final sig = _sig;
    if (rtc == null || sig == null) return;
    if (!_isOfferer) return;
    if (_remoteUserId == null) return;

    // Glare önlemek için stable değilsek renegotiate etmeyelim.
    final st = rtc.signalingState;
    if (st != null && st != RTCSignalingState.RTCSignalingStateStable) return;

    final offer = await rtc.createOffer();
    sig.sendJson(offerOut(targetUserId: _remoteUserId!, sdp: offer.sdp ?? ''));
  }

  Future<void> _toggleScreenShare() async {
    final rtc = _rtc;
    if (rtc == null) return;

    try {
      if (_isScreenSharing) {
        final camTracks = rtc.localStream?.getVideoTracks() ?? [];
        if (camTracks.isNotEmpty) {
          await rtc.replaceVideoTrack(camTracks.first);
          await _screenStream?.dispose();
          _screenStream = null;
          if (mounted) setState(() => _isScreenSharing = false);
          await _renegotiateIfPossible();

          try {
            if (Theme.of(context).platform == TargetPlatform.android && FlutterBackground.isBackgroundExecutionEnabled) {
              await FlutterBackground.disableBackgroundExecution();
            }
          } catch (_) {}
        }
        return;
      }

      try {
        if (Theme.of(context).platform == TargetPlatform.android) {
          final hasPermissions = await FlutterBackground.hasPermissions;
          if (!hasPermissions) {
            const androidConfig = FlutterBackgroundAndroidConfig(
              notificationTitle: "Ekran Paylaşımı",
              notificationText: "Ekran paylaşımı devam ediyor...",
              notificationImportance: AndroidNotificationImportance.normal,
              notificationIcon: AndroidResource(name: 'ic_launcher', defType: 'mipmap'),
            );
            await FlutterBackground.initialize(androidConfig: androidConfig);
          }
          if (!FlutterBackground.isBackgroundExecutionEnabled) {
            await FlutterBackground.enableBackgroundExecution();
          }
        }
      } catch (e) {
        debugPrint('FlutterBackground error: $e');
      }

      // Ekran paylaşımı: Android/iOS destek durumuna göre hata verebilir.
      final display = await navigator.mediaDevices.getDisplayMedia({
        'audio': false,
        'video': true,
      });
      final screenTracks = display.getVideoTracks();
      if (screenTracks.isEmpty) {
        await display.dispose();
        return;
      }

      _screenStream = display;
      await rtc.replaceVideoTrack(screenTracks.first);
      if (mounted) setState(() => _isScreenSharing = true);
      await _renegotiateIfPossible();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ekran paylaşımı açılamadı: $e')),
        );
      }
    }
  }

  Future<void> _cleanup({bool pop = false}) async {
    try {
      _sig?.sendJson(leaveRoomOut);
    } catch (_) {}
    _countdownArmTimer?.cancel();
    _countdownTicker?.cancel();
    _autoCloseTimer?.cancel();
    await _sub?.cancel();
    await _sig?.dispose();
    await _rtc?.dispose();
    await _localRenderer.dispose();
    await _remoteRenderer.dispose();

    try {
      if (Theme.of(context).platform == TargetPlatform.android && FlutterBackground.isBackgroundExecutionEnabled) {
        await FlutterBackground.disableBackgroundExecution();
      }
    } catch (_) {}

    _sig = null;
    _rtc = null;
    if (pop && mounted) context.pop();
  }

  Future<void> _hangup() => _cleanup(pop: true);

  Future<void> _requestFinish() async {
    if (!_isExpert) return;
    if (_finishRequested) return;
    if (_remoteUserId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Karşı taraf bağlanmadan bitirme isteği gönderilemez')),
        );
      }
      return;
    }
    if (mounted) {
      setState(() => _finishRequested = true);
    } else {
      _finishRequested = true;
    }
    _sig?.sendJson(finishRequestOut(targetUserId: _remoteUserId!));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bitirme isteği gönderildi')),
      );
    }
  }

  Future<void> _showFinishRequestDialog() async {
    if (!mounted) return;
    final remoteId = _remoteUserId;
    if (remoteId == null) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          contentPadding: const EdgeInsets.all(16),
          content: NeoBox(
            color: const Color(0xFFFFD600),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Uzman mülakatı bitirmek istiyor',
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Onaylarsan mülakat kapanacak ve sonuç ekranına geçeceksin.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: NeoButton(
                        color: Colors.white,
                        onPressed: () {
                          _sig?.sendJson(finishRejectOut(targetUserId: remoteId));
                          Navigator.of(context).pop();
                        },
                        child: const Center(
                          child: Text('Reddet', style: TextStyle(fontWeight: FontWeight.w900)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: NeoButton(
                        color: const Color(0xFF00E5FF),
                        onPressed: () {
                          _sig?.sendJson(finishAcceptOut(targetUserId: remoteId));
                          Navigator.of(context).pop();
                        },
                        child: const Center(
                          child: Text('Onayla', style: TextStyle(fontWeight: FontWeight.w900)),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

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

  Future<void> _closeDueToTime() async {
    if (_closing) return;
    _closing = true;
    await _completeInterview();
    await _cleanup(pop: true);
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
      backgroundColor: const Color(0xFFFAFAFA),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF9100), // Orange
                        border: Border.all(color: Colors.black, width: 3),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Kalan Süre: ${_remainingSeconds ?? 0}s',
                        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                  if (isExpert) ...[
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () async {
                        // Uzman: Bitirme isteği karşı tarafa gitsin ve popup açılsın.
                        if (_finishRequested) {
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Adayın onayı bekleniyor')),
                          );
                          return;
                        }
                        await _requestFinish();
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF00E5FF), // Cyan
                          border: Border.all(color: Colors.black, width: 3),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _finishRequested ? 'Bekleniyor' : 'Bitir',
                          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              if (isExpert && _finishRequested) ...[
                const SizedBox(height: 12),
                NeoBox(
                  color: const Color(0xFFFFD600),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    child: Text(
                      'Adaydan onay bekleniyor…',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              Expanded(
                child: Stack(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFB388FF), // Purple shadow/bg
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.black, width: 4),
                        boxShadow: const [
                          BoxShadow(color: Colors.black, offset: Offset(6, 6)),
                        ],
                      ),
                      clipBehavior: Clip.hardEdge,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          RTCVideoView(_remoteRenderer, objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover),
                          if (_conn != RoomConnState.connected)
                            const Center(
                              child: Text(
                                'Karşıdaki Kişinin Paylaşımı\nBekleniyor...',
                                textAlign: TextAlign.center,
                                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
                              ),
                            ),
                        ],
                      ),
                    ),
                    Positioned(
                      right: 16,
                      bottom: 16,
                      width: 120,
                      height: 160,
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFD600), // Yellow shadow/bg
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.black, width: 3),
                        ),
                        clipBehavior: Clip.hardEdge,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            RTCVideoView(_localRenderer, objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover),
                            if (_rtc?.localStream == null)
                              const Center(
                                child: Text(
                                  'Mevcut\nKişinin\nPaylaşımı',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildControlBtn('Mik', Icons.mic_off, const Color(0xFFFFD600), () {
                    final audios = _rtc?.localStream?.getAudioTracks() ?? [];
                    if (audios.isNotEmpty) audios.first.enabled = !audios.first.enabled;
                  }),
                  _buildControlBtn(
                    _isScreenSharing ? 'Ekran ✓' : 'Ekran',
                    Icons.screen_share,
                    const Color(0xFF00E5FF),
                    () async => _toggleScreenShare(),
                  ),
                  _buildControlBtn('Cam', Icons.videocam_off, const Color(0xFFFF5252), () {
                    final vids = _rtc?.localStream?.getVideoTracks() ?? [];
                    if (vids.isNotEmpty) vids.first.enabled = !vids.first.enabled;
                  }),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildControlBtn(String label, IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.black, width: 3),
          boxShadow: const [
            BoxShadow(color: Colors.black, offset: Offset(3, 3)),
          ],
        ),
        child: Column(
          children: [
            Icon(icon, color: Colors.black),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black)),
          ],
        ),
      ),
    );
  }
}

import 'dart:async';
import 'dart:developer' as developer;
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../core/models/booking_models.dart';
import '../../../core/platform/media_projection_fgs.dart';

import '../../../core/network/local_host.dart';
import '../../../core/presentation/widgets/neo/neo_background.dart';
import '../../../core/presentation/widgets/penkrowd/animated_action_button.dart';
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
  ConsumerState<InterviewRoomScreen> createState() =>
      _InterviewRoomScreenState();
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
  DateTime? _joinedAt;
  DateTime? _scheduledEndLocal;
  Timer? _countdownArmTimer;
  Timer? _countdownTicker;
  Timer? _autoCloseTimer;
  Timer? _sfuSyncTimer;
  final ValueNotifier<int?> _remainingSeconds = ValueNotifier<int?>(null);
  bool _closing = false;
  bool _finishRequested = false;
  bool _finishClosing = false;
  bool _isScreenSharing = false;
  MediaStream? _screenStream;
  bool _screenShareFgsEnabled = false;
  StreamSubscription<MediaStream>? _remoteStreamSub;
  bool _cleanedUp = false;

  Future<void> _ensureScreenShareForegroundService() async {
    if (!Platform.isAndroid) return;
    if (_screenShareFgsEnabled) return;
    await MediaProjectionFgs.start();
    _screenShareFgsEnabled = true;
  }

  Future<void> _stopScreenShareForegroundService() async {
    if (!Platform.isAndroid) return;
    if (!_screenShareFgsEnabled) return;
    try {
      await MediaProjectionFgs.stop();
    } finally {
      _screenShareFgsEnabled = false;
    }
  }

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<bool> _ensureCameraMicPermissions() async {
    final camStatus = await Permission.camera.request();
    final micStatus = await Permission.microphone.request();

    final ok = camStatus.isGranted && micStatus.isGranted;
    if (ok) return true;

    if (!mounted) return false;

    final permanentlyBlocked =
        camStatus.isPermanentlyDenied ||
        micStatus.isPermanentlyDenied ||
        camStatus.isRestricted ||
        micStatus.isRestricted;

    if (permanentlyBlocked) {
      await showDialog<void>(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text('İzin gerekli'),
            content: const Text(
              'Mülakata katılmak için kamera ve mikrofon izni gerekli. '
              'İzinleri Ayarlar’dan açıp tekrar deneyin.',
            ),
            actions: [
              AnimatedActionButton(
                onTap: () => Navigator.of(context).pop(),
                width: 110,
                height: 44,
                color: Colors.white,
                pressedColor: Colors.white,
                borderColor: Colors.black,
                borderWidth: 3,
                borderRadius: 14,
                shadowOffset: const Offset(4, 4),
                child: const Center(
                  child: Text(
                    'İptal',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      color: Colors.black,
                    ),
                  ),
                ),
              ),
              AnimatedActionButton(
                onTap: () async {
                  Navigator.of(context).pop();
                  await openAppSettings();
                },
                width: 110,
                height: 44,
                color: const Color(0xFF00E5FF),
                pressedColor: const Color(0xFF00E5FF),
                borderColor: Colors.black,
                borderWidth: 3,
                borderRadius: 14,
                shadowOffset: const Offset(4, 4),
                child: const Center(
                  child: Text(
                    'Ayarlar',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      color: Colors.black,
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Kamera ve mikrofon izni gerekli')),
      );
    }

    return false;
  }

  String _formatRemainingMinutes(int? seconds) {
    final value = seconds ?? 0;
    if (value <= 0) return '0 dk';
    if (value < 60) return '<1 dk';
    return '${(value / 60).ceil()} dk';
  }

  Future<void> _init() async {
    await _localRenderer.initialize();
    await _remoteRenderer.initialize();
    final permsOk = await _ensureCameraMicPermissions();
    if (!permsOk) {
      if (mounted) setState(() => _conn = RoomConnState.disconnected);
      return;
    }

    final auth = ref.read(authControllerProvider);
    final token = auth?.accessToken;
    final myId = auth?.userId;
    if (token == null || myId == null) return;
    _isExpert = (auth?.role.toUpperCase() == 'EXPERT');

    try {
      final booking = await ref
          .read(bookingRemoteProvider)
          .getBooking(widget.bookingId);
      if (booking.status.name.toUpperCase() != 'CONFIRMED') {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Mülakat sadece onaylı randevuda açılır'),
            ),
          );
          context.pop();
        }
        return;
      }
      final now = DateTime.now();
      final start = booking.scheduledStart.toLocal();
      final end = booking.scheduledEnd.toLocal();
      final inJoinWindow = now.isAfter(start) && now.isBefore(end);
      if (!inJoinWindow) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Mülakat zamanı dışında odaya girilemez'),
            ),
          );
          context.pop();
        }
        return;
      }
      _scheduledEndLocal = end;
      _armCountdownAndAutoClose();

      final session = await ref
          .read(sessionRemoteProvider)
          .getSessionByBooking(widget.bookingId);
      final wsRaw = replaceLocalhostForAndroid(session.signalingWebSocketUrl);
      final base = Uri.parse(wsRaw);
      final uri = base.replace(
        queryParameters: {...base.queryParameters, 'token': token},
      );

      _rtc = WebRtcEngine();
      await _rtc!.setupMediasoup(
        sessionId: session.sessionId,
        remoteDataSource: ref.read(sessionRemoteProvider),
      );
      await _rtc!.getUserMedia();
      // Ses yönlendirme: Android'de varsayılan olarak hoparlöre alalım.
      // (Emülatörde/cihazda karşı ses gelmiyor hissini azaltır)
      try {
        await Helper.setSpeakerphoneOn(true);
      } catch (_) {}
      _localRenderer.srcObject = _rtc!.localStream;

      _remoteStreamSub = _rtc!.remoteStreams.listen((s) {
        _remoteRenderer.srcObject = s;
        if (mounted) setState(() => _conn = RoomConnState.connected);
      });

      _sig = await SignalingClient.connect(uri);
      _joinedAt = DateTime.now();

      _sub = _sig!.messages.listen((msg) async {
        await _onSignal(msg, myId);
      });
      unawaited(_syncSfuConsumers());
      _startSfuSyncTimer();

      if (mounted) setState(() {});
    } catch (e) {
      if (mounted) {
        setState(() => _conn = RoomConnState.disconnected);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  void _startSfuSyncTimer() {
    _sfuSyncTimer?.cancel();
    var attempts = 0;
    _sfuSyncTimer = Timer.periodic(const Duration(milliseconds: 1500), (timer) {
      attempts += 1;
      if (_cleanedUp || attempts > 40) {
        timer.cancel();
        return;
      }
      unawaited(_syncSfuConsumers());
    });
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
        _remainingSeconds.value = 0;
        _countdownTicker?.cancel();
        return;
      }
      _remainingSeconds.value = secs;
    });
    // ilk render hemen gelsin
    final end = _scheduledEndLocal;
    if (end != null) {
      final secs = end.difference(DateTime.now()).inSeconds;
      _remainingSeconds.value = secs;
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
        await _syncSfuConsumers();
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
        }
        await _syncSfuConsumers();
      }
      return;
    }
    if (msg is OfferMessage) {
      return;
    }
    if (msg is AnswerMessage) {
      return;
    }
    if (msg is IceCandidateMessage) {
      return;
    }
    if (msg is ErrorMessage && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(msg.message)));
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
      context.go('/interview/${widget.bookingId}/result');
      unawaited(_cleanup(pop: false));
      return;
    }
    if (msg is FinishRejectMessage) {
      if (_isExpert && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Aday bitirmeyi reddetti')),
        );
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
      context.go('/interview/${widget.bookingId}/result');
      unawaited(_cleanup(pop: false));
      return;
    }
  }

  Future<void> _renegotiateIfPossible() async {
    await _syncSfuConsumers();
  }

  Future<void> _syncSfuConsumers() async {
    try {
      await Future<void>.delayed(const Duration(milliseconds: 250));
      await _rtc?.syncRemoteProducers();
    } catch (e) {
      developer.log('SFU consume sync failed: $e', name: 'InterviewRoom');
    }
  }

  Future<void> _toggleScreenShare() async {
    final rtc = _rtc;
    if (rtc == null) return;

    try {
      if (Platform.isIOS) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('iOS’ta ekran paylaşımı bu sürümde desteklenmiyor'),
            ),
          );
        }
        return;
      }
      if (_isScreenSharing) {
        final camTracks = rtc.localStream?.getVideoTracks() ?? [];
        if (camTracks.isNotEmpty) {
          await rtc.replaceVideoTrack(camTracks.first);
          await _screenStream?.dispose();
          _screenStream = null;
          if (mounted) setState(() => _isScreenSharing = false);
          await _renegotiateIfPossible();
          await _stopScreenShareForegroundService();
        }
        return;
      }

      // Ekran paylaşımı: Android/iOS destek durumuna göre hata verebilir.
      if (Platform.isAndroid) {
        // Android 14+’ta mediaProjection tipinde FGS başlatabilmek için önce
        // kullanıcıdan ekran yakalama iznini al.
        final granted = await Helper.requestCapturePermission();
        if (granted != true) {
          return;
        }
      }
      await _ensureScreenShareForegroundService();
      final display = await navigator.mediaDevices.getDisplayMedia({
        'audio': false,
        'video': true,
      });
      final screenTracks = display.getVideoTracks();
      if (screenTracks.isEmpty) {
        await display.dispose();
        await _stopScreenShareForegroundService();
        return;
      }

      _screenStream = display;
      await rtc.replaceVideoTrack(screenTracks.first);
      if (mounted) setState(() => _isScreenSharing = true);
      await _renegotiateIfPossible();
    } catch (e) {
      await _stopScreenShareForegroundService();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ekran paylaşımı açılamadı: $e')),
        );
      }
    }
  }

  Future<void> _cleanup({bool pop = false}) async {
    if (_cleanedUp) return;
    _cleanedUp = true;
    try {
      _sig?.sendJson(leaveRoomOut);
    } catch (_) {}
    _countdownArmTimer?.cancel();
    _countdownTicker?.cancel();
    _autoCloseTimer?.cancel();
    _sfuSyncTimer?.cancel();
    await _sub?.cancel();
    await _remoteStreamSub?.cancel();
    await _sig?.dispose();
    await _rtc?.dispose();
    await _localRenderer.dispose();
    await _remoteRenderer.dispose();
    await _stopScreenShareForegroundService();

    _sig = null;
    _rtc = null;
    if (pop && mounted) context.pop();
  }

  Future<void> _requestFinish() async {
    if (!_isExpert) return;
    if (_finishRequested) return;
    if (_remoteUserId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Karşı taraf bağlanmadan bitirme isteği gönderilemez',
            ),
          ),
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
          content: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFFFD600),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.black, width: 3),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black,
                  blurRadius: 0,
                  offset: Offset(4, 4),
                ),
              ],
            ),
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
                      child: AnimatedActionButton(
                        onTap: () {
                          _sig?.sendJson(
                            finishRejectOut(targetUserId: remoteId),
                          );
                          Navigator.of(context).pop();
                        },
                        width: double.infinity,
                        height: 44,
                        color: Colors.white,
                        pressedColor: Colors.white,
                        borderColor: Colors.black,
                        borderWidth: 3,
                        borderRadius: 14,
                        shadowOffset: const Offset(4, 4),
                        child: const Center(
                          child: Text(
                            'Reddet',
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              color: Colors.black,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: AnimatedActionButton(
                        onTap: () {
                          _sig?.sendJson(
                            finishAcceptOut(targetUserId: remoteId),
                          );
                          Navigator.of(context).pop();
                          unawaited(_markBookingCompletedFallback());
                        },
                        width: double.infinity,
                        height: 44,
                        color: const Color(0xFF00E5FF),
                        pressedColor: const Color(0xFF00E5FF),
                        borderColor: Colors.black,
                        borderWidth: 3,
                        borderRadius: 14,
                        shadowOffset: const Offset(4, 4),
                        child: const Center(
                          child: Text(
                            'Onayla',
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              color: Colors.black,
                            ),
                          ),
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
      await ref
          .read(sessionRemoteProvider)
          .completeSession(
            bookingId: widget.bookingId,
            durationSeconds: secs,
            recordedVideoUrl: '',
          );
      await _markBookingCompletedFallback();
      await _waitForBookingCompleted();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Mülakat tamamlandı')));
      }
    } catch (e) {
      await _markBookingCompletedFallback();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  Future<void> _markBookingCompletedFallback() async {
    try {
      await ref.read(bookingRemoteProvider).completeBooking(widget.bookingId);
    } catch (_) {}
  }

  Future<void> _waitForBookingCompleted() async {
    for (var attempt = 0; attempt < 10; attempt++) {
      try {
        final booking = await ref
            .read(bookingRemoteProvider)
            .getBooking(widget.bookingId);
        if (booking.status == BookingStatus.completed) {
          return;
        }
      } catch (_) {}
      await Future<void>.delayed(const Duration(milliseconds: 300));
    }
  }

  Future<void> _closeDueToTime() async {
    if (_closing) return;
    _closing = true;
    if (_isExpert) {
      await _completeInterview();
    }
    await _cleanup(pop: true);
  }

  @override
  void dispose() {
    unawaited(_cleanup(pop: false));
    _remainingSeconds.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    final isExpert = auth?.role.toUpperCase() == 'EXPERT';

    return NeoBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
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
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF9100), // Orange
                          border: Border.all(color: Colors.black, width: 3),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: ValueListenableBuilder<int?>(
                          valueListenable: _remainingSeconds,
                          builder: (context, seconds, _) {
                            return Text(
                              'Kalan Süre: ${_formatRemainingMinutes(seconds)}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 16,
                              ),
                              textAlign: TextAlign.center,
                            );
                          },
                        ),
                      ),
                    ),
                    if (isExpert) ...[
                      const SizedBox(width: 8),
                      AnimatedActionButton(
                        onTap: () async {
                          // Uzman: Bitirme isteği karşı tarafa gitsin ve popup açılsın.
                          if (_finishRequested) {
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Adayın onayı bekleniyor'),
                              ),
                            );
                            return;
                          }
                          await _requestFinish();
                        },
                        width: 120,
                        height: 44,
                        color: const Color(0xFF00E5FF),
                        pressedColor: const Color(0xFF00E5FF),
                        borderColor: Colors.black,
                        borderWidth: 3,
                        borderRadius: 14,
                        shadowOffset: const Offset(4, 4),
                        child: Center(
                          child: Text(
                            _finishRequested ? 'Bekleniyor' : 'Bitir',
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 16,
                              color: Colors.black,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                if (isExpert && _finishRequested) ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFD600),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.black, width: 3),
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black,
                          blurRadius: 0,
                          offset: Offset(4, 4),
                        ),
                      ],
                    ),
                    child: const Text(
                      'Adaydan onay bekleniyor…',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontWeight: FontWeight.w900),
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
                            BoxShadow(
                              color: Colors.black,
                              offset: Offset(6, 6),
                            ),
                          ],
                        ),
                        clipBehavior: Clip.hardEdge,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            ExcludeSemantics(
                              child: RepaintBoundary(
                                child: RTCVideoView(
                                  _remoteRenderer,
                                  objectFit: RTCVideoViewObjectFit
                                      .RTCVideoViewObjectFitContain,
                                ),
                              ),
                            ),
                            if (_conn != RoomConnState.connected)
                              const Center(
                                child: Text(
                                  'Karşıdaki Kişinin Paylaşımı\nBekleniyor...',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 18,
                                  ),
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
                              ExcludeSemantics(
                                child: RepaintBoundary(
                                  child: RTCVideoView(
                                    _localRenderer,
                                    objectFit: RTCVideoViewObjectFit
                                        .RTCVideoViewObjectFitContain,
                                  ),
                                ),
                              ),
                              if (_rtc?.localStream == null)
                                const Center(
                                  child: Text(
                                    'Mevcut\nKişinin\nPaylaşımı',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
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
                    _buildControlBtn(
                      'Mik',
                      Icons.mic_off,
                      const Color(0xFFFFD600),
                      () {
                        final audios =
                            _rtc?.localStream?.getAudioTracks() ?? [];
                        if (audios.isNotEmpty) {
                          audios.first.enabled = !audios.first.enabled;
                        }
                      },
                    ),
                    _buildControlBtn(
                      _isScreenSharing ? 'Ekran ✓' : 'Ekran',
                      Icons.screen_share,
                      const Color(0xFF00E5FF),
                      () async => _toggleScreenShare(),
                    ),
                    _buildControlBtn(
                      'Cam',
                      Icons.videocam_off,
                      const Color(0xFFFF5252),
                      () {
                        final vids = _rtc?.localStream?.getVideoTracks() ?? [];
                        if (vids.isNotEmpty) {
                          vids.first.enabled = !vids.first.enabled;
                        }
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildControlBtn(
    String label,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return AnimatedActionButton(
      onTap: onTap,
      width: 96,
      height: 64,
      color: color,
      pressedColor: color,
      borderColor: Colors.black,
      borderWidth: 3,
      borderRadius: 14,
      shadowOffset: const Offset(4, 4),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: Colors.black),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.w900,
              color: Colors.black,
            ),
          ),
        ],
      ),
    );
  }
}

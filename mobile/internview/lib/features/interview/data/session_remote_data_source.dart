import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:async';

import '../../../core/config/env.dart';
import '../../../core/models/session_models.dart';
import '../../../core/network/dio_client.dart';
import 'mediasoup_models.dart';

final sessionRemoteProvider = Provider<SessionRemoteDataSource>(
  (ref) => SessionRemoteDataSource(ref.watch(dioProvider)),
);

/// Interview servisi bu uçlarda ham JSON döner (ApiResponse zarfı yok).
class SessionRemoteDataSource {
  SessionRemoteDataSource(this._dio);

  final Dio _dio;

  Future<SessionSummary> getSessionByBooking(String bookingId) async {
    // booking -> interview session yaratımı Kafka ile async olabilir.
    // Bu yüzden kısa bir süre 404 alırsak yeniden deneriz.
    const maxAttempts = 6;
    for (var attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        final r = await _dio.get<Map<String, dynamic>>(
          // gateway: /interviews/** StripPrefix=1 -> interview-service: /sessions/**
          '/interviews/sessions/booking/$bookingId',
        );
        final data = r.data;
        if (data == null) throw StateError('Boş yanıt');
        return SessionSummary.fromJson(data);
      } on DioException catch (e) {
        final code = e.response?.statusCode;
        final isNotFound = code == 404;
        if (!isNotFound || attempt == maxAttempts) rethrow;
        await Future<void>.delayed(const Duration(milliseconds: 500));
      }
    }
    throw StateError('Beklenmeyen durum');
  }

  Future<void> completeSession({
    required String bookingId,
    required int durationSeconds,
    String recordedVideoUrl = '',
  }) async {
    await _dio.post<void>(
      // interview-service: POST /sessions/{bookingId}/complete
      '/interviews/sessions/$bookingId/complete',
      data: {
        'durationSeconds': durationSeconds,
        'recordedVideoUrl': recordedVideoUrl,
      },
    );
  }

  Future<Map<String, dynamic>> getMediaCapabilities(String sessionId) async {
    final r = await _dio.get<Map<String, dynamic>>(
      '/interviews/sessions/$sessionId/media/capabilities',
    );
    final data = r.data;
    if (data == null) throw StateError('Boş media capabilities yanıtı');
    return Map<String, dynamic>.from(data['rtpCapabilities'] as Map);
  }

  Future<MediaTransportInfo> createMediaTransport(String sessionId) async {
    final r = await _dio.post<Map<String, dynamic>>(
      '/interviews/sessions/$sessionId/media/transport',
      data: {'announcedIp': Uri.parse(Env.apiBaseUrl).host},
    );
    final data = r.data;
    if (data == null) throw StateError('Boş transport yanıtı');
    return MediaTransportInfo.fromJson(data);
  }

  Future<void> connectMediaTransport({
    required String sessionId,
    required String transportId,
    required Map<String, dynamic> dtlsParameters,
  }) async {
    await _dio.post<void>(
      '/interviews/sessions/$sessionId/media/transport/$transportId/connect',
      data: {'dtlsParameters': dtlsParameters},
    );
  }

  Future<String> produceMedia({
    required String sessionId,
    required String transportId,
    required String kind,
    required Map<String, dynamic> rtpParameters,
  }) async {
    final r = await _dio.post<Map<String, dynamic>>(
      '/interviews/sessions/$sessionId/media/transport/$transportId/produce',
      data: {'kind': kind, 'rtpParameters': rtpParameters},
    );
    final data = r.data;
    if (data == null) throw StateError('Boş produce yanıtı');
    return data['id'].toString();
  }

  Future<List<MediaProducerSummary>> listMediaProducers(
    String sessionId,
  ) async {
    final r = await _dio.get<Map<String, dynamic>>(
      '/interviews/sessions/$sessionId/media/producers',
    );
    final data = r.data;
    if (data == null) throw StateError('Boş producers yanıtı');
    final raw = data['producers'] as List<dynamic>? ?? const [];
    return raw
        .map(
          (e) => MediaProducerSummary.fromJson(
            Map<String, dynamic>.from(e as Map),
          ),
        )
        .toList();
  }

  Future<MediaConsumeInfo> consumeMedia({
    required String sessionId,
    required String transportId,
    required String producerId,
    required Map<String, dynamic> rtpCapabilities,
  }) async {
    final r = await _dio.post<Map<String, dynamic>>(
      '/interviews/sessions/$sessionId/media/transport/$transportId/consume',
      data: {'producerId': producerId, 'rtpCapabilities': rtpCapabilities},
    );
    final data = r.data;
    if (data == null) throw StateError('Boş consume yanıtı');
    return MediaConsumeInfo.fromJson(data);
  }

  Future<void> resumeConsumer({
    required String sessionId,
    required String consumerId,
  }) async {
    await _dio.post<void>(
      '/interviews/sessions/$sessionId/media/consumer/$consumerId/resume',
    );
  }
}

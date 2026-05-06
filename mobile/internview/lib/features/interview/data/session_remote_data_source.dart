import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:async';

import '../../../core/models/session_models.dart';
import '../../../core/network/dio_client.dart';

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
}

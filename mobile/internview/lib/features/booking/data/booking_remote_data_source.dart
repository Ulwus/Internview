import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/booking_models.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/models/page_response.dart';
import '../../../core/network/api_envelope.dart';
import '../../../core/network/api_exception.dart';

final bookingRemoteProvider = Provider<BookingRemoteDataSource>(
  (ref) => BookingRemoteDataSource(ref.watch(dioProvider)),
);

class BookingRemoteDataSource {
  BookingRemoteDataSource(this._dio);

  final Dio _dio;

  Future<List<SlotDto>> listOpenSlots(String expertId) async {
    final r = await _dio.get<Map<String, dynamic>>('/availability/$expertId');
    return ApiEnvelope.parseData(
      r.data,
      (j) => (j as List<dynamic>)
          .map((e) => SlotDto.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
    );
  }

  Future<List<SlotDto>> listMySlots() async {
    final r = await _dio.get<Map<String, dynamic>>('/experts/me/availability');
    return ApiEnvelope.parseData(
      r.data,
      (j) => (j as List<dynamic>)
          .map((e) => SlotDto.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
    );
  }

  Future<SlotDto> createMySlot({required DateTime start, required DateTime end}) async {
    try {
      final r = await _dio.post<Map<String, dynamic>>(
        '/experts/me/availability',
        data: {
          'startTime': start.toUtc().toIso8601String(),
          'endTime': end.toUtc().toIso8601String(),
        },
      );
      return ApiEnvelope.parseData(
        r.data,
        (j) => SlotDto.fromJson(Map<String, dynamic>.from(j! as Map)),
      );
    } on DioException catch (e) {
      throw _fromDio(e);
    }
  }

  Future<void> deleteMySlot(String slotId) async {
    try {
      await _dio.delete<void>('/experts/me/availability/$slotId');
    } on DioException catch (e) {
      if (e.response?.statusCode == 409) {
        throw ApiException(
          code: 'CONFLICT',
          message: e.response?.data?.toString() ?? 'Slot silinemiyor (409)',
          statusCode: 409,
        );
      }
      throw _fromDio(e);
    }
  }

  Future<BookingDto> createBooking({required String expertId, required String slotId}) async {
    try {
      final r = await _dio.post<Map<String, dynamic>>(
        '/bookings',
        data: {'expertId': expertId, 'slotId': slotId},
      );
      return ApiEnvelope.parseData(
        r.data,
        (j) => BookingDto.fromJson(Map<String, dynamic>.from(j! as Map)),
      );
    } on DioException catch (e) {
      if (e.response?.statusCode == 409) {
        throw ApiException(
          code: 'BOOKING_SLOT_UNAVAILABLE',
          message: 'Bu zaman dilimi artık uygun değil.',
          statusCode: 409,
        );
      }
      throw _fromDio(e);
    }
  }

  Future<BookingDto> getBooking(String id) async {
    final r = await _dio.get<Map<String, dynamic>>('/bookings/$id');
    return ApiEnvelope.parseData(
      r.data,
      (j) => BookingDto.fromJson(Map<String, dynamic>.from(j! as Map)),
    );
  }

  Future<PageResponse<BookingDto>> listCandidateBookings({int page = 0, int size = 20}) async {
    try {
      final r = await _dio.get<Map<String, dynamic>>(
        '/bookings/me/candidate',
        queryParameters: {'page': page, 'size': size},
      );
      return ApiEnvelope.parseData(
        r.data,
        (j) => PageResponse.fromJson(
          Map<String, dynamic>.from(j! as Map),
          (e) => BookingDto.fromJson(Map<String, dynamic>.from(e as Map)),
        ),
      );
    } on DioException catch (e) {
      throw _fromDio(e);
    }
  }

  Future<PageResponse<BookingDto>> listExpertBookings({int page = 0, int size = 20}) async {
    try {
      final r = await _dio.get<Map<String, dynamic>>(
        '/bookings/me/expert',
        queryParameters: {'page': page, 'size': size},
      );
      return ApiEnvelope.parseData(
        r.data,
        (j) => PageResponse.fromJson(
          Map<String, dynamic>.from(j! as Map),
          (e) => BookingDto.fromJson(Map<String, dynamic>.from(e as Map)),
        ),
      );
    } on DioException catch (e) {
      throw _fromDio(e);
    }
  }

  Future<BookingDto> patchBookingStatus(String id, BookingStatus status) async {
    final r = await _dio.patch<Map<String, dynamic>>(
      '/bookings/$id/status',
      data: {'status': bookingStatusToApi(status)},
    );
    return ApiEnvelope.parseData(
      r.data,
      (j) => BookingDto.fromJson(Map<String, dynamic>.from(j! as Map)),
    );
  }

  Future<BookingDto> approveBooking(String id) async {
    final r = await _dio.post<Map<String, dynamic>>('/bookings/$id/approve');
    return ApiEnvelope.parseData(
      r.data,
      (j) => BookingDto.fromJson(Map<String, dynamic>.from(j! as Map)),
    );
  }

  Future<BookingDto> rejectBooking(String id) async {
    final r = await _dio.post<Map<String, dynamic>>('/bookings/$id/reject');
    return ApiEnvelope.parseData(
      r.data,
      (j) => BookingDto.fromJson(Map<String, dynamic>.from(j! as Map)),
    );
  }

  Future<BookingDto> updateExpertFeedback({
    required String bookingId,
    required int expertRating,
    required String expertComment,
  }) async {
    final r = await _dio.patch<Map<String, dynamic>>(
      '/bookings/$bookingId/feedback',
      data: {
        'expertRating': expertRating,
        'expertComment': expertComment,
      },
    );
    return ApiEnvelope.parseData(
      r.data,
      (j) => BookingDto.fromJson(Map<String, dynamic>.from(j! as Map)),
    );
  }

  ApiException _fromDio(DioException e) {
    final code = e.response?.statusCode;
    final data = e.response?.data;
    if (data is Map) {
      final ae = ApiEnvelope.tryParseError(data);
      if (ae != null) {
        return ApiException(code: ae.code, message: ae.message, statusCode: code);
      }
    }
    return ApiException(
      message: e.message ?? 'Ağ hatası',
      statusCode: code,
    );
  }
}

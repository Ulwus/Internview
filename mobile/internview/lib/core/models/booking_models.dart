class SlotDto {
  SlotDto({
    required this.id,
    required this.expertId,
    required this.startTime,
    required this.endTime,
    required this.booked,
  });

  final String id;
  final String expertId;
  final DateTime startTime;
  final DateTime endTime;
  final bool booked;

  factory SlotDto.fromJson(Map<String, dynamic> j) {
    return SlotDto(
      id: j['id'].toString(),
      expertId: j['expertId'].toString(),
      startTime: DateTime.parse(j['startTime'] as String),
      endTime: DateTime.parse(j['endTime'] as String),
      booked: j['booked'] as bool? ?? false,
    );
  }
}

enum BookingStatus { pending, confirmed, completed, cancelled }

BookingStatus bookingStatusFromString(String? s) {
  switch ((s ?? '').toUpperCase()) {
    case 'CONFIRMED':
      return BookingStatus.confirmed;
    case 'COMPLETED':
      return BookingStatus.completed;
    case 'CANCELLED':
      return BookingStatus.cancelled;
    case 'PENDING':
    default:
      return BookingStatus.pending;
  }
}

String bookingStatusToApi(BookingStatus s) {
  switch (s) {
    case BookingStatus.confirmed:
      return 'CONFIRMED';
    case BookingStatus.completed:
      return 'COMPLETED';
    case BookingStatus.cancelled:
      return 'CANCELLED';
    case BookingStatus.pending:
      return 'PENDING';
  }
}

class BookingDto {
  BookingDto({
    required this.id,
    required this.candidateId,
    required this.expertId,
    required this.slotId,
    required this.status,
    required this.scheduledStart,
    required this.scheduledEnd,
    this.expertRating,
    this.expertComment,
  });

  final String id;
  final String candidateId;
  final String expertId;
  final String slotId;
  final BookingStatus status;
  final DateTime scheduledStart;
  final DateTime scheduledEnd;
  final int? expertRating;
  final String? expertComment;

  factory BookingDto.fromJson(Map<String, dynamic> j) {
    return BookingDto(
      id: j['id'].toString(),
      candidateId: j['candidateId'].toString(),
      expertId: j['expertId'].toString(),
      slotId: j['slotId'].toString(),
      status: bookingStatusFromString(j['status'] as String?),
      scheduledStart: DateTime.parse(j['scheduledStart'] as String),
      scheduledEnd: DateTime.parse(j['scheduledEnd'] as String),
      expertRating: (j['expertRating'] as num?)?.toInt(),
      expertComment: j['expertComment'] as String?,
    );
  }
}

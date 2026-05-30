import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/models/booking_models.dart';

bool joinWindowAllowed(BookingDto b, {DateTime? now}) {
  final n = now ?? DateTime.now();
  final start = b.scheduledStart.toLocal();
  final end = b.scheduledEnd.toLocal();
  return (n.isAfter(start.subtract(const Duration(minutes: 15))) && n.isBefore(end)) ||
      (n.isAfter(start) && n.isBefore(end.add(const Duration(minutes: 5))));
}

int secondsUntilEnd(BookingDto b, {DateTime? now}) {
  final n = now ?? DateTime.now();
  return b.scheduledEnd.toLocal().difference(n).inSeconds;
}

/// Kısa, UI'da gösterilecek CTA metni.
String joinCtaLabel(BookingDto b) {
  switch (b.status) {
    case BookingStatus.pending:
      return 'Onay bekleniyor';
    case BookingStatus.cancelled:
      return 'İptal edildi';
    case BookingStatus.completed:
      return 'Tamamlandı';
    case BookingStatus.confirmed:
      final n = DateTime.now();
      final start = b.scheduledStart.toLocal();
      final end = b.scheduledEnd.toLocal();

      // Seans saati geçtiyse "zamanı gelmedi" demeyelim.
      if (end.isBefore(n)) return 'Geçmiş';

      final canJoin = joinWindowAllowed(b);
      if (canJoin) {
        final secs = secondsUntilEnd(b);
        if (secs <= 60 && secs >= 0) return 'Son $secs sn';
        return 'Katıl';
      }
      if (start.isAfter(n) && start.isBefore(n.add(const Duration(days: 7)))) {
        final days = start.difference(DateTime(n.year, n.month, n.day)).inDays;
        if (days <= 0) return 'Yakında';
        return 'Yakında ($days gün)';
      }
      return 'Zamanı gelmedi';
  }
}

String formatBookingWhen(BookingDto b) {
  final start = b.scheduledStart.toLocal();
  final end = b.scheduledEnd.toLocal();

  final day = DateFormat('d MMM', 'tr_TR').format(start); // 7 May
  final dow = DateFormat('EEE', 'tr_TR').format(start); // Per
  final startTime = DateFormat('HH:mm', 'tr_TR').format(start);
  final endTime = DateFormat('HH:mm', 'tr_TR').format(end);

  return '$dow, $day • $startTime–$endTime';
}

String bookingStatusMiniLabel(BookingDto b) {
  final now = DateTime.now();
  switch (b.status) {
    case BookingStatus.pending:
      return 'Bekliyor';
    case BookingStatus.cancelled:
      return 'İptal';
    case BookingStatus.completed:
      return 'Bitti';
    case BookingStatus.confirmed:
      if (joinWindowAllowed(b, now: now)) return 'Canlı';
      if (b.scheduledEnd.toLocal().isBefore(now)) return 'Geçmiş';
      return 'Onaylı';
  }
}

Widget bookingStatusChip(BookingStatus status) {
  final (label, color) = switch (status) {
    BookingStatus.pending => ('Bekliyor', Colors.amber),
    BookingStatus.confirmed => ('Onaylı', Colors.green),
    BookingStatus.completed => ('Bitti', Colors.blueGrey),
    BookingStatus.cancelled => ('İptal', Colors.redAccent),
  };

  return Chip(
    label: Text(label),
    backgroundColor: color.withValues(alpha: 0.15),
    side: BorderSide(color: color.withValues(alpha: 0.35)),
    labelStyle: TextStyle(color: color.withValues(alpha: 0.9), fontWeight: FontWeight.w700),
    padding: const EdgeInsets.symmetric(horizontal: 6),
    visualDensity: VisualDensity.compact,
  );
}


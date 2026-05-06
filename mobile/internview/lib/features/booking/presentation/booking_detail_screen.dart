import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/models/booking_models.dart';
import '../../../core/network/api_exception.dart';
import '../../auth/controllers/auth_controller.dart';
import '../data/booking_remote_data_source.dart';

final bookingDetailProvider = FutureProvider.family.autoDispose<BookingDto, String>((ref, id) {
  return ref.watch(bookingRemoteProvider).getBooking(id);
});

class BookingDetailScreen extends ConsumerWidget {
  const BookingDetailScreen({super.key, required this.bookingId});

  final String bookingId;

  static bool _canJoinInterview(BookingDto b) {
    final now = DateTime.now();
    final start = b.scheduledStart.toLocal();
    final end = b.scheduledEnd.toLocal();
    return (now.isAfter(start.subtract(const Duration(minutes: 15))) && now.isBefore(end)) ||
        (now.isAfter(start) && now.isBefore(end.add(const Duration(minutes: 5))));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final b = ref.watch(bookingDetailProvider(bookingId));
    final auth = ref.watch(authControllerProvider);
    final isExpert = auth?.role.toUpperCase() == 'EXPERT';

    return Scaffold(
      appBar: AppBar(title: const Text('Randevu')),
      body: b.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (booking) {
          final canJoin = _canJoinInterview(booking);
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Durum: ${booking.status.name}'),
                Text('Başlangıç: ${booking.scheduledStart.toLocal()}'),
                Text('Bitiş: ${booking.scheduledEnd.toLocal()}'),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: canJoin ? () => context.push('/interview/$bookingId') : null,
                  child: const Text('Mülakata katıl'),
                ),
                const SizedBox(height: 12),
                if (booking.status != BookingStatus.cancelled &&
                    booking.status != BookingStatus.completed) ...[
                  OutlinedButton(
                    onPressed: () async {
                      try {
                        await ref.read(bookingRemoteProvider).patchBookingStatus(
                              booking.id,
                              BookingStatus.cancelled,
                            );
                        ref.invalidate(bookingDetailProvider(bookingId));
                      } on ApiException catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
                        }
                      }
                    },
                    child: const Text('İptal et'),
                  ),
                  if (isExpert) ...[
                    const SizedBox(height: 12),
                    OutlinedButton(
                      onPressed: () async {
                        try {
                          await ref.read(bookingRemoteProvider).patchBookingStatus(
                                booking.id,
                                BookingStatus.completed,
                              );
                          ref.invalidate(bookingDetailProvider(bookingId));
                        } on ApiException catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
                          }
                        }
                      },
                      child: const Text('Tamamlandı olarak işaretle'),
                    ),
                  ],
                ],
                TextButton(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('AI mülakat raporu backend’de planlı — yakında.')),
                    );
                  },
                  child: const Text('AI mülakat raporu (yakında)'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

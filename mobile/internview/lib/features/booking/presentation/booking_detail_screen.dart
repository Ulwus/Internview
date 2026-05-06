import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'dart:async';

import '../../../core/models/booking_models.dart';
import '../../../core/network/api_exception.dart';
import '../../auth/controllers/auth_controller.dart';
import '../data/booking_remote_data_source.dart';
import 'booking_ui_helpers.dart';

final bookingDetailProvider = FutureProvider.family.autoDispose<BookingDto, String>((ref, id) {
  return ref.watch(bookingRemoteProvider).getBooking(id);
});

class BookingDetailScreen extends ConsumerStatefulWidget {
  const BookingDetailScreen({super.key, required this.bookingId});

  final String bookingId;

  @override
  ConsumerState<BookingDetailScreen> createState() => _BookingDetailScreenState();
}

class _BookingDetailScreenState extends ConsumerState<BookingDetailScreen> with WidgetsBindingObserver {
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _startPolling();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.invalidate(bookingDetailProvider(widget.bookingId));
      _startPolling();
    } else if (state == AppLifecycleState.paused) {
      _pollTimer?.cancel();
      _pollTimer = null;
    }
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted) return;
      ref.invalidate(bookingDetailProvider(widget.bookingId));
    });
  }

  @override
  Widget build(BuildContext context) {
    final bookingId = widget.bookingId;
    final b = ref.watch(bookingDetailProvider(bookingId));
    final auth = ref.watch(authControllerProvider);
    final isExpert = auth?.role.toUpperCase() == 'EXPERT';

    return Scaffold(
      appBar: AppBar(title: const Text('Randevu')),
      body: b.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (booking) {
          final canJoin = joinWindowAllowed(booking) && booking.status == BookingStatus.confirmed;
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Randevu', style: Theme.of(context).textTheme.titleLarge),
                    bookingStatusChip(booking.status),
                  ],
                ),
                const SizedBox(height: 12),
                Text('Başlangıç: ${booking.scheduledStart.toLocal()}'),
                Text('Bitiş: ${booking.scheduledEnd.toLocal()}'),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: canJoin ? () => context.push('/interview/$bookingId') : null,
                  child: Text(joinCtaLabel(booking)),
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
                  if (isExpert && booking.status == BookingStatus.pending) ...[
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: () async {
                        try {
                          await ref.read(bookingRemoteProvider).approveBooking(booking.id);
                          ref.invalidate(bookingDetailProvider(bookingId));
                        } on ApiException catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
                          }
                        }
                      },
                      child: const Text('Onayla'),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton(
                      onPressed: () async {
                        try {
                          await ref.read(bookingRemoteProvider).rejectBooking(booking.id);
                          ref.invalidate(bookingDetailProvider(bookingId));
                        } on ApiException catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
                          }
                        }
                      },
                      child: const Text('Reddet'),
                    ),
                  ] else if (isExpert) ...[
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
                    context.push('/interview/${booking.id}/result');
                  },
                  child: const Text('Mülakat sonucu'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

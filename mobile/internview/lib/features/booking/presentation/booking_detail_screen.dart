import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'dart:async';

import '../../../core/models/booking_models.dart';
import '../../../core/models/domain_models.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/presentation/widgets/neo/neo_background.dart';
import '../../../core/presentation/widgets/penkrowd/action_group.dart';
import '../../../core/presentation/widgets/penkrowd/detail_header_card.dart';
import '../../../core/presentation/widgets/penkrowd/section_card.dart';
import '../../../core/presentation/widgets/penkrowd/skeleton_container.dart';
import '../../auth/controllers/auth_controller.dart';
import '../../profile/data/profile_remote_data_source.dart';
import '../data/booking_remote_data_source.dart';
import 'booking_ui_helpers.dart';

final bookingDetailProvider = FutureProvider.family.autoDispose<BookingDto, String>((ref, id) {
  return ref.watch(bookingRemoteProvider).getBooking(id);
});

final _profileRemoteProvider = Provider<ProfileRemoteDataSource>(
  (ref) => ProfileRemoteDataSource(ref.watch(dioProvider)),
);

final _otherUserProvider = FutureProvider.family.autoDispose<UserProfile, ({String bookingId, bool isExpert})>(
  (ref, args) async {
    final b = await ref.watch(bookingDetailProvider(args.bookingId).future);
    final otherId = args.isExpert ? b.candidateId : b.expertId;
    return ref.watch(_profileRemoteProvider).getUserById(otherId);
  },
);

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

    return NeoBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(title: const Text('Randevu')),
        body: b.when(
          loading: () => const Center(child: SkeletonContainer(width: 220, height: 14, borderRadius: 8)),
          error: (e, _) => Center(child: Text('$e')),
          data: (booking) {
            final canJoin = joinWindowAllowed(booking) && booking.status == BookingStatus.confirmed;
            final other = ref.watch(_otherUserProvider((bookingId: bookingId, isExpert: isExpert)));
            final whenText = formatBookingWhen(booking);

            final primary = () {
              if (isExpert && booking.status == BookingStatus.pending) {
                return primaryAction(
                  label: 'Onayla',
                  color: const Color(0xFFFF9100),
                  onTap: () async {
                    try {
                      await ref.read(bookingRemoteProvider).approveBooking(booking.id);
                      ref.invalidate(bookingDetailProvider(bookingId));
                    } on ApiException catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
                      }
                    }
                  },
                );
              }
              return primaryAction(
                label: joinCtaLabel(booking),
                onTap: canJoin ? () => context.push('/interview/$bookingId') : null,
                color: const Color(0xFF00E5FF),
              );
            }();

            final secondary = <ActionSpec>[
              // Pending'de "iptal" sadece aday tarafında anlamlı.
              if (!isExpert && booking.status == BookingStatus.pending)
                secondaryAction(
                  label: 'Talebi iptal et',
                  onTap: () async {
                    try {
                      await ref.read(bookingRemoteProvider).patchBookingStatus(booking.id, BookingStatus.cancelled);
                      ref.invalidate(bookingDetailProvider(bookingId));
                    } on ApiException catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
                      }
                    }
                  },
                ),
              // Confirmed durumda iki taraf da iptal edebilir (tamamlandı/iptal hariç).
              if (booking.status == BookingStatus.confirmed)
                secondaryAction(
                  label: 'İptal et',
                  onTap: () async {
                    try {
                      await ref.read(bookingRemoteProvider).patchBookingStatus(booking.id, BookingStatus.cancelled);
                      ref.invalidate(bookingDetailProvider(bookingId));
                    } on ApiException catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
                      }
                    }
                  },
                ),
              if (isExpert && booking.status == BookingStatus.pending)
                secondaryAction(
                  label: 'Reddet',
                  onTap: () async {
                    try {
                      await ref.read(bookingRemoteProvider).rejectBooking(booking.id);
                      ref.invalidate(bookingDetailProvider(bookingId));
                    } on ApiException catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
                      }
                    }
                  },
                ),
              if (isExpert && booking.status == BookingStatus.confirmed)
                secondaryAction(
                  label: 'Tamamlandı olarak işaretle',
                  onTap: () async {
                    try {
                      await ref.read(bookingRemoteProvider).patchBookingStatus(booking.id, BookingStatus.completed);
                      ref.invalidate(bookingDetailProvider(bookingId));
                    } on ApiException catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
                      }
                    }
                  },
                ),
              if (booking.status == BookingStatus.completed)
                secondaryAction(
                  label: 'Mülakat sonucu',
                  onTap: () => context.push('/interview/${booking.id}/result'),
                ),
            ];

            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                other.when(
                  loading: () => const SkeletonContainer(width: double.infinity, height: 74, borderRadius: 18),
                  error: (e, _) => DetailHeaderCard(
                    title: 'Randevu',
                    subtitle: whenText,
                    statusChip: bookingStatusChip(booking.status),
                    accentColor: const Color(0xFFB388FF),
                  ),
                  data: (u) => DetailHeaderCard(
                    title: '${u.firstName} ${u.lastName}'.trim(),
                    subtitle: whenText,
                    statusChip: bookingStatusChip(booking.status),
                    avatarUrl: u.avatarUrl,
                    fallbackLetter: (u.firstName.isNotEmpty ? u.firstName[0] : '?'),
                    accentColor: const Color(0xFFB388FF),
                  ),
                ),
                const SizedBox(height: 12),
                SectionCard(
                  title: 'Zaman',
                  subtitle: 'Randevu saatini kontrol et',
                  color: const Color(0xFFFFD600),
                  child: Text(
                    whenText,
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
                const SizedBox(height: 12),
                SectionCard(
                  title: 'Aksiyonlar',
                  subtitle: isExpert ? 'Talebi değerlendir veya seansa katıl' : 'Seansa katılmadan önce onay beklenir',
                  color: Theme.of(context).colorScheme.surface,
                  child: ActionGroup(primary: primary, secondary: secondary),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

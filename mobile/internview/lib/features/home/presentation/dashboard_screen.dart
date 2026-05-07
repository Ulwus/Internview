import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/presentation/widgets/neo/neo_background.dart';
import '../../../core/presentation/widgets/neo/neo_box.dart';
import '../../../core/presentation/widgets/penkrowd/animated_action_button.dart';
import '../../../core/presentation/widgets/penkrowd/penkrowd_card.dart';
import '../../../core/presentation/widgets/penkrowd/skeleton_container.dart';
import '../../../core/presentation/widgets/penkrowd/radial_stat_gauge.dart';
import '../../../core/network/dio_client.dart';
import '../../auth/controllers/auth_controller.dart';
import '../../booking/data/booking_remote_data_source.dart';
import '../../booking/presentation/booking_ui_helpers.dart';
import '../../../core/models/booking_models.dart';
import '../../expert/data/expert_remote_data_source.dart';
import '../../profile/data/profile_remote_data_source.dart';
import '../../marketplace/data/marketplace_remote_data_source.dart';
import '../../../core/models/shop_models.dart';

final _candidateBookingsPreviewProvider = FutureProvider.autoDispose((
  ref,
) async {
  return ref
      .watch(bookingRemoteProvider)
      .listCandidateBookings(page: 0, size: 50);
});

final _expertBookingsPreviewProvider = FutureProvider.autoDispose((ref) async {
  return ref.watch(bookingRemoteProvider).listExpertBookings(page: 0, size: 20);
});

final _dashboardExpertRemoteDsProvider = Provider<ExpertRemoteDataSource>(
  (ref) => ExpertRemoteDataSource(ref.watch(dioProvider)),
);

final _dashboardProfileRemoteDsProvider = Provider<ProfileRemoteDataSource>(
  (ref) => ProfileRemoteDataSource(ref.watch(dioProvider)),
);

final _dashboardUserByIdProvider = FutureProvider.family((
  ref,
  String userId,
) async {
  return ref.read(_dashboardProfileRemoteDsProvider).getUserById(userId);
});

final _dashboardMyShopProvider = FutureProvider.autoDispose<ShopSummaryDto?>((
  ref,
) async {
  return ref.watch(marketplaceRemoteProvider).getMyShop();
});

final _dashboardMySlotsProvider = FutureProvider.autoDispose<List<SlotDto>>((
  ref,
) async {
  final me = await ref.watch(_dashboardExpertMeProvider.future);
  return ref.read(bookingRemoteProvider).listOpenSlots(me.userId);
});

final _dashboardExpertByUserIdProvider = FutureProvider.family((
  ref,
  String userId,
) async {
  return ref.read(_dashboardExpertRemoteDsProvider).getExpertByUserId(userId);
});

final _dashboardExpertMeProvider = FutureProvider.autoDispose((ref) async {
  return ref.read(_dashboardExpertRemoteDsProvider).getExpertMe();
});

final _dashboardCandidateAvgRatingProvider =
    FutureProvider.autoDispose<double?>((ref) async {
      final page = await ref
          .read(bookingRemoteProvider)
          .listCandidateBookings(page: 0, size: 50);
      final ratings = page.items
          .map((b) => b.expertRating)
          .whereType<int>()
          .toList();
      if (ratings.isEmpty) return null;
      final avg = ratings.reduce((a, b) => a + b) / ratings.length;
      return avg.toDouble();
    });

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  bool _hasUpcomingConfirmed(List<BookingDto> items) {
    final now = DateTime.now();
    return items.any(
      (b) =>
          b.status == BookingStatus.confirmed &&
          b.scheduledEnd.toLocal().isAfter(now),
    );
  }

  Widget _ctaButton({
    required String label,
    required VoidCallback onTap,
    bool enabled = true,
  }) {
    return Opacity(
      opacity: enabled ? 1 : 0.75,
      child: IgnorePointer(
        ignoring: !enabled,
        child: AnimatedActionButton(
          onTap: onTap,
          width: double.infinity,
          height: 48,
          color: Colors.white,
          pressedColor: Colors.white,
          borderColor: Colors.black,
          borderWidth: 3,
          borderRadius: 14,
          shadowOffset: const Offset(4, 4),
          child: Center(
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 16,
                color: Colors.black,
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);
    final isExpert = auth?.role.toUpperCase() == 'EXPERT';
    final theme = Theme.of(context);
    final candidateBookings = isExpert
        ? null
        : ref.watch(_candidateBookingsPreviewProvider);

    return NeoBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text('Internview'),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 16.0),
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: theme.colorScheme.secondary,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.black, width: 3),
                ),
                child: const Icon(Icons.person, color: Colors.black),
              ),
            ),
          ],
        ),
        body: LayoutBuilder(
          builder: (context, constraints) {
            return CustomScrollView(
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.all(16),
                  sliver: SliverToBoxAdapter(
                    child: isExpert
                        ? const _DashboardExpertTopCard()
                        : const _DashboardCandidateTopCard(),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  sliver: SliverFillRemaining(
                    hasScrollBody: false,
                    child: Column(
                      children: [
                        Expanded(
                          child: NeoBox(
                            color: const Color(0xFFB388FF), // Purple
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  isExpert ? 'Onay Bekleyen' : 'Geçmiş Mülakat',
                                  style: theme.textTheme.titleLarge,
                                ),
                                if (isExpert) ...[
                                  const SizedBox(height: 8),
                                  const _PendingApprovalsHeader(),
                                ],
                                const SizedBox(height: 10),
                                Expanded(
                                  child: isExpert
                                      ? const _PendingApprovalsPreview()
                                      : const _PastInterviewsPreview(),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        if (isExpert)
                          Expanded(
                            child: NeoBox(
                              color: const Color(0xFFFF9100), // Orange
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Dükkanım',
                                    style: theme.textTheme.titleLarge,
                                  ),
                                  const SizedBox(height: 12),
                                  const _MyShopSummaryCard(),
                                ],
                              ),
                            ),
                          )
                        else
                          candidateBookings!.when(
                            loading: () => Expanded(
                              child: NeoBox(
                                color: const Color(0xFFFF9100),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Yeni Randevu',
                                      style: theme.textTheme.titleLarge,
                                    ),
                                    const SizedBox(height: 16),
                                    _ctaButton(
                                      label: 'Aç',
                                      onTap: () =>
                                          context.push('/booking/create'),
                                    ),
                                    const Spacer(),
                                  ],
                                ),
                              ),
                            ),
                            error: (_, __) => Expanded(
                              child: NeoBox(
                                color: const Color(0xFFFF9100),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Yeni Randevu',
                                      style: theme.textTheme.titleLarge,
                                    ),
                                    const SizedBox(height: 16),
                                    _ctaButton(
                                      label: 'Aç',
                                      onTap: () =>
                                          context.push('/booking/create'),
                                    ),
                                    const Spacer(),
                                  ],
                                ),
                              ),
                            ),
                            data: (page) {
                              final showBottomNewBooking =
                                  _hasUpcomingConfirmed(page.items);
                              if (!showBottomNewBooking)
                                return const SizedBox.shrink();
                              return Expanded(
                                child: NeoBox(
                                  color: const Color(0xFFFF9100), // Orange
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Yeni Randevu',
                                        style: theme.textTheme.titleLarge,
                                      ),
                                      const SizedBox(height: 16),
                                      _ctaButton(
                                        label: 'Aç',
                                        onTap: () =>
                                            context.push('/booking/create'),
                                      ),
                                      const Spacer(),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        SizedBox(
                          height: MediaQuery.of(context).padding.bottom + 12,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _DashboardCandidateTopCard extends ConsumerWidget {
  const _DashboardCandidateTopCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final bookings = ref.watch(_candidateBookingsPreviewProvider);
    final avgRating = ref.watch(_dashboardCandidateAvgRatingProvider);
    return NeoBox(
      color: theme.colorScheme.tertiary,
      child: bookings.when(
        loading: () => const SizedBox(
          height: 120,
          child: Center(
            child: SkeletonContainer(width: 220, height: 14, borderRadius: 8),
          ),
        ),
        error: (e, _) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Sıradaki randevu', style: theme.textTheme.titleLarge),
            const SizedBox(height: 8),
            Text('$e'),
          ],
        ),
        data: (page) {
          final now = DateTime.now();
          final upcomingConfirmed =
              page.items
                  .where(
                    (b) =>
                        b.status == BookingStatus.confirmed &&
                        b.scheduledEnd.toLocal().isAfter(now),
                  )
                  .toList()
                ..sort((a, b) => a.scheduledStart.compareTo(b.scheduledStart));
          final next = upcomingConfirmed.isNotEmpty
              ? upcomingConfirmed.first
              : null;

          if (next == null) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    avgRating.when(
                      data: (v) =>
                          RadialStatGauge(value: v, max: 10, label: 'Puan'),
                      loading: () => const SkeletonContainer(
                        width: 82,
                        height: 82,
                        borderRadius: 18,
                      ),
                      error: (_, __) => const RadialStatGauge(
                        value: null,
                        max: 10,
                        label: 'Puan',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Herhangi bir randevun yok',
                            style: theme.textTheme.titleLarge,
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Yeni bir randevu oluşturup uzman seçebilirsin.',
                          ),
                          const SizedBox(height: 12),
                          AnimatedActionButton(
                            onTap: () => context.push('/booking/create'),
                            width: double.infinity,
                            height: 48,
                            color: Colors.white,
                            pressedColor: Colors.white,
                            borderWidth: 3,
                            borderRadius: 14,
                            shadowOffset: const Offset(4, 4),
                            child: const Center(
                              child: Text(
                                'Yeni randevu',
                                style: TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 16,
                                  color: Colors.black,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
              ],
            );
          }
          final canJoin = joinWindowAllowed(next);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  avgRating.when(
                    data: (v) =>
                        RadialStatGauge(value: v, max: 10, label: 'Puan'),
                    loading: () => const SkeletonContainer(
                      width: 82,
                      height: 82,
                      borderRadius: 18,
                    ),
                    error: (_, __) => const RadialStatGauge(
                      value: null,
                      max: 10,
                      label: 'Puan',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Sıradaki randevu',
                          style: theme.textTheme.titleLarge,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          formatBookingWhen(next),
                          style: theme.textTheme.bodyLarge,
                        ),
                        const SizedBox(height: 12),
                        AnimatedActionButton(
                          onTap: () => context.push(
                            canJoin
                                ? '/interview/${next.id}'
                                : '/booking/${next.id}',
                          ),
                          width: double.infinity,
                          height: 48,
                          color: Colors.white,
                          pressedColor: Colors.white,
                          borderWidth: 3,
                          borderRadius: 14,
                          shadowOffset: const Offset(4, 4),
                          child: Center(
                            child: Text(
                              joinCtaLabel(next),
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 16,
                                color: Colors.black,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class _DashboardExpertTopCard extends ConsumerWidget {
  const _DashboardExpertTopCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final bookings = ref.watch(_expertBookingsPreviewProvider);
    final me = ref.watch(_dashboardExpertMeProvider);
    return NeoBox(
      color: theme.colorScheme.tertiary,
      child: bookings.when(
        loading: () => const SizedBox(
          height: 120,
          child: Center(
            child: SkeletonContainer(width: 220, height: 14, borderRadius: 8),
          ),
        ),
        error: (e, _) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Sıradaki seans', style: theme.textTheme.titleLarge),
            const SizedBox(height: 8),
            Text('$e'),
          ],
        ),
        data: (page) {
          final confirmed = page.items
              .where((b) => b.status.name.toUpperCase() == 'CONFIRMED')
              .toList();
          confirmed.sort(
            (a, b) => a.scheduledStart.compareTo(b.scheduledStart),
          );
          if (confirmed.isEmpty) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    me.when(
                      data: (d) => RadialStatGauge(
                        value: d.averageRating,
                        max: 10,
                        label: 'Ortalama\npuan',
                        accentColor: const Color(0xFFB388FF),
                      ),
                      loading: () => const SkeletonContainer(
                        width: 82,
                        height: 82,
                        borderRadius: 18,
                      ),
                      error: (_, __) => const RadialStatGauge(
                        value: null,
                        max: 10,
                        label: 'Ortalama\npuan',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Sıradaki seans',
                            style: theme.textTheme.titleLarge,
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Henüz onaylı seans yok. Dükkanından müsaitlik ekleyebilirsin.',
                          ),
                          const SizedBox(height: 12),
                          AnimatedActionButton(
                            onTap: () => context.push('/expert-self'),
                            width: double.infinity,
                            height: 48,
                            color: Colors.white,
                            pressedColor: Colors.white,
                            borderWidth: 3,
                            borderRadius: 14,
                            shadowOffset: const Offset(4, 4),
                            child: const Center(
                              child: Text(
                                'İstatistikler',
                                style: TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 16,
                                  color: Colors.black,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            );
          }
          final next = confirmed.first;
          final canJoin =
              joinWindowAllowed(next) &&
              next.status.name.toUpperCase() == 'CONFIRMED';
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  me.when(
                    data: (d) => RadialStatGauge(
                      value: d.averageRating,
                      max: 10,
                      label: 'Ortalama\npuan',
                      accentColor: const Color(0xFFB388FF),
                    ),
                    loading: () => const SkeletonContainer(
                      width: 82,
                      height: 82,
                      borderRadius: 18,
                    ),
                    error: (_, __) => const RadialStatGauge(
                      value: null,
                      max: 10,
                      label: 'Ortalama\npuan',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Sıradaki seans',
                          style: theme.textTheme.titleLarge,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          formatBookingWhen(next),
                          style: theme.textTheme.bodyLarge,
                        ),
                        const SizedBox(height: 12),
                        AnimatedActionButton(
                          onTap: () => context.push(
                            canJoin
                                ? '/interview/${next.id}'
                                : '/booking/${next.id}',
                          ),
                          width: double.infinity,
                          height: 48,
                          color: Colors.white,
                          pressedColor: Colors.white,
                          borderWidth: 3,
                          borderRadius: 14,
                          shadowOffset: const Offset(4, 4),
                          child: Center(
                            child: Text(
                              joinCtaLabel(next),
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 16,
                                color: Colors.black,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class _PastInterviewsPreview extends ConsumerWidget {
  const _PastInterviewsPreview();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookings = ref.watch(_candidateBookingsPreviewProvider);
    return bookings.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: SkeletonContainer(
          width: double.infinity,
          height: 12,
          borderRadius: 8,
        ),
      ),
      error: (e, _) => Text('$e'),
      data: (page) {
        final now = DateTime.now();
        final past = page.items.where((b) {
          if (b.status == BookingStatus.completed) return true;
          if (b.status == BookingStatus.cancelled) return true;
          if (b.status == BookingStatus.confirmed &&
              b.scheduledEnd.toLocal().isBefore(now))
            return true;
          return false;
        }).toList()..sort((a, b) => b.scheduledEnd.compareTo(a.scheduledEnd));

        if (past.isEmpty) return const Text('Henüz geçmiş mülakat yok.');
        final b = past.first;
        final accent = switch (b.status) {
          BookingStatus.pending => const Color(0xFFFF9100),
          BookingStatus.confirmed => const Color(0xFF00E5FF),
          BookingStatus.completed => const Color(0xFFB388FF),
          BookingStatus.cancelled => const Color(0xFFFF5252),
        };
        final expertAsync = ref.watch(
          _dashboardExpertByUserIdProvider(b.expertId),
        );
        return Column(
          children: [
            PenkrowdCard(
              accentColor: accent,
              leading: expertAsync.when(
                data: (e) => CircleAvatar(
                  radius: 18,
                  backgroundColor: Colors.white,
                  backgroundImage:
                      (e.avatarUrl != null && e.avatarUrl!.isNotEmpty)
                      ? NetworkImage(e.avatarUrl!)
                      : null,
                  child: (e.avatarUrl == null || e.avatarUrl!.isEmpty)
                      ? Text(
                          (e.firstName.isNotEmpty ? e.firstName[0] : '?')
                              .toUpperCase(),
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            color: Colors.black,
                          ),
                        )
                      : null,
                ),
                loading: () => const SkeletonContainer(
                  width: 36,
                  height: 36,
                  borderRadius: 18,
                ),
                error: (_, __) => const CircleAvatar(
                  radius: 18,
                  backgroundColor: Colors.white,
                  child: Text(
                    '?',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      color: Colors.black,
                    ),
                  ),
                ),
              ),
              title: expertAsync.when(
                data: (e) => Text(
                  '${e.firstName} ${e.lastName}',
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
                loading: () => const SkeletonContainer(
                  width: 140,
                  height: 12,
                  borderRadius: 8,
                ),
                error: (_, __) => const Text('Mülakat'),
              ),
              subtitle: expertAsync.when(
                data: (e) => Text(
                  [
                    formatBookingWhen(b),
                    if (e.industry?.name.isNotEmpty == true) e.industry!.name,
                  ].join(' • '),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                loading: () => const SkeletonContainer(
                  width: 170,
                  height: 12,
                  borderRadius: 8,
                ),
                error: (_, __) => Text(
                  formatBookingWhen(b),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              onTap: () => context.push('/interview/${b.id}/result'),
              trailing: const Icon(Icons.chevron_right, color: Colors.black),
            ),
          ],
        );
      },
    );
  }
}

class _PendingApprovalsPreview extends ConsumerWidget {
  const _PendingApprovalsPreview();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookings = ref.watch(_expertBookingsPreviewProvider);
    return bookings.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: SkeletonContainer(
          width: double.infinity,
          height: 12,
          borderRadius: 8,
        ),
      ),
      error: (e, _) => Text('$e'),
      data: (page) {
        final pending = page.items
            .where((b) => b.status == BookingStatus.pending)
            .toList();
        if (pending.isEmpty) return const Text('Onay bekleyen talep yok.');
        final first = pending.first;
        return Align(
          alignment: Alignment.topLeft,
          child: _PendingApprovalCard(booking: first),
        );
      },
    );
  }
}

class _PendingApprovalsHeader extends ConsumerWidget {
  const _PendingApprovalsHeader();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookings = ref.watch(_expertBookingsPreviewProvider);
    final count = bookings.valueOrNull?.items
        .where((b) => b.status == BookingStatus.pending)
        .length;
    final label = (count == null) ? '…' : count.toString();

    return AnimatedActionButton(
      onTap: () => context.push('/bookings?asExpert=1&tab=pending'),
      width: double.infinity,
      height: 42,
      color: Colors.white,
      pressedColor: Colors.white,
      borderColor: Colors.black,
      borderWidth: 2,
      borderRadius: 14,
      shadowOffset: const Offset(3, 3),
      child: Row(
        children: [
          const SizedBox(width: 12),
          const Icon(
            Icons.hourglass_top_rounded,
            color: Colors.black,
            size: 18,
          ),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'Bekleyen talepler',
              style: TextStyle(
                fontWeight: FontWeight.w900,
                color: Colors.black,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: const Color(0xFFFF9100),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.black, width: 2),
            ),
            alignment: Alignment.center,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 12,
                color: Colors.black,
              ),
            ),
          ),
          const SizedBox(width: 10),
          const Icon(Icons.chevron_right, color: Colors.black),
          const SizedBox(width: 8),
        ],
      ),
    );
  }
}

class _PendingApprovalCard extends ConsumerWidget {
  const _PendingApprovalCard({required this.booking});

  final BookingDto booking;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final u = ref.watch(_dashboardUserByIdProvider(booking.candidateId));
    final whenText = formatBookingWhen(booking);
    return PenkrowdCard(
      accentColor: const Color(0xFFFF9100),
      accentWidth: 18,
      leading: u.when(
        data: (p) => CircleAvatar(
          radius: 18,
          backgroundColor: Colors.white,
          backgroundImage: (p.avatarUrl != null && p.avatarUrl!.isNotEmpty)
              ? NetworkImage(p.avatarUrl!)
              : null,
          child: (p.avatarUrl == null || p.avatarUrl!.isEmpty)
              ? Text(
                  (p.firstName.isNotEmpty ? p.firstName[0] : '?').toUpperCase(),
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    color: Colors.black,
                  ),
                )
              : null,
        ),
        loading: () =>
            const SkeletonContainer(width: 36, height: 36, borderRadius: 18),
        error: (e, _) => const CircleAvatar(
          radius: 18,
          backgroundColor: Colors.white,
          child: Text(
            '?',
            style: TextStyle(fontWeight: FontWeight.w900, color: Colors.black),
          ),
        ),
      ),
      title: u.when(
        data: (p) => Text(
          '${p.firstName} ${p.lastName}'.trim().isEmpty
              ? 'Aday'
              : '${p.firstName} ${p.lastName}',
          overflow: TextOverflow.ellipsis,
          maxLines: 1,
        ),
        loading: () =>
            const SkeletonContainer(width: 140, height: 12, borderRadius: 8),
        error: (e, _) => const Text('Talep'),
      ),
      subtitle: Text(whenText, overflow: TextOverflow.ellipsis, maxLines: 1),
      trailing: const Icon(Icons.chevron_right, color: Colors.black),
      onTap: () => context.push('/booking/${booking.id}'),
    );
  }
}

class _MyShopSummaryCard extends ConsumerWidget {
  const _MyShopSummaryCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shop = ref.watch(_dashboardMyShopProvider);
    final slots = ref.watch(_dashboardMySlotsProvider);

    return shop.when(
      loading: () => const Padding(
        padding: EdgeInsets.only(top: 6),
        child: SkeletonContainer(
          width: double.infinity,
          height: 74,
          borderRadius: 18,
        ),
      ),
      error: (e, _) => PenkrowdCard(
        accentColor: const Color(0xFFFF5252),
        title: const Text('Dükkan yüklenemedi'),
        subtitle: Text(
          e.toString(),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: const Icon(Icons.chevron_right, color: Colors.black),
        onTap: () => context.push('/shop-me'),
      ),
      data: (s) {
        if (s == null) {
          return PenkrowdCard(
            accentColor: const Color(0xFF00E5FF),
            title: const Text('İlan oluştur'),
            subtitle: const Text('Dükkanını yayına al ve müsaitlik ekle.'),
            trailing: const Icon(Icons.chevron_right, color: Colors.black),
            onTap: () => context.push('/shop-me'),
          );
        }

        final industry = s.industry?.name;
        final price = (s.hourlyRate != null)
            ? '${s.hourlyRate} ${s.currency ?? ''}'
            : null;
        final meta = [
          if (industry != null && industry.isNotEmpty) industry,
          if (price != null && price.trim().isNotEmpty) price,
          (s.isPublished) ? 'Yayında' : 'Taslak',
        ].join(' • ');

        final openCount = slots.valueOrNull?.where((x) => !x.booked).length;

        return PenkrowdCard(
          accentColor: const Color(0xFF00E5FF),
          leading: CircleAvatar(
            radius: 18,
            backgroundColor: Colors.white,
            backgroundImage:
                (s.expertAvatarUrl != null && s.expertAvatarUrl!.isNotEmpty)
                ? NetworkImage(s.expertAvatarUrl!)
                : null,
            child: (s.expertAvatarUrl == null || s.expertAvatarUrl!.isEmpty)
                ? Text(
                    (s.expertFirstName.isNotEmpty ? s.expertFirstName[0] : '?')
                        .toUpperCase(),
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      color: Colors.black,
                    ),
                  )
                : null,
          ),
          title: Text(
            s.expertFullName,
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
          subtitle: Text(meta, overflow: TextOverflow.ellipsis, maxLines: 2),
          trailing: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              RadialStatGauge(
                value: s.averageRating,
                max: 10,
                label: 'Puan',
                size: 62,
                accentColor: const Color(0xFFB388FF),
              ),
              const SizedBox(height: 6),
              Text(
                (openCount == null) ? '…' : 'Müsait: $openCount',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 11,
                  color: Colors.black.withValues(alpha: 0.65),
                ),
              ),
            ],
          ),
          onTap: () => context.push('/shop-me'),
        );
      },
    );
  }
}

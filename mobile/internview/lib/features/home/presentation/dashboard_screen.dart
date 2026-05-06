import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/presentation/widgets/neo/neo_background.dart';
import '../../../core/presentation/widgets/neo/neo_box.dart';
import '../../../core/presentation/widgets/neo/neo_button.dart';
import '../../auth/controllers/auth_controller.dart';
import '../../booking/data/booking_remote_data_source.dart';
import '../../booking/presentation/booking_ui_helpers.dart';
import '../../../core/models/booking_models.dart';

final _candidateBookingsPreviewProvider = FutureProvider.autoDispose((ref) async {
  return ref.watch(bookingRemoteProvider).listCandidateBookings(page: 0, size: 20);
});

final _expertBookingsPreviewProvider = FutureProvider.autoDispose((ref) async {
  return ref.watch(bookingRemoteProvider).listExpertBookings(page: 0, size: 20);
});

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);
    final isExpert = auth?.role.toUpperCase() == 'EXPERT';
    final theme = Theme.of(context);

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
        body: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            isExpert ? const _DashboardExpertTopCard() : const _DashboardCandidateTopCard(),
            const SizedBox(height: 24),
            if (!isExpert)
              NeoBox(
                color: const Color(0xFFB388FF), // Purple
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Geçmiş Mülakat', style: theme.textTheme.titleLarge),
                    const SizedBox(height: 12),
                    const _PastInterviewsPreview(),
                  ],
                ),
              )
            else
              NeoBox(
                color: const Color(0xFFB388FF), // Purple
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Onay Bekleyen', style: theme.textTheme.titleLarge),
                    const SizedBox(height: 12),
                    const _PendingApprovalsPreview(),
                  ],
                ),
              ),
            const SizedBox(height: 24),
            NeoBox(
              color: const Color(0xFFFF9100), // Orange
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(isExpert ? 'Müsaitlik' : 'Yeni Randevu', style: theme.textTheme.titleLarge),
                  const SizedBox(height: 16),
                  NeoButton(
                    color: Colors.white,
                    onPressed: () {
                      context.push(isExpert ? '/expert-availability' : '/booking/create');
                    },
                    width: double.infinity,
                    child: const Center(
                      child: Text('Aç', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),
          ],
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
    return NeoBox(
      color: theme.colorScheme.tertiary,
      child: bookings.when(
        loading: () => const SizedBox(height: 120, child: Center(child: CircularProgressIndicator())),
        error: (e, _) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Sıradaki randevu', style: theme.textTheme.titleLarge),
            const SizedBox(height: 8),
            Text('$e'),
          ],
        ),
        data: (page) {
          final confirmed = page.items.where((b) => b.status.name.toUpperCase() == 'CONFIRMED').toList();
          confirmed.sort((a, b) => a.scheduledStart.compareTo(b.scheduledStart));
          final next = confirmed.isNotEmpty ? confirmed.first : (page.items.isNotEmpty ? page.items.first : null);
          if (next == null) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Sıradaki randevu', style: theme.textTheme.titleLarge),
                const SizedBox(height: 8),
                const Text('Henüz randevu yok. Uzman seçip talep gönderebilirsiniz.'),
              ],
            );
          }
          final canJoin = joinWindowAllowed(next) && next.status.name.toUpperCase() == 'CONFIRMED';
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Sıradaki randevu', style: theme.textTheme.titleLarge),
              const SizedBox(height: 8),
              Text('${next.scheduledStart.toLocal()}', style: theme.textTheme.bodyLarge),
              const SizedBox(height: 16),
              IgnorePointer(
                ignoring: false,
                child: Opacity(
                  opacity: canJoin ? 1 : 0.75,
                  child: NeoButton(
                    color: Colors.white,
                    onPressed: () => context.push(canJoin ? '/interview/${next.id}' : '/booking/${next.id}'),
                    width: double.infinity,
                    child: Center(
                      child: Text(
                        joinCtaLabel(next),
                        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                      ),
                    ),
                  ),
                ),
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
    return NeoBox(
      color: theme.colorScheme.tertiary,
      child: bookings.when(
        loading: () => const SizedBox(height: 120, child: Center(child: CircularProgressIndicator())),
        error: (e, _) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Sıradaki seans', style: theme.textTheme.titleLarge),
            const SizedBox(height: 8),
            Text('$e'),
          ],
        ),
        data: (page) {
          final confirmed = page.items.where((b) => b.status.name.toUpperCase() == 'CONFIRMED').toList();
          confirmed.sort((a, b) => a.scheduledStart.compareTo(b.scheduledStart));
          if (confirmed.isEmpty) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Sıradaki seans', style: theme.textTheme.titleLarge),
                const SizedBox(height: 8),
                const Text('Henüz onaylı seans yok. Müsaitlik ekleyin.'),
              ],
            );
          }
          final next = confirmed.first;
          final canJoin = joinWindowAllowed(next) && next.status.name.toUpperCase() == 'CONFIRMED';
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Sıradaki seans', style: theme.textTheme.titleLarge),
              const SizedBox(height: 8),
              Text('${next.scheduledStart.toLocal()}', style: theme.textTheme.bodyLarge),
              const SizedBox(height: 16),
              IgnorePointer(
                ignoring: false,
                child: Opacity(
                  opacity: canJoin ? 1 : 0.75,
                  child: NeoButton(
                    color: Colors.white,
                    onPressed: () => context.push(canJoin ? '/interview/${next.id}' : '/booking/${next.id}'),
                    width: double.infinity,
                    child: Center(
                      child: Text(
                        joinCtaLabel(next),
                        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                      ),
                    ),
                  ),
                ),
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
        child: CircularProgressIndicator(),
      ),
      error: (e, _) => Text('$e'),
      data: (page) {
        final cutoff = DateTime.now().subtract(const Duration(days: 30));
        final completed = page.items
            .where((b) => b.status == BookingStatus.completed && b.scheduledEnd.toLocal().isAfter(cutoff))
            .toList();
        if (completed.isEmpty) return const Text('Henüz tamamlanan mülakat yok.');
        return Column(
          children: [
            for (final b in completed.take(3))
              ListTile(
                dense: true,
                title: const Text('Mülakat'),
                subtitle: Text('${b.scheduledStart.toLocal()}'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push('/interview/${b.id}/result'),
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
        child: CircularProgressIndicator(),
      ),
      error: (e, _) => Text('$e'),
      data: (page) {
        final pending = page.items.where((b) => b.status == BookingStatus.pending).toList();
        if (pending.isEmpty) return const Text('Onay bekleyen talep yok.');
        return Column(
          children: [
            for (final b in pending.take(3))
              ListTile(
                dense: true,
                title: const Text('Talep'),
                subtitle: Text('${b.scheduledStart.toLocal()}'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push('/booking/${b.id}'),
              ),
          ],
        );
      },
    );
  }
}

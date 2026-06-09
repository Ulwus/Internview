import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../../core/models/booking_models.dart';
import '../../../core/models/page_response.dart';
import '../../../core/models/shop_models.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/presentation/widgets/neo/neo_background.dart';
import '../../../core/presentation/widgets/penkrowd/animated_action_button.dart';
import '../../../core/presentation/widgets/penkrowd/penkrowd_card.dart';
import '../../../core/presentation/widgets/penkrowd/radial_stat_gauge.dart';
import '../../../core/presentation/widgets/penkrowd/skeleton_container.dart';
import '../../booking/data/booking_remote_data_source.dart';
import '../data/marketplace_remote_data_source.dart';

final _shopDetailProvider = FutureProvider.family
    .autoDispose<ShopSummaryDto, String>((ref, id) {
      return ref.watch(marketplaceRemoteProvider).getShop(id);
    });

final _expertStatsProvider = FutureProvider.family
    .autoDispose<ExpertStatsDto, String>((ref, expertUserId) {
      return ref.watch(marketplaceRemoteProvider).getExpertStats(expertUserId);
    });

final _expertReviewsProvider = FutureProvider.family
    .autoDispose<PageResponse<ExpertReviewDto>, String>((ref, expertUserId) {
      return ref
          .watch(marketplaceRemoteProvider)
          .getExpertReviews(expertUserId: expertUserId, page: 0, size: 10);
    });

final _openSlotsForExpertProvider = FutureProvider.family
    .autoDispose<List<SlotDto>, String>((ref, expertUserId) {
      return ref.watch(bookingRemoteProvider).listOpenSlots(expertUserId);
    });

class ShopDetailScreen extends ConsumerStatefulWidget {
  const ShopDetailScreen({super.key, required this.shopId});

  final String shopId;

  @override
  ConsumerState<ShopDetailScreen> createState() => _ShopDetailScreenState();
}

class _ShopDetailScreenState extends ConsumerState<ShopDetailScreen> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  SlotDto? _selectedSlot;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final shopAsync = ref.watch(_shopDetailProvider(widget.shopId));

    return NeoBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(title: const Text('Uzman dükkanı')),
        body: shopAsync.when(
          loading: () => const Center(
            child: SkeletonContainer(width: 220, height: 14, borderRadius: 8),
          ),
          error: (e, _) => Center(child: Text('$e')),
          data: (shop) {
            final statsAsync = ref.watch(
              _expertStatsProvider(shop.expertUserId),
            );
            final reviewsAsync = ref.watch(
              _expertReviewsProvider(shop.expertUserId),
            );
            final slotsAsync = ref.watch(
              _openSlotsForExpertProvider(shop.expertUserId),
            );

            final openSlots = (slotsAsync.valueOrNull ?? const <SlotDto>[])
                .where((s) => !s.booked)
                .toList();
            final openSlotsByDay = <DateTime, List<SlotDto>>{};
            for (final s in openSlots) {
              final st = s.startTime.toLocal();
              final k = DateTime(st.year, st.month, st.day);
              (openSlotsByDay[k] ??= []).add(s);
            }
            for (final list in openSlotsByDay.values) {
              list.sort((a, b) => a.startTime.compareTo(b.startTime));
            }

            final name = shop.expertFullName;
            final industry = shop.industry?.name;
            final price = (shop.hourlyRate != null)
                ? '${shop.hourlyRate} ${shop.currency ?? ''}'
                : null;
            final meta = [
              if (industry != null && industry.isNotEmpty) industry,
              if (price != null && price.trim().isNotEmpty) price,
            ].join(' • ');

            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                PenkrowdCard(
                  accentColor: const Color(0xFF00E5FF),
                  leading: CircleAvatar(
                    radius: 18,
                    backgroundColor: Colors.white,
                    backgroundImage:
                        (shop.expertAvatarUrl != null &&
                            shop.expertAvatarUrl!.isNotEmpty)
                        ? NetworkImage(shop.expertAvatarUrl!)
                        : null,
                    child:
                        (shop.expertAvatarUrl == null ||
                            shop.expertAvatarUrl!.isEmpty)
                        ? Text(
                            (shop.expertFirstName.isNotEmpty
                                    ? shop.expertFirstName[0]
                                    : '?')
                                .toUpperCase(),
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              color: Colors.black,
                            ),
                          )
                        : null,
                  ),
                  title: Text(
                    name,
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                  subtitle: meta.isEmpty
                      ? null
                      : Text(
                          meta,
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                  trailing: statsAsync.when(
                    data: (s) => RadialStatGauge(
                      value: s.averageRating,
                      max: 10,
                      label: 'Puan',
                      size: 62,
                      accentColor: const Color(0xFFB388FF),
                    ),
                    loading: () => const SkeletonContainer(
                      width: 62,
                      height: 62,
                      borderRadius: 18,
                    ),
                    error: (_, __) => const RadialStatGauge(
                      value: null,
                      max: 10,
                      label: 'Puan',
                      size: 62,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                if (shop.description != null &&
                    shop.description!.trim().isNotEmpty) ...[
                  Text(
                    'Açıklama',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(shop.description!.trim()),
                  const SizedBox(height: 14),
                ],
                statsAsync.when(
                  data: (s) => Row(
                    children: [
                      Expanded(
                        child: _statChip(
                          'Tamamlanan',
                          s.completedCount.toString(),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _statChip('İptal', s.cancelledCount.toString()),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _statChip(
                          'İncelemeler',
                          s.totalRated.toString(),
                        ),
                      ),
                    ],
                  ),
                  loading: () => const SkeletonContainer(
                    width: double.infinity,
                    height: 54,
                    borderRadius: 18,
                  ),
                  error: (_, __) => const SizedBox.shrink(),
                ),
                const SizedBox(height: 16),
                Text(
                  'Müsaitlik',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFD600),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.black, width: 3),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black,
                        blurRadius: 0,
                        offset: Offset(4, 4),
                      ),
                    ],
                  ),
                  child: slotsAsync.when(
                    loading: () => const SkeletonContainer(
                      width: double.infinity,
                      height: 14,
                      borderRadius: 8,
                    ),
                    error: (e, _) => Text('$e'),
                    data: (_) => TableCalendar(
                      firstDay: DateTime.now().subtract(
                        const Duration(days: 1),
                      ),
                      lastDay: DateTime.now().add(const Duration(days: 45)),
                      focusedDay: _focusedDay,
                      enabledDayPredicate: (day) {
                        final k = DateTime(day.year, day.month, day.day);
                        return openSlotsByDay.containsKey(k);
                      },
                      selectedDayPredicate: (day) =>
                          isSameDay(_selectedDay, day),
                      onDaySelected: (selectedDay, focusedDay) {
                        setState(() {
                          _selectedDay = selectedDay;
                          _focusedDay = focusedDay;
                          _selectedSlot = null;
                        });
                      },
                      headerStyle: const HeaderStyle(
                        formatButtonVisible: false,
                        titleCentered: true,
                        titleTextStyle: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      calendarStyle: const CalendarStyle(
                        selectedDecoration: BoxDecoration(
                          color: Colors.black,
                          shape: BoxShape.circle,
                        ),
                        todayDecoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          border: Border.fromBorderSide(
                            BorderSide(color: Colors.black, width: 2),
                          ),
                        ),
                        todayTextStyle: TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                if (_selectedDay != null) ...[
                  Builder(
                    builder: (context) {
                      final k = DateTime(
                        _selectedDay!.year,
                        _selectedDay!.month,
                        _selectedDay!.day,
                      );
                      final daySlots = openSlotsByDay[k] ?? const <SlotDto>[];
                      if (daySlots.isEmpty)
                        return const Text('Bu gün için uygun slot yok.');
                      return GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              crossAxisSpacing: 8,
                              mainAxisSpacing: 8,
                              childAspectRatio: 3.2,
                            ),
                        itemCount: daySlots.length,
                        itemBuilder: (context, index) {
                          final s = daySlots[index];
                          final isSelected = _selectedSlot?.id == s.id;
                          final st = s.startTime.toLocal();
                          final label = DateFormat('HH:mm', 'tr_TR').format(st);
                          return GestureDetector(
                            onTap: () => setState(() => _selectedSlot = s),
                            child: Container(
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? Colors.black
                                    : const Color(0xFFFF5252),
                                border: Border.all(
                                  color: Colors.black,
                                  width: 2,
                                ),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                label,
                                style: TextStyle(
                                  color: isSelected
                                      ? Colors.white
                                      : Colors.black,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  AnimatedActionButton(
                    onTap: () async {
                      if (_selectedSlot == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Önce saat seçin')),
                        );
                        return;
                      }
                      try {
                        final b = await ref
                            .read(bookingRemoteProvider)
                            .createBooking(
                              expertId: shop.expertUserId,
                              slotId: _selectedSlot!.id,
                            );
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Talep gönderildi (uzman onayı bekleniyor)',
                            ),
                          ),
                        );
                        context.push('/booking/${b.id}');
                      } on ApiException catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(
                            context,
                          ).showSnackBar(SnackBar(content: Text(e.message)));
                        }
                      }
                    },
                    width: double.infinity,
                    height: 48,
                    color: const Color(0xFF00E5FF),
                    pressedColor: const Color(0xFF00E5FF),
                    borderColor: Colors.black,
                    borderWidth: 3,
                    borderRadius: 14,
                    shadowOffset: const Offset(4, 4),
                    child: const Center(
                      child: Text(
                        'İstek at',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                          color: Colors.black,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                ],
                Text(
                  'Yorumlar',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 10),
                reviewsAsync.when(
                  loading: () => const SkeletonContainer(
                    width: double.infinity,
                    height: 70,
                    borderRadius: 18,
                  ),
                  error: (e, _) => Text('$e'),
                  data: (page) {
                    if (page.items.isEmpty)
                      return const Text('Henüz yorum yok.');
                    return Column(
                      children: [
                        for (final r in page.items)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: PenkrowdCard(
                              accentColor: const Color(0xFFB388FF),
                              title: Text(
                                r.rating == null
                                    ? 'Değerlendirme'
                                    : 'Puan: ${r.rating}/10',
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                              subtitle:
                                  (r.comment != null &&
                                      r.comment!.trim().isNotEmpty)
                                  ? Text(
                                      r.comment!.trim(),
                                      maxLines: 3,
                                      overflow: TextOverflow.ellipsis,
                                    )
                                  : const Text('Yorum yok'),
                              onTap: () => context.push(
                                '/interview/${r.bookingId}/result',
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 24),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _statChip(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.black, width: 3),
        boxShadow: const [
          BoxShadow(color: Colors.black, blurRadius: 0, offset: Offset(4, 4)),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w900,
              color: Colors.black.withValues(alpha: 0.65),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
          ),
        ],
      ),
    );
  }
}

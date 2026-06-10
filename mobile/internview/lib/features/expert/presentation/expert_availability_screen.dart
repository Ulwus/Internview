import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/models/booking_models.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/presentation/widgets/penkrowd/animated_action_button.dart';
import '../../../core/presentation/widgets/penkrowd/skeleton_container.dart';
import '../../booking/data/booking_remote_data_source.dart';

final mySlotsProvider = FutureProvider.autoDispose<List<SlotDto>>((ref) {
  return ref.watch(bookingRemoteProvider).listMySlots();
});

class ExpertAvailabilityScreen extends ConsumerStatefulWidget {
  const ExpertAvailabilityScreen({super.key});

  @override
  ConsumerState<ExpertAvailabilityScreen> createState() =>
      _ExpertAvailabilityScreenState();
}

class _ExpertAvailabilityScreenState
    extends ConsumerState<ExpertAvailabilityScreen> {
  late DateTime _visibleMonth;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _visibleMonth = DateTime(now.year, now.month);
  }

  DateTime get _thisMonth {
    final now = DateTime.now();
    return DateTime(now.year, now.month);
  }

  DateTime get _nextMonth {
    final t = _thisMonth;
    return DateTime(t.year, t.month + 1);
  }

  bool get _canGoPrev => _visibleMonth.isAfter(_thisMonth);
  bool get _canGoNext => _visibleMonth.isBefore(_nextMonth);

  @override
  Widget build(BuildContext context) {
    final slotsAsync = ref.watch(mySlotsProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF7F5EF),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF7F5EF),
        title: const Text('Müsaitlik'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: IconButton.filledTonal(
              onPressed: () => ref.invalidate(mySlotsProvider),
              icon: const Icon(Icons.refresh),
            ),
          ),
        ],
      ),
      body: slotsAsync.when(
        loading: () => const Center(
          child: SkeletonContainer(width: 220, height: 14, borderRadius: 8),
        ),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(e is ApiException ? e.message : '$e'),
          ),
        ),
        data: (slots) {
          final grouped = _groupSlotsByLocalDay(slots);
          final openCount = slots.where((slot) => !slot.booked).length;
          final bookedCount = slots.length - openCount;
          final upcoming =
              slots
                  .where(
                    (slot) => slot.startTime.toLocal().isAfter(DateTime.now()),
                  )
                  .toList()
                ..sort((a, b) => a.startTime.compareTo(b.startTime));

          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(mySlotsProvider),
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
                  sliver: SliverToBoxAdapter(
                    child: _AvailabilitySummary(
                      total: slots.length,
                      open: openCount,
                      booked: bookedCount,
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  sliver: SliverToBoxAdapter(
                    child: _CalendarPanel(
                      month: _visibleMonth,
                      canGoPrev: _canGoPrev,
                      canGoNext: _canGoNext,
                      slotsByDay: grouped,
                      onPrev: () => setState(() {
                        _visibleMonth = DateTime(
                          _visibleMonth.year,
                          _visibleMonth.month - 1,
                        );
                      }),
                      onNext: () => setState(() {
                        _visibleMonth = DateTime(
                          _visibleMonth.year,
                          _visibleMonth.month + 1,
                        );
                      }),
                      onDayTap: (day) => _openDayBottomSheet(
                        context,
                        day,
                        grouped[day] ?? const [],
                      ),
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  sliver: SliverToBoxAdapter(
                    child: _UpcomingSlots(
                      slots: upcoming.take(4).toList(),
                      onTap: (slot) {
                        final local = slot.startTime.toLocal();
                        _openDayBottomSheet(
                          context,
                          _dayKey(local),
                          grouped[_dayKey(local)] ?? const [],
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  static DateTime _dayKey(DateTime dtLocal) =>
      DateTime(dtLocal.year, dtLocal.month, dtLocal.day);

  static Map<DateTime, List<SlotDto>> _groupSlotsByLocalDay(
    List<SlotDto> slots,
  ) {
    final map = <DateTime, List<SlotDto>>{};
    for (final s in slots) {
      final k = _dayKey(s.startTime.toLocal());
      (map[k] ??= []).add(s);
    }
    for (final list in map.values) {
      list.sort((a, b) => a.startTime.compareTo(b.startTime));
    }
    return map;
  }

  Future<void> _openDayBottomSheet(
    BuildContext context,
    DateTime day,
    List<SlotDto> slots,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      backgroundColor: const Color(0xFFF7F5EF),
      builder: (context) {
        final dateLabel = DateFormat('d MMMM EEEE', 'tr_TR').format(day);

        return SafeArea(
          child: Padding(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 8,
              bottom: 16 + MediaQuery.viewInsetsOf(context).bottom,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  dateLabel,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${slots.length} seans planlandı',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.black.withValues(alpha: 0.62),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 16),
                AnimatedActionButton(
                  onTap: () => _createSlotForDay(context, day),
                  width: double.infinity,
                  height: 52,
                  color: const Color(0xFF00E5FF),
                  pressedColor: const Color(0xFF00E5FF),
                  borderColor: Colors.black,
                  borderWidth: 3,
                  borderRadius: 14,
                  shadowOffset: const Offset(4, 4),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.add, color: Colors.black),
                      SizedBox(width: 8),
                      Text(
                        '45 dk seans ekle',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          color: Colors.black,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                if (slots.isEmpty)
                  const _EmptyDay()
                else
                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: slots.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (context, i) {
                        final slot = slots[i];
                        return _SlotRow(
                          slot: slot,
                          onDelete: slot.booked
                              ? null
                              : () => _deleteSlot(context, slot.id),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _createSlotForDay(BuildContext context, DateTime day) async {
    final startT = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 9, minute: 0),
    );
    if (startT == null) return;

    final start = DateTime(
      day.year,
      day.month,
      day.day,
      startT.hour,
      startT.minute,
    );
    final end = start.add(const Duration(minutes: 45));

    try {
      await ref
          .read(bookingRemoteProvider)
          .createMySlot(start: start, end: end);
      ref.invalidate(mySlotsProvider);
      if (context.mounted) Navigator.of(context).pop();
    } on ApiException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  Future<void> _deleteSlot(BuildContext context, String slotId) async {
    try {
      await ref.read(bookingRemoteProvider).deleteMySlot(slotId);
      ref.invalidate(mySlotsProvider);
      if (context.mounted) Navigator.of(context).pop();
    } on ApiException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }
}

class _AvailabilitySummary extends StatelessWidget {
  const _AvailabilitySummary({
    required this.total,
    required this.open,
    required this.booked,
  });

  final int total;
  final int open;
  final int booked;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _neoDecoration(const Color(0xFFFFFFFF)),
      child: Row(
        children: [
          Expanded(
            child: _SummaryItem(label: 'Toplam', value: '$total'),
          ),
          Expanded(
            child: _SummaryItem(label: 'Boş', value: '$open'),
          ),
          Expanded(
            child: _SummaryItem(label: 'Dolu', value: '$booked'),
          ),
        ],
      ),
    );
  }
}

class _SummaryItem extends StatelessWidget {
  const _SummaryItem({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: Colors.black.withValues(alpha: 0.56),
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
        ),
      ],
    );
  }
}

class _CalendarPanel extends StatelessWidget {
  const _CalendarPanel({
    required this.month,
    required this.canGoPrev,
    required this.canGoNext,
    required this.slotsByDay,
    required this.onPrev,
    required this.onNext,
    required this.onDayTap,
  });

  final DateTime month;
  final bool canGoPrev;
  final bool canGoNext;
  final Map<DateTime, List<SlotDto>> slotsByDay;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final void Function(DateTime day) onDayTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: _neoDecoration(const Color(0xFFFFD600)),
      child: Column(
        children: [
          _MonthHeader(
            month: month,
            canGoPrev: canGoPrev,
            canGoNext: canGoNext,
            onPrev: onPrev,
            onNext: onNext,
          ),
          const SizedBox(height: 14),
          _MonthGrid(month: month, slotsByDay: slotsByDay, onDayTap: onDayTap),
        ],
      ),
    );
  }
}

class _MonthHeader extends StatelessWidget {
  const _MonthHeader({
    required this.month,
    required this.canGoPrev,
    required this.canGoNext,
    required this.onPrev,
    required this.onNext,
  });

  final DateTime month;
  final bool canGoPrev;
  final bool canGoNext;
  final VoidCallback onPrev;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _MonthButton(
          icon: Icons.chevron_left,
          enabled: canGoPrev,
          onTap: onPrev,
        ),
        Expanded(
          child: Center(
            child: Text(
              DateFormat('MMMM yyyy', 'tr_TR').format(month),
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
            ),
          ),
        ),
        _MonthButton(
          icon: Icons.chevron_right,
          enabled: canGoNext,
          onTap: onNext,
        ),
      ],
    );
  }
}

class _MonthButton extends StatelessWidget {
  const _MonthButton({
    required this.icon,
    required this.enabled,
    required this.onTap,
  });

  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AnimatedActionButton(
      onTap: enabled ? onTap : null,
      width: 46,
      height: 46,
      color: Colors.white,
      pressedColor: Colors.white,
      borderColor: Colors.black,
      borderWidth: 3,
      borderRadius: 14,
      shadowOffset: const Offset(4, 4),
      child: Icon(icon, color: enabled ? Colors.black : Colors.black26),
    );
  }
}

class _MonthGrid extends StatelessWidget {
  const _MonthGrid({
    required this.month,
    required this.slotsByDay,
    required this.onDayTap,
  });

  final DateTime month;
  final Map<DateTime, List<SlotDto>> slotsByDay;
  final void Function(DateTime day) onDayTap;

  @override
  Widget build(BuildContext context) {
    final firstOfMonth = DateTime(month.year, month.month, 1);
    final firstWeekday = firstOfMonth.weekday;
    final gridStart = firstOfMonth.subtract(Duration(days: firstWeekday - 1));
    final firstOfNextMonth = DateTime(month.year, month.month + 1, 1);
    final daysInMonth = firstOfNextMonth.difference(firstOfMonth).inDays;
    final totalCells = (((firstWeekday - 1) + daysInMonth) / 7).ceil() * 7;
    const weekdays = ['Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cmt', 'Paz'];

    return Column(
      children: [
        Row(
          children: [
            for (final weekday in weekdays)
              Expanded(
                child: Center(
                  child: Text(
                    weekday,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: Colors.black.withValues(alpha: 0.58),
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 0.88,
          ),
          itemCount: totalCells,
          itemBuilder: (context, i) {
            final day = DateTime(
              gridStart.year,
              gridStart.month,
              gridStart.day + i,
            );
            final key = DateTime(day.year, day.month, day.day);
            final inMonth = day.month == month.month;
            final slots = slotsByDay[key] ?? const <SlotDto>[];
            return _DayCell(
              day: day,
              inMonth: inMonth,
              count: slots.length,
              bookedCount: slots.where((slot) => slot.booked).length,
              onTap: inMonth ? () => onDayTap(key) : null,
            );
          },
        ),
      ],
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.day,
    required this.inMonth,
    required this.count,
    required this.bookedCount,
    required this.onTap,
  });

  final DateTime day;
  final bool inMonth;
  final int count;
  final int bookedCount;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final isToday = _isSameDay(day, DateTime.now());
    final openCount = count - bookedCount;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            color: !inMonth
                ? Colors.white.withValues(alpha: 0.35)
                : isToday
                ? const Color(0xFF00E5FF)
                : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: inMonth ? Colors.black : Colors.black12,
              width: inMonth ? 2 : 1,
            ),
          ),
          child: Stack(
            children: [
              Positioned(
                left: 6,
                top: 5,
                child: Text(
                  '${day.day}',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: inMonth ? Colors.black : Colors.black26,
                    fontWeight: FontWeight.w900,
                    height: 1,
                  ),
                ),
              ),
              if (inMonth && count > 0)
                Positioned(
                  left: 6,
                  right: 6,
                  bottom: 5,
                  child: _SlotMarkers(
                    openCount: openCount,
                    bookedCount: bookedCount,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  static bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

class _SlotMarkers extends StatelessWidget {
  const _SlotMarkers({required this.openCount, required this.bookedCount});

  final int openCount;
  final int bookedCount;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (openCount > 0) const _MiniDot(color: Color(0xFF00C853)),
        if (openCount > 1) const SizedBox(width: 3),
        if (openCount > 1) const _MiniDot(color: Color(0xFF00C853)),
        if (bookedCount > 0) const SizedBox(width: 3),
        if (bookedCount > 0) const _MiniDot(color: Colors.black),
      ],
    );
  }
}

class _MiniDot extends StatelessWidget {
  const _MiniDot({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 6,
      height: 6,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

class _UpcomingSlots extends StatelessWidget {
  const _UpcomingSlots({required this.slots, required this.onTap});

  final List<SlotDto> slots;
  final ValueChanged<SlotDto> onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
      decoration: _neoDecoration(Colors.white, shadow: const Offset(3, 3)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Yaklaşan seanslar',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              if (slots.isNotEmpty) _CountPill(label: '${slots.length}'),
            ],
          ),
          const SizedBox(height: 10),
          if (slots.isEmpty)
            Text(
              'Henüz seans yok.',
              style: TextStyle(
                color: Colors.black.withValues(alpha: 0.58),
                fontWeight: FontWeight.w700,
              ),
            )
          else ...[
            for (var i = 0; i < slots.length; i++) ...[
              _UpcomingSlotRow(slot: slots[i], onTap: () => onTap(slots[i])),
              if (i != slots.length - 1)
                Divider(
                  color: Colors.black.withValues(alpha: 0.12),
                  height: 12,
                ),
            ],
          ],
        ],
      ),
    );
  }
}

class _UpcomingSlotRow extends StatelessWidget {
  const _UpcomingSlotRow({required this.slot, required this.onTap});

  final SlotDto slot;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final start = slot.startTime.toLocal();
    final end = slot.endTime.toLocal();
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 8),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: const Color(0xFFFFD600),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.black, width: 2),
              ),
              child: Text(
                DateFormat('d', 'tr_TR').format(start),
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    DateFormat('MMM EEE', 'tr_TR').format(start),
                    style: TextStyle(
                      color: Colors.black.withValues(alpha: 0.6),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${DateFormat('HH:mm', 'tr_TR').format(start)}-'
                    '${DateFormat('HH:mm', 'tr_TR').format(end)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 17,
                    ),
                  ),
                ],
              ),
            ),
            _StatusPill(label: slot.booked ? 'Dolu' : 'Boş'),
          ],
        ),
      ),
    );
  }
}

class _CountPill extends StatelessWidget {
  const _CountPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFF00E5FF),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.black, width: 2),
      ),
      child: Text(label, style: const TextStyle(fontWeight: FontWeight.w900)),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 54),
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F5EF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black, width: 2),
      ),
      child: Text(label, style: const TextStyle(fontWeight: FontWeight.w900)),
    );
  }
}

class _SlotRow extends StatelessWidget {
  const _SlotRow({required this.slot, required this.onDelete});

  final SlotDto slot;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final localStart = slot.startTime.toLocal();
    final localEnd = slot.endTime.toLocal();
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: _neoDecoration(Colors.white, shadow: const Offset(3, 3)),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${DateFormat('HH:mm').format(localStart)} - '
                  '${DateFormat('HH:mm').format(localEnd)}',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  slot.booked ? 'Aday tarafından rezerve edildi' : 'Boş slot',
                  style: TextStyle(
                    color: Colors.black.withValues(alpha: 0.58),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          if (onDelete != null)
            IconButton.filledTonal(
              onPressed: onDelete,
              icon: const Icon(Icons.delete_outline),
            ),
        ],
      ),
    );
  }
}

class _EmptyDay extends StatelessWidget {
  const _EmptyDay();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _neoDecoration(Colors.white),
      child: const Text(
        'Bu gün için seans yok.',
        style: TextStyle(fontWeight: FontWeight.w800),
      ),
    );
  }
}

BoxDecoration _neoDecoration(
  Color color, {
  Offset shadow = const Offset(4, 4),
}) {
  return BoxDecoration(
    color: color,
    borderRadius: BorderRadius.circular(18),
    border: Border.all(color: Colors.black, width: 3),
    boxShadow: [BoxShadow(color: Colors.black, blurRadius: 0, offset: shadow)],
  );
}

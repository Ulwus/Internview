import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/booking_models.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/presentation/widgets/neo/neo_background.dart';
import '../../../core/presentation/widgets/penkrowd/animated_action_button.dart';
import '../../../core/presentation/widgets/penkrowd/skeleton_container.dart';
import '../../booking/data/booking_remote_data_source.dart';

final mySlotsProvider = FutureProvider.autoDispose<List<SlotDto>>((ref) {
  return ref.watch(bookingRemoteProvider).listMySlots();
});

class ExpertAvailabilityScreen extends ConsumerStatefulWidget {
  const ExpertAvailabilityScreen({super.key});

  @override
  ConsumerState<ExpertAvailabilityScreen> createState() => _ExpertAvailabilityScreenState();
}

class _ExpertAvailabilityScreenState extends ConsumerState<ExpertAvailabilityScreen> {
  late DateTime _visibleMonth; // local

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

    return NeoBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text('Müsaitlik'),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: AnimatedActionButton(
                onTap: () => ref.invalidate(mySlotsProvider),
                width: 46,
                height: 46,
                color: Colors.white,
                pressedColor: Colors.white,
                borderColor: Colors.black,
                borderWidth: 3,
                borderRadius: 14,
                shadowOffset: const Offset(4, 4),
                child: const Icon(Icons.refresh, color: Colors.black),
              ),
            ),
          ],
        ),
        body: slotsAsync.when(
          loading: () => const Center(child: SkeletonContainer(width: 220, height: 14, borderRadius: 8)),
          error: (e, _) => Center(child: Text('$e')),
          data: (slots) {
            final grouped = _groupSlotsByLocalDay(slots);
            return Column(
              children: [
                _MonthHeader(
                  month: _visibleMonth,
                  canGoPrev: _canGoPrev,
                  canGoNext: _canGoNext,
                  onPrev: () => setState(() => _visibleMonth = DateTime(_visibleMonth.year, _visibleMonth.month - 1)),
                  onNext: () => setState(() => _visibleMonth = DateTime(_visibleMonth.year, _visibleMonth.month + 1)),
                ),
                Expanded(
                  child: _MonthGrid(
                    month: _visibleMonth,
                    slotsByDay: grouped,
                    onDayTap: (day) => _openDayBottomSheet(context, day, grouped[day] ?? const []),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  static DateTime _dayKey(DateTime dtLocal) => DateTime(dtLocal.year, dtLocal.month, dtLocal.day);

  static Map<DateTime, List<SlotDto>> _groupSlotsByLocalDay(List<SlotDto> slots) {
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

  Future<void> _openDayBottomSheet(BuildContext context, DateTime day, List<SlotDto> slots) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) {
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
                  '${day.day}.${day.month}.${day.year}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                AnimatedActionButton(
                  onTap: () async {
                    final startT = await showTimePicker(
                      context: context,
                      initialTime: const TimeOfDay(hour: 9, minute: 0),
                    );
                    if (startT == null) return;

                    final start = DateTime(day.year, day.month, day.day, startT.hour, startT.minute);
                    final end = start.add(const Duration(minutes: 45));

                    try {
                      await ref.read(bookingRemoteProvider).createMySlot(start: start, end: end);
                      ref.invalidate(mySlotsProvider);
                      if (context.mounted) {
                        Navigator.of(context).pop();
                      }
                    } on ApiException catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
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
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.add, color: Colors.black),
                      SizedBox(width: 8),
                      Text('45 dk seans ekle', style: TextStyle(fontWeight: FontWeight.w900, color: Colors.black)),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                if (slots.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Text('Bu gün için seans yok.'),
                  )
                else
                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: slots.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (context, i) {
                        final s = slots[i];
                        final localStart = s.startTime.toLocal();
                        final localEnd = s.endTime.toLocal();
                        return ListTile(
                          dense: true,
                          title: Text(
                            '${localStart.hour.toString().padLeft(2, '0')}:${localStart.minute.toString().padLeft(2, '0')}'
                            ' — '
                            '${localEnd.hour.toString().padLeft(2, '0')}:${localEnd.minute.toString().padLeft(2, '0')}',
                          ),
                          subtitle: Text(s.booked ? 'Dolu' : 'Boş'),
                          trailing: s.booked
                              ? null
                              : AnimatedActionButton(
                                  onTap: () async {
                                    try {
                                      await ref.read(bookingRemoteProvider).deleteMySlot(s.id);
                                      ref.invalidate(mySlotsProvider);
                                      if (context.mounted) {
                                        Navigator.of(context).pop();
                                      }
                                    } on ApiException catch (e) {
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
                                      }
                                    }
                                  },
                                  width: 44,
                                  height: 44,
                                  color: Colors.white,
                                  pressedColor: Colors.white,
                                  borderColor: Colors.black,
                                  borderWidth: 3,
                                  borderRadius: 14,
                                  shadowOffset: const Offset(4, 4),
                                  child: const Icon(Icons.delete_outline, color: Colors.black),
                                ),
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: Row(
        children: [
          AnimatedActionButton(
            onTap: canGoPrev ? onPrev : null,
            width: 46,
            height: 46,
            color: Colors.white,
            pressedColor: Colors.white,
            borderColor: Colors.black,
            borderWidth: 3,
            borderRadius: 14,
            shadowOffset: const Offset(4, 4),
            child: const Icon(Icons.chevron_left, color: Colors.black),
          ),
          Expanded(
            child: Center(
              child: Text(
                '${month.month.toString().padLeft(2, '0')}.${month.year}',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
          ),
          AnimatedActionButton(
            onTap: canGoNext ? onNext : null,
            width: 46,
            height: 46,
            color: Colors.white,
            pressedColor: Colors.white,
            borderColor: Colors.black,
            borderWidth: 3,
            borderRadius: 14,
            shadowOffset: const Offset(4, 4),
            child: const Icon(Icons.chevron_right, color: Colors.black),
          ),
        ],
      ),
    );
  }
}

class _MonthGrid extends StatelessWidget {
  const _MonthGrid({
    required this.month,
    required this.slotsByDay,
    required this.onDayTap,
  });

  final DateTime month; // local, first day
  final Map<DateTime, List<SlotDto>> slotsByDay;
  final void Function(DateTime day) onDayTap;

  @override
  Widget build(BuildContext context) {
    final firstOfMonth = DateTime(month.year, month.month, 1);
    final firstWeekday = firstOfMonth.weekday; // Mon=1..Sun=7
    final gridStart = firstOfMonth.subtract(Duration(days: firstWeekday - 1));

    final firstOfNextMonth = DateTime(month.year, month.month + 1, 1);
    final daysInMonth = firstOfNextMonth.difference(firstOfMonth).inDays;
    final totalCells = (((firstWeekday - 1) + daysInMonth) / 7).ceil() * 7;

    final weekdays = const ['Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cmt', 'Paz'];

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              for (final w in weekdays)
                Expanded(
                  child: Center(
                    child: Text(
                      w,
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
            ),
            itemCount: totalCells,
            itemBuilder: (context, i) {
              final day = DateTime(gridStart.year, gridStart.month, gridStart.day + i);
              final inMonth = day.month == month.month;
              final count = slotsByDay[DateTime(day.year, day.month, day.day)]?.length ?? 0;
              return _DayCell(
                day: day,
                inMonth: inMonth,
                count: count,
                onTap: inMonth ? () => onDayTap(DateTime(day.year, day.month, day.day)) : null,
              );
            },
          ),
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
    required this.onTap,
  });

  final DateTime day;
  final bool inMonth;
  final int count;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final isToday = _isSameDay(day, DateTime.now());
    final cs = Theme.of(context).colorScheme;
    final bg = isToday ? cs.primaryContainer : cs.surfaceContainerHighest;
    final fg = isToday ? cs.onPrimaryContainer : cs.onSurface;

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Ink(
        decoration: BoxDecoration(
          color: inMonth ? bg : cs.surface.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: inMonth ? cs.outlineVariant : cs.outlineVariant.withValues(alpha: 0.3),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: LayoutBuilder(
            builder: (context, c) {
              final isTight = c.maxHeight <= 40 || c.maxWidth <= 40;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${day.day}',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: inMonth ? fg : fg.withValues(alpha: 0.35),
                        ),
                  ),
                  if (!isTight) ...[
                    const Spacer(),
                    if (inMonth && count > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: cs.secondaryContainer,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          '$count seans',
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(color: cs.onSecondaryContainer),
                        ),
                      ),
                  ],
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  static bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

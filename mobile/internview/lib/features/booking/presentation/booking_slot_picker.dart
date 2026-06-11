import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../../core/models/booking_models.dart';
import '../../../core/presentation/widgets/penkrowd/skeleton_container.dart';

class BookingSlotPicker extends StatelessWidget {
  const BookingSlotPicker({
    super.key,
    required this.slots,
    required this.loading,
    required this.focusedDay,
    required this.selectedDay,
    required this.selectedSlot,
    required this.onDaySelected,
    required this.onPageChanged,
    required this.onSlotSelected,
    this.enabled = true,
    this.emptyTitle = 'Uygun saat yok',
    this.disabledTitle = 'Önce uzman seç',
  });

  final List<SlotDto> slots;
  final bool loading;
  final DateTime focusedDay;
  final DateTime? selectedDay;
  final SlotDto? selectedSlot;
  final void Function(DateTime selectedDay, DateTime focusedDay) onDaySelected;
  final ValueChanged<DateTime> onPageChanged;
  final ValueChanged<SlotDto> onSlotSelected;
  final bool enabled;
  final String emptyTitle;
  final String disabledTitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final openSlots = slots.where((s) => !s.booked).toList();
    final grouped = _groupSlots(openSlots);
    final selectedSlots = selectedDay == null
        ? const <SlotDto>[]
        : grouped[_dayKey(selectedDay!)] ?? const <SlotDto>[];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFD600),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.black, width: 3),
        boxShadow: const [
          BoxShadow(color: Colors.black, blurRadius: 0, offset: Offset(4, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              _StepBadge(label: '1'),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Gün seç',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              _SlotSummary(count: openSlots.length),
            ],
          ),
          const SizedBox(height: 12),
          if (!enabled)
            _EmptyState(title: disabledTitle)
          else if (loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 28),
              child: Center(
                child: SkeletonContainer(
                  width: 180,
                  height: 14,
                  borderRadius: 8,
                ),
              ),
            )
          else ...[
            TableCalendar(
              firstDay: DateTime.now().subtract(const Duration(days: 1)),
              lastDay: DateTime.now().add(const Duration(days: 45)),
              focusedDay: focusedDay,
              enabledDayPredicate: (day) => grouped.containsKey(_dayKey(day)),
              selectedDayPredicate: (day) => isSameDay(selectedDay, day),
              onDaySelected: onDaySelected,
              onPageChanged: onPageChanged,
              calendarBuilders: CalendarBuilders(
                markerBuilder: (context, day, events) {
                  final count = grouped[_dayKey(day)]?.length ?? 0;
                  if (count == 0) return null;
                  return Positioned(
                    bottom: 4,
                    child: Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: Colors.black,
                        shape: BoxShape.circle,
                      ),
                    ),
                  );
                },
              ),
              headerStyle: const HeaderStyle(
                formatButtonVisible: false,
                titleCentered: true,
                titleTextStyle: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                ),
              ),
              daysOfWeekStyle: DaysOfWeekStyle(
                weekdayStyle: TextStyle(
                  fontWeight: FontWeight.w900,
                  color: Colors.black.withValues(alpha: 0.65),
                ),
                weekendStyle: TextStyle(
                  fontWeight: FontWeight.w900,
                  color: Colors.black.withValues(alpha: 0.65),
                ),
              ),
              calendarStyle: CalendarStyle(
                outsideDaysVisible: false,
                disabledTextStyle: TextStyle(
                  color: Colors.black.withValues(alpha: 0.22),
                  fontWeight: FontWeight.w800,
                ),
                defaultTextStyle: const TextStyle(fontWeight: FontWeight.w900),
                weekendTextStyle: const TextStyle(fontWeight: FontWeight.w900),
                selectedDecoration: const BoxDecoration(
                  color: Colors.black,
                  shape: BoxShape.circle,
                ),
                selectedTextStyle: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                ),
                todayDecoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  border: Border.fromBorderSide(
                    BorderSide(color: Colors.black, width: 2),
                  ),
                ),
                todayTextStyle: const TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                _StepBadge(label: '2'),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Saat seç',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (selectedDay == null)
              const _EmptyState(title: 'Müsait günlerden birini seç')
            else if (selectedSlots.isEmpty)
              _EmptyState(title: emptyTitle)
            else
              _TimeGrid(
                slots: selectedSlots,
                selectedSlot: selectedSlot,
                onSlotSelected: onSlotSelected,
              ),
          ],
        ],
      ),
    );
  }

  static DateTime _dayKey(DateTime day) =>
      DateTime(day.year, day.month, day.day);

  static Map<DateTime, List<SlotDto>> _groupSlots(List<SlotDto> slots) {
    final grouped = <DateTime, List<SlotDto>>{};
    for (final slot in slots) {
      final local = slot.startTime.toLocal();
      (grouped[_dayKey(local)] ??= []).add(slot);
    }
    for (final list in grouped.values) {
      list.sort((a, b) => a.startTime.compareTo(b.startTime));
    }
    return grouped;
  }
}

class _TimeGrid extends StatelessWidget {
  const _TimeGrid({
    required this.slots,
    required this.selectedSlot,
    required this.onSlotSelected,
  });

  final List<SlotDto> slots;
  final SlotDto? selectedSlot;
  final ValueChanged<SlotDto> onSlotSelected;

  @override
  Widget build(BuildContext context) {
    final formatter = DateFormat('HH:mm', 'tr_TR');
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 3.4,
      ),
      itemCount: slots.length,
      itemBuilder: (context, index) {
        final slot = slots[index];
        final selected = selectedSlot?.id == slot.id;
        return Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => onSlotSelected(slot),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: selected ? Colors.black : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.black,
                  width: selected ? 3 : 2,
                ),
                boxShadow: selected
                    ? null
                    : const [
                        BoxShadow(
                          color: Colors.black,
                          blurRadius: 0,
                          offset: Offset(3, 3),
                        ),
                      ],
              ),
              child: Text(
                '${formatter.format(slot.startTime.toLocal())} - ${formatter.format(slot.endTime.toLocal())}',
                style: TextStyle(
                  color: selected ? Colors.white : Colors.black,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _StepBadge extends StatelessWidget {
  const _StepBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 30,
      height: 30,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.black, width: 3),
      ),
      child: Text(label, style: const TextStyle(fontWeight: FontWeight.w900)),
    );
  }
}

class _SlotSummary extends StatelessWidget {
  const _SlotSummary({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.black, width: 2),
      ),
      child: Text(
        '$count saat',
        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black, width: 2),
      ),
      child: Text(
        title,
        textAlign: TextAlign.center,
        style: const TextStyle(fontWeight: FontWeight.w900),
      ),
    );
  }
}

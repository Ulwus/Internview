import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:table_calendar/table_calendar.dart';
import '../../../core/presentation/widgets/neo/neo_background.dart';
import '../../../core/presentation/widgets/penkrowd/animated_action_button.dart';
import '../../../core/presentation/widgets/penkrowd/skeleton_container.dart';

import '../../../core/models/booking_models.dart';
import '../../../core/models/domain_models.dart';
import '../../../core/network/api_exception.dart';
import '../../booking/data/booking_remote_data_source.dart';
import '../../expert/presentation/expert_list_screen.dart';

final _openSlotsForExpertProvider = FutureProvider.family.autoDispose<List<SlotDto>, String>((ref, expertUserId) {
  return ref.watch(bookingRemoteProvider).listOpenSlots(expertUserId);
});

class BookingCreateScreen extends ConsumerStatefulWidget {
  const BookingCreateScreen({super.key});

  @override
  ConsumerState<BookingCreateScreen> createState() => _BookingCreateScreenState();
}

class _BookingCreateScreenState extends ConsumerState<BookingCreateScreen> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  SlotDto? _selectedSlot;
  ExpertSummary? _selectedExpert;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final expertUserId = _selectedExpert?.userId;
    final slotsAsync = expertUserId == null ? null : ref.watch(_openSlotsForExpertProvider(expertUserId));
    final openSlots = (slotsAsync?.valueOrNull ?? const <SlotDto>[]).where((s) => !s.booked).toList();

    final openSlotsByDay = <DateTime, List<SlotDto>>{};
    for (final s in openSlots) {
      final st = s.startTime.toLocal();
      final k = DateTime(st.year, st.month, st.day);
      (openSlotsByDay[k] ??= []).add(s);
    }
    for (final list in openSlotsByDay.values) {
      list.sort((a, b) => a.startTime.compareTo(b.startTime));
    }

    return NeoBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text('Randevu Ekranı'),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                width: double.infinity,
                padding: EdgeInsets.zero,
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.black, width: 3),
                  boxShadow: const [BoxShadow(color: Colors.black, blurRadius: 0, offset: Offset(4, 4))],
                ),
                child: Column(
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16.0),
                      decoration: const BoxDecoration(
                        color: Color(0xFF00E5FF), // Cyan header
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(12),
                          topRight: Radius.circular(12),
                        ),
                        border: Border(bottom: BorderSide(color: Colors.black, width: 3)),
                      ),
                      child: const Text(
                        'Randevu Al',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: InkWell(
                        onTap: () async {
                          final picked = await showModalBottomSheet<ExpertSummary>(
                            context: context,
                            showDragHandle: true,
                            isScrollControlled: true,
                            builder: (context) => const _ExpertPickerSheet(),
                          );
                          if (!mounted) return;
                          if (picked == null) return;
                          setState(() {
                            _selectedExpert = picked;
                            _selectedDay = null;
                            _selectedSlot = null;
                          });
                        },
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.black, width: 3),
                            boxShadow: const [
                              BoxShadow(color: Colors.black, blurRadius: 0, offset: Offset(4, 4)),
                            ],
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  _selectedExpert == null
                                      ? 'Uzman seçin'
                                      : '${_selectedExpert!.firstName} ${_selectedExpert!.lastName}',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const Icon(Icons.arrow_drop_down, color: Colors.black),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFD600),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.black, width: 3),
                          boxShadow: const [BoxShadow(color: Colors.black, blurRadius: 0, offset: Offset(4, 4))],
                        ),
                        child: IgnorePointer(
                          ignoring: _selectedExpert == null,
                          child: Opacity(
                            opacity: _selectedExpert == null ? 0.45 : 1,
                            child: TableCalendar(
                              firstDay: DateTime.now().subtract(const Duration(days: 1)),
                              lastDay: DateTime.now().add(const Duration(days: 45)),
                              focusedDay: _focusedDay,
                              enabledDayPredicate: (day) {
                                final k = DateTime(day.year, day.month, day.day);
                                return openSlotsByDay.containsKey(k);
                              },
                              selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
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
                                titleTextStyle: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                              calendarStyle: const CalendarStyle(
                                selectedDecoration: BoxDecoration(
                                  color: Colors.black,
                                  shape: BoxShape.circle,
                                ),
                                todayDecoration: BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                  border: Border.fromBorderSide(BorderSide(color: Colors.black, width: 2)),
                                ),
                                todayTextStyle: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (_selectedDay != null) ...[
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: Builder(
                          builder: (context) {
                            final k = DateTime(_selectedDay!.year, _selectedDay!.month, _selectedDay!.day);
                            final daySlots = openSlotsByDay[k] ?? const <SlotDto>[];
                            if (daySlots.isEmpty) {
                              return const Text('Bu gün için uygun seans yok.');
                            }
                            return GridView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
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
                                final label =
                                    '${st.hour.toString().padLeft(2, '0')}:${st.minute.toString().padLeft(2, '0')}';
                                return GestureDetector(
                                  onTap: () => setState(() => _selectedSlot = s),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: isSelected ? Colors.black : const Color(0xFFFF5252),
                                      border: Border.all(color: Colors.black, width: 2),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    alignment: Alignment.center,
                                    child: Text(
                                      label,
                                      style: TextStyle(
                                        color: isSelected ? Colors.white : Colors.black,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ),
                                );
                              },
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 24),
              AnimatedActionButton(
                onTap: () async {
                  if (_selectedExpert == null || _selectedSlot == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Önce uzman ve seans seçin')),
                    );
                    return;
                  }
                  try {
                    final b = await ref.read(bookingRemoteProvider).createBooking(
                          expertId: _selectedExpert!.userId,
                          slotId: _selectedSlot!.id,
                        );
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Talep gönderildi (uzman onayı bekleniyor)')),
                      );
                      context.push('/booking/${b.id}');
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
                child: Center(
                  child: Text(
                    'Randevu Oluştur',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 18,
                      color: (_selectedExpert != null && _selectedSlot != null) ? Colors.black : Colors.black54,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}

class _ExpertPickerSheet extends ConsumerStatefulWidget {
  const _ExpertPickerSheet();

  @override
  ConsumerState<_ExpertPickerSheet> createState() => _ExpertPickerSheetState();
}

class _ExpertPickerSheetState extends ConsumerState<_ExpertPickerSheet> {
  final _search = TextEditingController();
  int _page = 0;
  final List<ExpertSummary> _items = [];
  bool _loading = false;
  bool _hasNext = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load({bool refresh = false}) async {
    if (_loading) return;
    if (refresh) {
      _page = 0;
      _items.clear();
      _hasNext = true;
    }
    if (!_hasNext) return;
    setState(() => _loading = true);
    try {
      final res = await ref.read(expertRemoteProvider).searchExperts(
            search: _search.text.trim().isEmpty ? null : _search.text.trim(),
            page: _page,
          );
      setState(() {
        _items.addAll(res.items);
        _hasNext = res.hasNext;
        if (res.hasNext) _page++;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
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
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _search,
                    decoration: const InputDecoration(
                      hintText: 'Uzman ara…',
                      prefixIcon: Icon(Icons.search),
                    ),
                    onSubmitted: (_) => _load(refresh: true),
                  ),
                ),
                const SizedBox(width: 10),
                AnimatedActionButton(
                  onTap: () => _load(refresh: true),
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
              ],
            ),
            const SizedBox(height: 12),
            Flexible(
              child: NotificationListener<ScrollNotification>(
                onNotification: (n) {
                  if (n.metrics.pixels > n.metrics.maxScrollExtent - 200) _load();
                  return false;
                },
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _items.length + (_loading ? 1 : 0),
                  itemBuilder: (context, i) {
                    if (i >= _items.length) {
                      return const Padding(
                        padding: EdgeInsets.all(16),
                        child: Center(child: SkeletonContainer(width: 140, height: 14, borderRadius: 8)),
                      );
                    }
                    final e = _items[i];
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundImage:
                            (e.avatarUrl != null && e.avatarUrl!.isNotEmpty) ? NetworkImage(e.avatarUrl!) : null,
                        child: (e.avatarUrl == null || e.avatarUrl!.isEmpty)
                            ? Text(e.firstName.isNotEmpty ? e.firstName[0].toUpperCase() : '?')
                            : null,
                      ),
                      title: Text('${e.firstName} ${e.lastName}'),
                      subtitle: Text(e.headline ?? ''),
                      onTap: () => Navigator.of(context).pop(e),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

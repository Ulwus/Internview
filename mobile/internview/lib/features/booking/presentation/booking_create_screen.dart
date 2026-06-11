import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/presentation/widgets/neo/neo_background.dart';
import '../../../core/presentation/widgets/penkrowd/animated_action_button.dart';
import '../../../core/presentation/widgets/penkrowd/radial_stat_gauge.dart';
import '../../../core/presentation/widgets/penkrowd/section_card.dart';
import '../../../core/presentation/widgets/penkrowd/skeleton_container.dart';

import '../../../core/models/booking_models.dart';
import '../../../core/models/domain_models.dart';
import '../../../core/network/api_exception.dart';
import '../../booking/data/booking_remote_data_source.dart';
import '../../expert/presentation/expert_list_screen.dart';
import 'booking_slot_picker.dart';

final _openSlotsForExpertProvider = FutureProvider.family
    .autoDispose<List<SlotDto>, String>((ref, expertUserId) {
      return ref.watch(bookingRemoteProvider).listOpenSlots(expertUserId);
    });

class BookingCreateScreen extends ConsumerStatefulWidget {
  const BookingCreateScreen({super.key});

  @override
  ConsumerState<BookingCreateScreen> createState() =>
      _BookingCreateScreenState();
}

class _BookingCreateScreenState extends ConsumerState<BookingCreateScreen> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  SlotDto? _selectedSlot;
  ExpertSummary? _selectedExpert;

  @override
  Widget build(BuildContext context) {
    final expertUserId = _selectedExpert?.userId;
    final slotsAsync = expertUserId == null
        ? null
        : ref.watch(_openSlotsForExpertProvider(expertUserId));
    final slots = slotsAsync?.valueOrNull ?? const <SlotDto>[];

    return NeoBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(title: const Text('Randevu Al')),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            SectionCard(
              title: 'Uzman',
              subtitle: 'Randevu almak istediğin mülakatçıyı seç',
              color: const Color(0xFF00E5FF),
              child: _ExpertSelectCard(
                expert: _selectedExpert,
                onTap: _pickExpert,
              ),
            ),
            const SizedBox(height: 16),
            BookingSlotPicker(
              slots: slots,
              loading: slotsAsync?.isLoading ?? false,
              enabled: _selectedExpert != null,
              focusedDay: _focusedDay,
              selectedDay: _selectedDay,
              selectedSlot: _selectedSlot,
              onPageChanged: (day) => setState(() => _focusedDay = day),
              onDaySelected: (selectedDay, focusedDay) {
                setState(() {
                  _selectedDay = selectedDay;
                  _focusedDay = focusedDay;
                  _selectedSlot = null;
                });
              },
              onSlotSelected: (slot) => setState(() => _selectedSlot = slot),
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
                  final b = await ref
                      .read(bookingRemoteProvider)
                      .createBooking(
                        expertId: _selectedExpert!.userId,
                        slotId: _selectedSlot!.id,
                      );
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Talep gönderildi (uzman onayı bekleniyor)',
                        ),
                      ),
                    );
                    context.push('/booking/${b.id}');
                  }
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
              child: Center(
                child: Text(
                  'Randevu Oluştur',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                    color: (_selectedExpert != null && _selectedSlot != null)
                        ? Colors.black
                        : Colors.black54,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Future<void> _pickExpert() async {
    final picked = await showModalBottomSheet<ExpertSummary>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => const _ExpertPickerSheet(),
    );
    if (!mounted || picked == null) return;
    setState(() {
      _selectedExpert = picked;
      _selectedDay = null;
      _selectedSlot = null;
    });
  }
}

class _ExpertSelectCard extends StatelessWidget {
  const _ExpertSelectCard({required this.expert, required this.onTap});

  final ExpertSummary? expert;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final selected = expert;
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.black, width: 3),
          boxShadow: const [
            BoxShadow(color: Colors.black, blurRadius: 0, offset: Offset(4, 4)),
          ],
        ),
        child: selected == null
            ? const Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: Color(0xFFFFD600),
                    child: Icon(Icons.person_search, color: Colors.black),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Uzman seç',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  Icon(Icons.arrow_drop_down, color: Colors.black),
                ],
              )
            : Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: const Color(0xFFFFD600),
                    backgroundImage:
                        (selected.avatarUrl != null &&
                            selected.avatarUrl!.isNotEmpty)
                        ? NetworkImage(selected.avatarUrl!)
                        : null,
                    child:
                        (selected.avatarUrl == null ||
                            selected.avatarUrl!.isEmpty)
                        ? Text(
                            selected.firstName.isNotEmpty
                                ? selected.firstName[0].toUpperCase()
                                : '?',
                            style: const TextStyle(fontWeight: FontWeight.w900),
                          )
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${selected.firstName} ${selected.lastName}'.trim(),
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if ((selected.headline ?? selected.company ?? '')
                            .trim()
                            .isNotEmpty)
                          Text(
                            (selected.headline ?? selected.company ?? '')
                                .trim(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              color: Colors.black.withValues(alpha: 0.65),
                            ),
                          ),
                        if (selected.hourlyRate != null)
                          Text(
                            '${selected.hourlyRate} ${selected.currency ?? ''}',
                            style: const TextStyle(fontWeight: FontWeight.w900),
                          ),
                      ],
                    ),
                  ),
                  RadialStatGauge(
                    value: selected.averageRating,
                    max: 10,
                    label: 'Puan',
                    size: 58,
                    accentColor: const Color(0xFFB388FF),
                  ),
                ],
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
      final res = await ref
          .read(expertRemoteProvider)
          .searchExperts(
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
                  if (n.metrics.pixels > n.metrics.maxScrollExtent - 200) {
                    _load();
                  }
                  return false;
                },
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _items.length + (_loading ? 1 : 0),
                  itemBuilder: (context, i) {
                    if (i >= _items.length) {
                      return const Padding(
                        padding: EdgeInsets.all(16),
                        child: Center(
                          child: SkeletonContainer(
                            width: 140,
                            height: 14,
                            borderRadius: 8,
                          ),
                        ),
                      );
                    }
                    final e = _items[i];
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundImage:
                            (e.avatarUrl != null && e.avatarUrl!.isNotEmpty)
                            ? NetworkImage(e.avatarUrl!)
                            : null,
                        child: (e.avatarUrl == null || e.avatarUrl!.isEmpty)
                            ? Text(
                                e.firstName.isNotEmpty
                                    ? e.firstName[0].toUpperCase()
                                    : '?',
                              )
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

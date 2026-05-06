import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'dart:async';

import '../../../core/models/booking_models.dart';
import '../../../core/network/api_exception.dart';
import '../data/booking_remote_data_source.dart';
import 'booking_ui_helpers.dart';

class BookingsScreen extends ConsumerStatefulWidget {
  const BookingsScreen({super.key, required this.asExpert});

  final bool asExpert;

  @override
  ConsumerState<BookingsScreen> createState() => _BookingsScreenState();
}

enum _BookingsTab { pending, upcoming, past }

class _BookingsScreenState extends ConsumerState<BookingsScreen> with WidgetsBindingObserver {
  final List<BookingDto> _items = [];
  int _page = 0;
  bool _loading = false;
  bool _hasNext = true;
  _BookingsTab _tab = _BookingsTab.upcoming;
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
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
      _load(refresh: true);
      _startPolling();
    } else if (state == AppLifecycleState.paused) {
      _pollTimer?.cancel();
      _pollTimer = null;
    }
  }

  void _startPolling() {
    _pollTimer?.cancel();
    // "Geçmiş" sekmesinde sürekli anlık yenileme gerekmiyor.
    if (_tab == _BookingsTab.past) return;
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted) return;
      _load(refresh: true);
    });
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
      final res = widget.asExpert
          ? await ref.read(bookingRemoteProvider).listExpertBookings(page: _page)
          : await ref.read(bookingRemoteProvider).listCandidateBookings(page: _page);
      setState(() {
        _items.addAll(res.items);
        _hasNext = res.hasNext;
        if (res.hasNext) _page++;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tabs = <_BookingsTab>[
      _BookingsTab.pending,
      _BookingsTab.upcoming,
      _BookingsTab.past,
    ];
    final tabLabels = <_BookingsTab, String>{
      _BookingsTab.pending: widget.asExpert ? 'Onay Bekleyen' : 'Bekleyen',
      _BookingsTab.upcoming: 'Yaklaşan',
      _BookingsTab.past: 'Geçmiş',
    };

    List<BookingDto> visibleItems() {
      final now = DateTime.now();
      return _items.where((b) {
        switch (_tab) {
          case _BookingsTab.pending:
            return b.status == BookingStatus.pending;
          case _BookingsTab.upcoming:
            return b.status == BookingStatus.confirmed && b.scheduledEnd.toLocal().isAfter(now);
          case _BookingsTab.past:
            return b.status == BookingStatus.completed ||
                b.status == BookingStatus.cancelled ||
                (b.status == BookingStatus.confirmed && b.scheduledEnd.toLocal().isBefore(now));
        }
      }).toList();
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Randevular')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: SizedBox(
              width: double.infinity,
              child: SegmentedButton<_BookingsTab>(
                segments: [
                  for (final t in tabs) ButtonSegment<_BookingsTab>(value: t, label: Text(tabLabels[t]!)),
                ],
                selected: {_tab},
                onSelectionChanged: (s) {
                  setState(() => _tab = s.first);
                  _startPolling();
                  _load(refresh: true);
                },
              ),
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => _load(refresh: true),
              child: NotificationListener<ScrollNotification>(
                onNotification: (n) {
                  if (_tab != _BookingsTab.past && n.metrics.pixels > n.metrics.maxScrollExtent - 200) _load();
                  return false;
                },
                child: Builder(
                  builder: (context) {
                    final v = visibleItems();
                    if (v.isEmpty && !_loading) {
                      return const Center(child: Text('Henüz randevu yok'));
                    }
                    return ListView.builder(
                      itemCount: v.length + (_loading ? 1 : 0),
                      itemBuilder: (context, i) {
                        if (i >= v.length) {
                          return const Padding(
                            padding: EdgeInsets.all(16),
                            child: Center(child: CircularProgressIndicator()),
                          );
                        }
                        final b = v[i];
                        final canJoin = joinWindowAllowed(b) && b.status == BookingStatus.confirmed;
                        final isPending = b.status == BookingStatus.pending;

                        return Card(
                          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          child: ListTile(
                            title: Row(
                              children: [
                                Expanded(child: Text(joinCtaLabel(b), overflow: TextOverflow.ellipsis)),
                                bookingStatusChip(b.status),
                              ],
                            ),
                            subtitle: Text('${b.scheduledStart.toLocal()}'),
                            trailing: widget.asExpert && isPending
                                ? Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      TextButton(
                                        onPressed: () async {
                                          try {
                                            await ref.read(bookingRemoteProvider).rejectBooking(b.id);
                                            if (mounted) _load(refresh: true);
                                          } on ApiException catch (e) {
                                            if (context.mounted) {
                                              ScaffoldMessenger.of(context)
                                                  .showSnackBar(SnackBar(content: Text(e.message)));
                                            }
                                          }
                                        },
                                        child: const Text('Reddet'),
                                      ),
                                      const SizedBox(width: 8),
                                      FilledButton(
                                        onPressed: () async {
                                          try {
                                            await ref.read(bookingRemoteProvider).approveBooking(b.id);
                                            if (mounted) _load(refresh: true);
                                          } on ApiException catch (e) {
                                            if (context.mounted) {
                                              ScaffoldMessenger.of(context)
                                                  .showSnackBar(SnackBar(content: Text(e.message)));
                                            }
                                          }
                                        },
                                        child: const Text('Onayla'),
                                      ),
                                    ],
                                  )
                                : (canJoin)
                                    ? FilledButton.tonal(
                                        onPressed: () => context.push('/interview/${b.id}'),
                                        child: const Text('Katıl'),
                                      )
                                    : null,
                            onTap: () => context.push(
                              b.status == BookingStatus.completed ? '/interview/${b.id}/result' : '/booking/${b.id}',
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

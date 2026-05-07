import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'dart:async';

import '../../../core/models/booking_models.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/presentation/widgets/neo/neo_background.dart';
import '../../../core/presentation/widgets/penkrowd/animated_action_button.dart';
import '../../../core/presentation/widgets/penkrowd/animated_tab_bar.dart';
import '../../../core/presentation/widgets/penkrowd/penkrowd_card.dart';
import '../../../core/presentation/widgets/penkrowd/section_card.dart';
import '../../../core/presentation/widgets/penkrowd/skeleton_container.dart';
import '../../../core/network/dio_client.dart';
import '../data/booking_remote_data_source.dart';
import '../../expert/data/expert_remote_data_source.dart';
import '../../profile/data/profile_remote_data_source.dart';
import '../../../core/models/domain_models.dart';
import 'booking_ui_helpers.dart';

final _expertRemoteDsProvider = Provider<ExpertRemoteDataSource>(
  (ref) => ExpertRemoteDataSource(ref.watch(dioProvider)),
);

final _profileRemoteDsProvider = Provider<ProfileRemoteDataSource>(
  (ref) => ProfileRemoteDataSource(ref.watch(dioProvider)),
);

final _expertByUserIdProvider = FutureProvider.family((ref, String userId) async {
  return ref.read(_expertRemoteDsProvider).getExpertByUserId(userId);
});

final _userByIdProvider = FutureProvider.family((ref, String userId) async {
  return ref.read(_profileRemoteDsProvider).getUserById(userId);
});

class BookingsScreen extends ConsumerStatefulWidget {
  const BookingsScreen({super.key, required this.asExpert, this.initialTab});

  final bool asExpert;
  final String? initialTab;

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
    _tab = switch ((widget.initialTab ?? '').toLowerCase()) {
      'pending' => _BookingsTab.pending,
      'past' => _BookingsTab.past,
      'upcoming' => _BookingsTab.upcoming,
      _ => _BookingsTab.upcoming,
    };
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
      if (!mounted) return;
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

    final selectedIndex = tabs.indexOf(_tab);

    return NeoBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(title: const Text('Randevular')),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
              child: AnimatedTabBar(
                tabs: [for (final t in tabs) tabLabels[t]!],
                selectedIndex: selectedIndex,
                onTabChanged: (i) {
                  setState(() => _tab = tabs[i]);
                  _startPolling();
                  _load(refresh: true);
                },
                selectedColor: Colors.black,
                selectedTextColor: Colors.white,
                unselectedColor: Colors.white,
                unselectedTextColor: Colors.black,
                borderColor: Colors.black,
                borderWidth: 3,
                borderRadius: 14,
                shadowOffset: const Offset(4, 4),
                fontSize: 12,
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
                        return ListView(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                          children: const [
                            SectionCard(
                              title: 'Henüz randevu yok',
                              subtitle: 'Pazar Yerinden bir uzman seçip randevu talebi gönderebilirsin.',
                              color: Color(0xFFFFD600),
                              child: SizedBox.shrink(),
                            ),
                          ],
                        );
                      }
                      return ListView.builder(
                        itemCount: v.length + (_loading ? 1 : 0),
                        itemBuilder: (context, i) {
                          if (i >= v.length) {
                            return const Padding(
                              padding: EdgeInsets.all(16),
                              child: Center(child: SkeletonContainer(width: 140, height: 14, borderRadius: 8)),
                            );
                          }
                          final b = v[i];
                          final canJoin = joinWindowAllowed(b) && b.status == BookingStatus.confirmed;
                          final isPending = b.status == BookingStatus.pending;
                          final hasTrailing = (widget.asExpert && isPending) || canJoin;
                          final accent = switch (b.status) {
                            BookingStatus.pending => const Color(0xFFFF9100),
                            BookingStatus.confirmed => const Color(0xFF00E5FF),
                            BookingStatus.completed => const Color(0xFFB388FF),
                            BookingStatus.cancelled => const Color(0xFFFF5252),
                          };

                          final otherAsync = widget.asExpert
                              ? ref.watch(_userByIdProvider(b.candidateId))
                              : ref.watch(_expertByUserIdProvider(b.expertId));

                          Widget avatarFromProfile({required String? avatarUrl, required String fallbackLetter}) {
                            return CircleAvatar(
                              radius: 18,
                              backgroundColor: Colors.white,
                              backgroundImage: (avatarUrl != null && avatarUrl.isNotEmpty) ? NetworkImage(avatarUrl) : null,
                              child: (avatarUrl == null || avatarUrl.isEmpty)
                                  ? Text(
                                      fallbackLetter.isNotEmpty ? fallbackLetter[0].toUpperCase() : '?',
                                      style: const TextStyle(fontWeight: FontWeight.w900, color: Colors.black),
                                    )
                                  : null,
                            );
                          }

                          return Padding(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                            child: PenkrowdCard(
                              accentColor: accent,
                              leading: otherAsync.when(
                                data: (d) {
                                  if (d is ExpertDetail) {
                                    return avatarFromProfile(
                                      avatarUrl: d.avatarUrl,
                                      fallbackLetter: d.firstName.isNotEmpty ? d.firstName : '?',
                                    );
                                  }
                                  final p = d as UserProfile;
                                  return avatarFromProfile(
                                    avatarUrl: p.avatarUrl,
                                    fallbackLetter: p.firstName.isNotEmpty ? p.firstName : '?',
                                  );
                                },
                                loading: () => const SkeletonContainer(width: 36, height: 36, borderRadius: 18),
                                error: (e, _) => const CircleAvatar(
                                  radius: 18,
                                  backgroundColor: Colors.white,
                                  child: Text('?', style: TextStyle(fontWeight: FontWeight.w900, color: Colors.black)),
                                ),
                              ),
                              title: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: otherAsync.when(
                                          data: (d) {
                                            if (d is ExpertDetail) {
                                              return Text(
                                                '${d.firstName} ${d.lastName}',
                                                overflow: TextOverflow.ellipsis,
                                                maxLines: 1,
                                              );
                                            }
                                            final p = d as UserProfile;
                                            return Text(
                                              '${p.firstName} ${p.lastName}',
                                              overflow: TextOverflow.ellipsis,
                                              maxLines: 1,
                                            );
                                          },
                                          loading: () =>
                                              const SkeletonContainer(width: 140, height: 12, borderRadius: 8),
                                          error: (e, _) => Text(
                                            joinCtaLabel(b),
                                            overflow: TextOverflow.ellipsis,
                                            maxLines: 1,
                                          ),
                                        ),
                                      ),
                                      if (!hasTrailing) ...[
                                        const SizedBox(width: 8),
                                        Text(
                                          bookingStatusMiniLabel(b),
                                          style: TextStyle(
                                            fontWeight: FontWeight.w900,
                                            fontSize: 11,
                                            color: Colors.black.withValues(alpha: 0.65),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    formatBookingWhen(b),
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 1,
                                    style: const TextStyle(fontWeight: FontWeight.w700),
                                  ),
                                  if (!widget.asExpert)
                                    otherAsync.when(
                                      data: (d) {
                                        final e = d as ExpertDetail;
                                        return (e.industry?.name != null && e.industry!.name.isNotEmpty)
                                            ? Padding(
                                                padding: const EdgeInsets.only(top: 4),
                                                child: Text(
                                                  e.industry!.name,
                                                  overflow: TextOverflow.ellipsis,
                                                  maxLines: 1,
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.w800,
                                                    color: Colors.black.withValues(alpha: 0.7),
                                                  ),
                                                ),
                                              )
                                            : const SizedBox.shrink();
                                      },
                                      loading: () => const SizedBox.shrink(),
                                      error: (e, _) => const SizedBox.shrink(),
                                    ),
                                ],
                              ),
                              onTap: () => context.push(
                                b.status == BookingStatus.completed ? '/interview/${b.id}/result' : '/booking/${b.id}',
                              ),
                              trailing: widget.asExpert && isPending
                                  ? Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        AnimatedActionButton(
                                          onTap: () async {
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
                                          width: 88,
                                          height: 40,
                                          color: Colors.white,
                                          pressedColor: Colors.white,
                                          borderColor: Colors.black,
                                          borderWidth: 3,
                                          borderRadius: 14,
                                          shadowOffset: const Offset(4, 4),
                                          child: const Center(
                                            child: Text(
                                              'Reddet',
                                              style: TextStyle(
                                                fontWeight: FontWeight.w900,
                                                fontSize: 12,
                                                color: Colors.black,
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        AnimatedActionButton(
                                          onTap: () async {
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
                                          width: 88,
                                          height: 40,
                                          color: const Color(0xFFFF9100),
                                          pressedColor: const Color(0xFFFF9100),
                                          borderColor: Colors.black,
                                          borderWidth: 3,
                                          borderRadius: 14,
                                          shadowOffset: const Offset(4, 4),
                                          child: const Center(
                                            child: Text(
                                              'Onayla',
                                              style: TextStyle(
                                                fontWeight: FontWeight.w900,
                                                fontSize: 12,
                                                color: Colors.black,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    )
                                  : (canJoin)
                                      ? AnimatedActionButton(
                                          onTap: () => context.push('/interview/${b.id}'),
                                          width: 72,
                                          height: 40,
                                          color: const Color(0xFF00E5FF),
                                          pressedColor: const Color(0xFF00E5FF),
                                          borderColor: Colors.black,
                                          borderWidth: 3,
                                          borderRadius: 14,
                                          shadowOffset: const Offset(4, 4),
                                          child: const Center(
                                            child: Text(
                                              'Katıl',
                                              style: TextStyle(
                                                fontWeight: FontWeight.w900,
                                                fontSize: 12,
                                                color: Colors.black,
                                              ),
                                            ),
                                          ),
                                        )
                                      : null,
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
      ),
    );
  }
}

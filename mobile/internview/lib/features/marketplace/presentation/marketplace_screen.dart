import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/models/shop_models.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/presentation/widgets/neo/neo_background.dart';
import '../../../core/presentation/widgets/penkrowd/animated_action_button.dart';
import '../../../core/presentation/widgets/penkrowd/penkrowd_card.dart';
import '../../../core/presentation/widgets/penkrowd/radial_stat_gauge.dart';
import '../../../core/presentation/widgets/penkrowd/skeleton_container.dart';
import '../../auth/controllers/auth_controller.dart';
import '../../expert/presentation/expert_list_screen.dart';
import '../data/marketplace_remote_data_source.dart';

final industriesProvider = FutureProvider.autoDispose((ref) {
  return ref.watch(expertRemoteProvider).listIndustries();
});

final skillsProvider = FutureProvider.autoDispose((ref) {
  return ref.watch(expertRemoteProvider).listSkills();
});

final _myShopProvider = FutureProvider.autoDispose<ShopSummaryDto?>((
  ref,
) async {
  return ref.watch(marketplaceRemoteProvider).getMyShop();
});

class MarketplaceScreen extends ConsumerStatefulWidget {
  const MarketplaceScreen({super.key});

  @override
  ConsumerState<MarketplaceScreen> createState() => _MarketplaceScreenState();
}

class _MarketplaceScreenState extends ConsumerState<MarketplaceScreen> {
  final List<ShopSummaryDto> _items = [];
  int _page = 0;
  bool _loading = false;
  bool _hasNext = true;

  String? _industrySlug;
  final Set<String> _skillSlugs = {};
  double? _minRating;
  double? _minPrice;
  double? _maxPrice;
  bool? _isAvailable;

  @override
  void initState() {
    super.initState();
    _load();
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
          .read(marketplaceRemoteProvider)
          .listShops(
            page: _page,
            size: 20,
            industrySlug: _industrySlug,
            skillSlugs: _skillSlugs,
            minRating: _minRating,
            minPrice: _minPrice,
            maxPrice: _maxPrice,
            isAvailable: _isAvailable,
            publishedOnly: true,
          );
      if (!mounted) return;
      setState(() {
        _items.addAll(res.items);
        _hasNext = res.hasNext;
        if (res.hasNext) _page++;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openFilters() async {
    final res = await showModalBottomSheet<_FiltersState>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) => _FiltersSheet(
        initial: _FiltersState(
          industrySlug: _industrySlug,
          skillSlugs: _skillSlugs,
          minRating: _minRating,
          minPrice: _minPrice,
          maxPrice: _maxPrice,
          isAvailable: _isAvailable,
        ),
      ),
    );
    if (!mounted || res == null) return;
    setState(() {
      _industrySlug = res.industrySlug;
      _skillSlugs
        ..clear()
        ..addAll(res.skillSlugs);
      _minRating = res.minRating;
      _minPrice = res.minPrice;
      _maxPrice = res.maxPrice;
      _isAvailable = res.isAvailable;
    });
    await _load(refresh: true);
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    final isExpert = auth?.role.toUpperCase() == 'EXPERT';
    final myShopAsync = isExpert ? ref.watch(_myShopProvider) : null;

    return NeoBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text('Pazar Yeri'),
          actions: [
            if (isExpert)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: myShopAsync!.when(
                  loading: () => const SkeletonContainer(
                    width: 98,
                    height: 40,
                    borderRadius: 14,
                  ),
                  error: (_, __) => AnimatedActionButton(
                    onTap: () async {
                      await context.push('/shop-me');
                      ref.invalidate(_myShopProvider);
                      await _load(refresh: true);
                    },
                    width: 106,
                    height: 46,
                    color: Colors.white,
                    pressedColor: Colors.white,
                    borderColor: Colors.black,
                    borderWidth: 3,
                    borderRadius: 14,
                    shadowOffset: const Offset(4, 4),
                    child: const Center(
                      child: Text(
                        'Dükkanım',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 12,
                          color: Colors.black,
                        ),
                      ),
                    ),
                  ),
                  data: (s) => AnimatedActionButton(
                    onTap: () async {
                      await context.push('/shop-me');
                      ref.invalidate(_myShopProvider);
                      await _load(refresh: true);
                    },
                    width: 132,
                    height: 46,
                    color: const Color(0xFFFFD600),
                    pressedColor: const Color(0xFFFFD600),
                    borderColor: Colors.black,
                    borderWidth: 3,
                    borderRadius: 14,
                    shadowOffset: const Offset(4, 4),
                    child: Center(
                      child: Text(
                        (s == null) ? 'İlan oluştur' : 'İlanı düzenle',
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 12,
                          color: Colors.black,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: AnimatedActionButton(
                onTap: _openFilters,
                width: 46,
                height: 46,
                color: Colors.white,
                pressedColor: Colors.white,
                borderColor: Colors.black,
                borderWidth: 3,
                borderRadius: 14,
                shadowOffset: const Offset(4, 4),
                child: const Icon(Icons.tune, color: Colors.black),
              ),
            ),
          ],
        ),
        body: RefreshIndicator(
          onRefresh: () => _load(refresh: true),
          child: NotificationListener<ScrollNotification>(
            onNotification: (n) {
              if (n.metrics.pixels > n.metrics.maxScrollExtent - 200) _load();
              return false;
            },
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              itemCount: (_items.isEmpty && _loading)
                  ? 8
                  : _items.isEmpty
                  ? 1
                  : _items.length + (_loading ? 1 : 0),
              itemBuilder: (context, i) {
                if (_items.isEmpty && _loading) {
                  return const Padding(
                    padding: EdgeInsets.only(bottom: 12),
                    child: SkeletonContainer(
                      width: double.infinity,
                      height: 74,
                      borderRadius: 18,
                    ),
                  );
                }
                if (_items.isEmpty && !_loading) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: PenkrowdCard(
                      accentColor: const Color(0xFFB388FF),
                      title: const Text(
                        'Henüz ilan yok',
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                      subtitle: Text(
                        isExpert
                            ? 'İlanını oluşturup yayınlayarak pazar yerinde görünür olabilirsin.'
                            : 'Filtreleri temizleyip tekrar deneyebilirsin.',
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: isExpert
                          ? AnimatedActionButton(
                              onTap: () async {
                                await context.push('/shop-me');
                                ref.invalidate(_myShopProvider);
                                await _load(refresh: true);
                              },
                              width: 118,
                              height: 40,
                              color: const Color(0xFFFFD600),
                              pressedColor: const Color(0xFFFFD600),
                              borderColor: Colors.black,
                              borderWidth: 3,
                              borderRadius: 14,
                              shadowOffset: const Offset(4, 4),
                              child: const Center(
                                child: Text(
                                  'İlan oluştur',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 12,
                                    color: Colors.black,
                                  ),
                                ),
                              ),
                            )
                          : null,
                      onTap: isExpert
                          ? () async {
                              await context.push('/shop-me');
                              ref.invalidate(_myShopProvider);
                              await _load(refresh: true);
                            }
                          : null,
                    ),
                  );
                }
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
                final s = _items[i];
                final accent = (s.isAvailable ?? false)
                    ? const Color(0xFF00E5FF)
                    : const Color(0xFFFFD600);
                final industry = s.industry?.name;
                final price = (s.hourlyRate != null)
                    ? '${s.hourlyRate} ${s.currency ?? ''}'
                    : null;
                final skills = s.skills.take(3).map((e) => e.name).toList();
                final meta = [
                  if (industry != null && industry.isNotEmpty) industry,
                  if (price != null && price.trim().isNotEmpty) price,
                ].join(' • ');

                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: PenkrowdCard(
                    accentColor: accent,
                    leading: CircleAvatar(
                      radius: 18,
                      backgroundColor: Colors.white,
                      backgroundImage:
                          (s.expertAvatarUrl != null &&
                              s.expertAvatarUrl!.isNotEmpty)
                          ? NetworkImage(s.expertAvatarUrl!)
                          : null,
                      child:
                          (s.expertAvatarUrl == null ||
                              s.expertAvatarUrl!.isEmpty)
                          ? Text(
                              (s.expertFirstName.isNotEmpty
                                      ? s.expertFirstName[0]
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
                      s.expertFullName,
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (meta.isNotEmpty)
                          Text(
                            meta,
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        if ((s.description ?? '').trim().isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            s.description!.trim(),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 2,
                          ),
                        ],
                        if (skills.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              for (final skill in skills)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(999),
                                    border: Border.all(
                                      color: Colors.black,
                                      width: 2,
                                    ),
                                  ),
                                  child: Text(
                                    skill,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w900,
                                      fontSize: 11,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ],
                    ),
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
                          (s.isAvailable ?? false) ? 'Müsait' : 'Kısıtlı',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 11,
                            color: Colors.black.withValues(alpha: 0.65),
                          ),
                        ),
                      ],
                    ),
                    onTap: () => context.push('/shop/${s.id}'),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _FiltersState {
  _FiltersState({
    required this.industrySlug,
    required this.skillSlugs,
    required this.minRating,
    required this.minPrice,
    required this.maxPrice,
    required this.isAvailable,
  });

  final String? industrySlug;
  final Set<String> skillSlugs;
  final double? minRating;
  final double? minPrice;
  final double? maxPrice;
  final bool? isAvailable;
}

class _FiltersSheet extends ConsumerStatefulWidget {
  const _FiltersSheet({required this.initial});

  final _FiltersState initial;

  @override
  ConsumerState<_FiltersSheet> createState() => _FiltersSheetState();
}

class _FiltersSheetState extends ConsumerState<_FiltersSheet> {
  String? _industrySlug;
  final Set<String> _skillSlugs = {};
  final _minRating = TextEditingController();
  final _minPrice = TextEditingController();
  final _maxPrice = TextEditingController();
  bool? _isAvailable;

  @override
  void initState() {
    super.initState();
    _industrySlug = widget.initial.industrySlug;
    _skillSlugs.addAll(widget.initial.skillSlugs);
    _minRating.text = widget.initial.minRating?.toString() ?? '';
    _minPrice.text = widget.initial.minPrice?.toString() ?? '';
    _maxPrice.text = widget.initial.maxPrice?.toString() ?? '';
    _isAvailable = widget.initial.isAvailable;
  }

  @override
  void dispose() {
    _minRating.dispose();
    _minPrice.dispose();
    _maxPrice.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final industries = ref.watch(industriesProvider);
    final skills = ref.watch(skillsProvider);

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
            Text('Filtreler', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            industries.when(
              loading: () => const SkeletonContainer(
                width: double.infinity,
                height: 12,
                borderRadius: 8,
              ),
              error: (e, _) => Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        e is ApiException ? e.message : 'Sektörler yüklenemedi',
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                    ),
                    const SizedBox(width: 8),
                    AnimatedActionButton(
                      onTap: () => ref.invalidate(industriesProvider),
                      width: 104,
                      height: 40,
                      color: Colors.white,
                      pressedColor: Colors.white,
                      borderColor: Colors.black,
                      borderWidth: 2,
                      borderRadius: 12,
                      shadowOffset: const Offset(3, 3),
                      child: const Center(
                        child: Text(
                          'Tekrar dene',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 12,
                            color: Colors.black,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              data: (inds) => DropdownButtonFormField<String?>(
                value: _industrySlug,
                decoration: const InputDecoration(labelText: 'Sektör'),
                items: [
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text('Hepsi'),
                  ),
                  ...inds.map(
                    (i) => DropdownMenuItem<String?>(
                      value: i.slug,
                      child: Text(i.name),
                    ),
                  ),
                ],
                onChanged: (v) => setState(() => _industrySlug = v),
              ),
            ),
            const SizedBox(height: 12),
            skills.when(
              loading: () => const SkeletonContainer(
                width: double.infinity,
                height: 12,
                borderRadius: 8,
              ),
              error: (_, __) => const SizedBox.shrink(),
              data: (sk) => Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final s in sk)
                    FilterChip(
                      label: Text(s.name),
                      selected: _skillSlugs.contains(s.slug),
                      onSelected: (sel) => setState(() {
                        if (sel) {
                          _skillSlugs.add(s.slug);
                        } else {
                          _skillSlugs.remove(s.slug);
                        }
                      }),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _minPrice,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Min fiyat'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _maxPrice,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Max fiyat'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _minRating,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Min puan (1-10)'),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<bool?>(
              value: _isAvailable,
              decoration: const InputDecoration(labelText: 'Müsaitlik'),
              items: const [
                DropdownMenuItem(value: null, child: Text('Hepsi')),
                DropdownMenuItem(value: true, child: Text('Sadece müsait')),
                DropdownMenuItem(value: false, child: Text('Müsait değil')),
              ],
              onChanged: (v) => setState(() => _isAvailable = v),
            ),
            const SizedBox(height: 16),
            AnimatedActionButton(
              onTap: () {
                Navigator.of(context).pop(
                  _FiltersState(
                    industrySlug: _industrySlug,
                    skillSlugs: _skillSlugs,
                    minRating: double.tryParse(_minRating.text),
                    minPrice: double.tryParse(_minPrice.text),
                    maxPrice: double.tryParse(_maxPrice.text),
                    isAvailable: _isAvailable,
                  ),
                );
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
                  'Uygula',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                    color: Colors.black,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/models/booking_models.dart';
import '../../../core/models/shop_models.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/presentation/widgets/neo/neo_background.dart';
import '../../../core/presentation/widgets/penkrowd/animated_action_button.dart';
import '../../../core/presentation/widgets/penkrowd/skeleton_container.dart';
import '../../booking/data/booking_remote_data_source.dart';
import 'marketplace_screen.dart';
import '../data/marketplace_remote_data_source.dart';

final _myShopProvider = FutureProvider.autoDispose<ShopSummaryDto?>((ref) async {
  return ref.watch(marketplaceRemoteProvider).getMyShop();
});

final _mySlotsProvider = FutureProvider.autoDispose<List<SlotDto>>((ref) async {
  return ref.watch(bookingRemoteProvider).listMySlots();
});

class ShopMeScreen extends ConsumerStatefulWidget {
  const ShopMeScreen({super.key});

  @override
  ConsumerState<ShopMeScreen> createState() => _ShopMeScreenState();
}

class _ShopMeScreenState extends ConsumerState<ShopMeScreen> {
  final _desc = TextEditingController();
  final _years = TextEditingController();
  final _rate = TextEditingController();
  String _currency = 'TRY';
  String? _industrySlug;
  final Set<String> _skillSlugs = {};
  bool _published = false;
  bool _saving = false;
  bool _seeded = false;

  @override
  void dispose() {
    _desc.dispose();
    _years.dispose();
    _rate.dispose();
    super.dispose();
  }

  void _syncFrom(ShopSummaryDto? s) {
    if (s == null) return;
    _desc.text = s.description ?? '';
    _years.text = s.yearsOfExperience.toString();
    _rate.text = s.hourlyRate?.toString() ?? '';
    _currency = s.currency ?? _currency;
    _industrySlug = s.industry?.slug;
    _skillSlugs
      ..clear()
      ..addAll(s.skills.map((e) => e.slug));
    _published = s.isPublished;
  }

  @override
  Widget build(BuildContext context) {
    final meShop = ref.watch(_myShopProvider);
    final industries = ref.watch(industriesProvider);
    final skills = ref.watch(skillsProvider);
    final mySlots = ref.watch(_mySlotsProvider);

    return NeoBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(title: const Text('Dükkanım')),
        body: meShop.when(
          loading: () => const Center(child: SkeletonContainer(width: 220, height: 14, borderRadius: 8)),
          error: (e, _) => Center(child: Text(e is ApiException ? e.message : 'Dükkan yüklenemedi')),
          data: (s) {
            if (!_seeded) {
              _seeded = true;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) setState(() => _syncFrom(s));
              });
            }
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (s != null) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.black, width: 3),
                      boxShadow: const [BoxShadow(color: Colors.black, blurRadius: 0, offset: Offset(4, 4))],
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 22,
                          backgroundColor: Colors.white,
                          backgroundImage: (s.expertAvatarUrl != null && s.expertAvatarUrl!.isNotEmpty)
                              ? NetworkImage(s.expertAvatarUrl!)
                              : null,
                          child: (s.expertAvatarUrl == null || s.expertAvatarUrl!.isEmpty)
                              ? Text(
                                  (s.expertFirstName.isNotEmpty ? s.expertFirstName[0] : '?').toUpperCase(),
                                  style: const TextStyle(fontWeight: FontWeight.w900, color: Colors.black),
                                )
                              : null,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(s.expertFullName, style: Theme.of(context).textTheme.titleMedium),
                              const SizedBox(height: 2),
                              Text(
                                _published ? 'Pazarda yayında' : 'Taslak (yayında değil)',
                                style: TextStyle(fontWeight: FontWeight.w900, color: Colors.black.withValues(alpha: 0.6)),
                              ),
                            ],
                          ),
                        ),
                        AnimatedActionButton(
                          onTap: () async {
                            await context.push('/expert-availability');
                            ref.invalidate(_mySlotsProvider);
                          },
                          width: 150,
                          height: 44,
                          color: const Color(0xFFFFD600),
                          pressedColor: const Color(0xFFFFD600),
                          borderColor: Colors.black,
                          borderWidth: 3,
                          borderRadius: 14,
                          shadowOffset: const Offset(4, 4),
                          child: const Center(
                            child: Text(
                              'Müsaitlik ayarla',
                              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12, color: Colors.black),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  mySlots.when(
                    loading: () => const SkeletonContainer(width: double.infinity, height: 12, borderRadius: 8),
                    error: (e, _) => Text(e is ApiException ? e.message : 'Müsaitlik yüklenemedi'),
                    data: (slots) {
                      final open = slots.where((x) => !x.booked).length;
                      return Text(
                        'Müsait seans: $open',
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      );
                    },
                  ),
                  const SizedBox(height: 14),
                ],
                TextField(
                  controller: _desc,
                  maxLines: 5,
                  decoration: const InputDecoration(labelText: 'Açıklama'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _years,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Tecrübe (yıl)'),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _rate,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Saatlik ücret'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    SizedBox(
                      width: 110,
                      child: DropdownButtonFormField<String>(
                        value: _currency,
                        decoration: const InputDecoration(labelText: 'Para'),
                        items: const [
                          DropdownMenuItem(value: 'TRY', child: Text('TRY')),
                          DropdownMenuItem(value: 'USD', child: Text('USD')),
                          DropdownMenuItem(value: 'EUR', child: Text('EUR')),
                        ],
                        onChanged: (v) => setState(() => _currency = v ?? 'TRY'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                industries.when(
                  loading: () => const SkeletonContainer(width: double.infinity, height: 12, borderRadius: 8),
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
                              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12, color: Colors.black),
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
                      const DropdownMenuItem<String?>(value: null, child: Text('Seçiniz')),
                      ...inds.map((i) => DropdownMenuItem<String?>(value: i.slug, child: Text(i.name))),
                    ],
                    onChanged: (v) => setState(() => _industrySlug = v),
                  ),
                ),
                const SizedBox(height: 12),
                skills.when(
                  loading: () => const SkeletonContainer(width: double.infinity, height: 12, borderRadius: 8),
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
                SwitchListTile(
                  title: const Text('Pazarda yayınla'),
                  value: _published,
                  onChanged: (v) => setState(() => _published = v),
                ),
                const SizedBox(height: 12),
                AnimatedActionButton(
                  onTap: _saving
                      ? null
                      : () async {
                          setState(() => _saving = true);
                          try {
                            final updated = await ref.read(marketplaceRemoteProvider).upsertMyShop(
                                  description: _desc.text.trim(),
                                  yearsOfExperience: int.tryParse(_years.text) ?? 0,
                                  hourlyRate: double.tryParse(_rate.text) ?? 0,
                                  currency: _currency,
                                  industrySlug: _industrySlug,
                                  skillSlugs: _skillSlugs,
                                  isPublished: _published,
                                );
                            ref.invalidate(_myShopProvider);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Kaydedildi')));
                              setState(() => _syncFrom(updated));
                            }
                          } on ApiException catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
                            }
                          } finally {
                            if (mounted) setState(() => _saving = false);
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
                    child: _saving
                        ? const SkeletonContainer(width: 120, height: 14, borderRadius: 8)
                        : const Text('Kaydet', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Colors.black)),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}


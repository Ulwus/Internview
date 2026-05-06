import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/models/domain_models.dart';
import '../../../core/network/api_exception.dart';
import 'expert_list_screen.dart';

final expertMeProvider = FutureProvider.autoDispose((ref) {
  return ref.watch(expertRemoteProvider).getExpertMe();
});

final industriesProvider = FutureProvider.autoDispose((ref) {
  return ref.watch(expertRemoteProvider).listIndustries();
});

final skillsProvider = FutureProvider.autoDispose((ref) {
  return ref.watch(expertRemoteProvider).listSkills();
});

class ExpertSelfScreen extends ConsumerStatefulWidget {
  const ExpertSelfScreen({super.key});

  @override
  ConsumerState<ExpertSelfScreen> createState() => _ExpertSelfScreenState();
}

class _ExpertSelfScreenState extends ConsumerState<ExpertSelfScreen> {
  final _rate = TextEditingController();
  String? _industrySlug;
  final Set<String> _skillSlugs = {};
  bool _available = true;
  bool _saving = false;
  bool _seeded = false;

  @override
  void dispose() {
    _rate.dispose();
    super.dispose();
  }

  void _syncFrom(ExpertDetail d) {
    _industrySlug = d.industry?.slug;
    _skillSlugs
      ..clear()
      ..addAll(d.skills.map((s) => s.slug));
    _available = d.isAvailable ?? false;
    _rate.text = d.hourlyRate?.toString() ?? '';
  }

  @override
  Widget build(BuildContext context) {
    final me = ref.watch(expertMeProvider);
    final industries = ref.watch(industriesProvider);
    final skills = ref.watch(skillsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Uzman profilim')),
      body: me.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (d) {
          if (!_seeded) {
            _seeded = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) setState(() => _syncFrom(d));
            });
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text('${d.firstName} ${d.lastName}', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              industries.when(
                loading: () => const LinearProgressIndicator(),
                error: (error, stackTrace) => const SizedBox.shrink(),
                data: (inds) => DropdownButtonFormField<String>(
                  // ignore: deprecated_member_use
                  value: _industrySlug,
                  decoration: const InputDecoration(labelText: 'Sektör'),
                  items: inds
                      .map((i) => DropdownMenuItem(value: i.slug, child: Text(i.name)))
                      .toList(),
                  onChanged: (v) => setState(() => _industrySlug = v),
                ),
              ),
              const SizedBox(height: 12),
              skills.when(
                loading: () => const LinearProgressIndicator(),
                error: (error, stackTrace) => const SizedBox.shrink(),
                data: (sk) => Wrap(
                  spacing: 8,
                  children: sk
                      .map(
                        (s) => FilterChip(
                          label: Text(s.name),
                          selected: _skillSlugs.contains(s.slug),
                          onSelected: (sel) {
                            setState(() {
                              if (sel) {
                                _skillSlugs.add(s.slug);
                              } else {
                                _skillSlugs.remove(s.slug);
                              }
                            });
                          },
                        ),
                      )
                      .toList(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _rate,
                decoration: const InputDecoration(labelText: 'Saatlik ücret'),
                keyboardType: TextInputType.number,
              ),
              SwitchListTile(
                title: const Text('Müsait'),
                value: _available,
                onChanged: (v) => setState(() => _available = v),
              ),
              FilledButton(
                onPressed: _saving
                    ? null
                    : () async {
                        setState(() => _saving = true);
                        try {
                          await ref.read(expertRemoteProvider).updateExpertMe({
                            if (_industrySlug != null) 'industrySlug': _industrySlug,
                            'skillSlugs': _skillSlugs.toList(),
                            'hourlyRate': double.tryParse(_rate.text) ?? 0,
                            'currency': d.currency ?? 'TRY',
                            'isAvailable': _available,
                          });
                          ref.invalidate(expertMeProvider);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Kaydedildi')));
                            context.pop();
                          }
                        } on ApiException catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
                          }
                        } finally {
                          if (mounted) setState(() => _saving = false);
                        }
                      },
                child: _saving ? const CircularProgressIndicator() : const Text('Kaydet'),
              ),
            ],
          );
        },
      ),
    );
  }
}

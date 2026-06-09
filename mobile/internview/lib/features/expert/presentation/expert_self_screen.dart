import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/models/domain_models.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/presentation/widgets/neo/neo_background.dart';
import '../../../core/presentation/widgets/penkrowd/animated_action_button.dart';
import '../../../core/presentation/widgets/penkrowd/skeleton_container.dart';
import 'expert_list_screen.dart';

final expertMeProvider = FutureProvider.autoDispose((ref) {
  return ref.watch(expertRemoteProvider).getExpertMe();
});

class ExpertSelfScreen extends ConsumerStatefulWidget {
  const ExpertSelfScreen({super.key});

  @override
  ConsumerState<ExpertSelfScreen> createState() => _ExpertSelfScreenState();
}

class _ExpertSelfScreenState extends ConsumerState<ExpertSelfScreen> {
  bool _seeded = false;

  @override
  void dispose() {
    super.dispose();
  }

  void _syncFrom(ExpertDetail d) {}

  @override
  Widget build(BuildContext context) {
    final me = ref.watch(expertMeProvider);

    return NeoBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(title: const Text('Uzman ayarları')),
        body: me.when(
          loading: () => const Center(child: SkeletonContainer(width: 220, height: 14, borderRadius: 8)),
          error: (e, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                e is ApiException ? e.message : 'Uzman profili yüklenemedi',
                textAlign: TextAlign.center,
              ),
            ),
          ),
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
                AnimatedActionButton(
                  onTap: () => context.push('/shop-me'),
                  width: double.infinity,
                  height: 48,
                  color: const Color(0xFF00E5FF),
                  pressedColor: const Color(0xFF00E5FF),
                  borderColor: Colors.black,
                  borderWidth: 3,
                  borderRadius: 14,
                  shadowOffset: const Offset(4, 4),
                  child: Center(
                    child: const Text(
                      'Dükkanımı düzenle',
                      style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Colors.black),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Müsaitlik yönetimi artık sadece Pazar Yeri > Dükkanım ekranından yapılır.',
                  style: TextStyle(fontWeight: FontWeight.w900, color: Colors.black.withValues(alpha: 0.7)),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

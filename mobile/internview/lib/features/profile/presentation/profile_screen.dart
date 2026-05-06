import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/models/domain_models.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/presentation/widgets/neo/neo_background.dart';
import '../../../core/presentation/widgets/neo/neo_box.dart';
import '../../../core/presentation/widgets/neo/neo_button.dart';
import '../../auth/controllers/auth_controller.dart';
import '../data/profile_remote_data_source.dart';

final profileRemoteProvider = Provider<ProfileRemoteDataSource>(
  (ref) => ProfileRemoteDataSource(ref.watch(dioProvider)),
);

final userProfileProvider = FutureProvider.autoDispose<UserProfile>((ref) async {
  return ref.watch(profileRemoteProvider).getProfile();
});

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final _first = TextEditingController();
  final _last = TextEditingController();
  final _avatar = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _first.dispose();
    _last.dispose();
    _avatar.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await ref.read(profileRemoteProvider).updateProfile(
            firstName: _first.text.trim(),
            lastName: _last.text.trim(),
            avatarUrl: _avatar.text.trim().isEmpty ? null : _avatar.text.trim(),
          );
      ref.invalidate(userProfileProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profil güncellendi')));
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    final role = auth?.role.toUpperCase() ?? '';

    return NeoBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(title: const Text('Profil')),
        body: ref.watch(userProfileProvider).when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('$e')),
            data: (p) {
              if (_first.text.isEmpty && _last.text.isEmpty) {
                _first.text = p.firstName;
                _last.text = p.lastName;
                _avatar.text = p.avatarUrl ?? '';
              }
              return ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  NeoBox(
                    color: Theme.of(context).colorScheme.surface,
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 28,
                          backgroundImage:
                              (p.avatarUrl != null && p.avatarUrl!.isNotEmpty) ? NetworkImage(p.avatarUrl!) : null,
                          child: (p.avatarUrl == null || p.avatarUrl!.isEmpty)
                              ? Text(
                                  (p.firstName.isNotEmpty ? p.firstName[0] : '?').toUpperCase(),
                                  style: const TextStyle(fontWeight: FontWeight.w900),
                                )
                              : null,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('${p.firstName} ${p.lastName}', style: Theme.of(context).textTheme.titleLarge),
                              const SizedBox(height: 2),
                              Text(p.email, style: Theme.of(context).textTheme.bodyMedium),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.tertiary,
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(color: Colors.black, width: 2),
                          ),
                          child: Text(
                            p.role,
                            style: const TextStyle(fontWeight: FontWeight.w900),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  NeoBox(
                    color: Theme.of(context).colorScheme.surface,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text('Kişisel bilgiler', style: Theme.of(context).textTheme.titleLarge),
                        const SizedBox(height: 12),
                        TextField(controller: _first, decoration: const InputDecoration(labelText: 'Ad')),
                        const SizedBox(height: 12),
                        TextField(controller: _last, decoration: const InputDecoration(labelText: 'Soyad')),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _avatar,
                          decoration: const InputDecoration(labelText: 'Avatar URL (opsiyonel)'),
                        ),
                        const SizedBox(height: 16),
                        NeoButton(
                          color: Theme.of(context).colorScheme.secondary,
                          onPressed: _saving ? () {} : _save,
                          width: double.infinity,
                          child: Center(
                            child: _saving
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : const Text(
                                    'Kaydet',
                                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (role == 'EXPERT') ...[
                    const SizedBox(height: 16),
                    NeoBox(
                      color: const Color(0xFFFF9100),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text('Uzman profili', style: Theme.of(context).textTheme.titleLarge),
                          const SizedBox(height: 12),
                          NeoButton(
                            color: Colors.white,
                            onPressed: () => context.push('/expert-self'),
                            width: double.infinity,
                            child: const Center(
                              child: Text(
                                'Uzman profilimi düzenle',
                                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  NeoBox(
                    color: const Color(0xFFFF5252),
                    child: NeoButton(
                      color: Colors.white,
                      onPressed: () async {
                        await ref.read(authControllerProvider.notifier).logout();
                        if (context.mounted) context.go('/auth/login');
                      },
                      width: double.infinity,
                      child: const Center(
                        child: Text(
                          'Çıkış yap',
                          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                        ),
                      ),
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

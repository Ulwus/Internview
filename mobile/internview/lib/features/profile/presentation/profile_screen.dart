import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/models/domain_models.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/network/dio_client.dart';
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

    return Scaffold(
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
                  Text('E-posta: ${p.email}', style: Theme.of(context).textTheme.bodyLarge),
                  Text('Rol: ${p.role}'),
                  const SizedBox(height: 16),
                  TextField(controller: _first, decoration: const InputDecoration(labelText: 'Ad')),
                  TextField(controller: _last, decoration: const InputDecoration(labelText: 'Soyad')),
                  TextField(
                    controller: _avatar,
                    decoration: const InputDecoration(labelText: 'Avatar URL (opsiyonel)'),
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: _saving ? null : _save,
                    child: _saving ? const CircularProgressIndicator() : const Text('Kaydet'),
                  ),
                  if (role == 'EXPERT') ...[
                    const SizedBox(height: 24),
                    OutlinedButton.icon(
                      onPressed: () => context.push('/expert-self'),
                      icon: const Icon(Icons.work_outline),
                      label: const Text('Uzman profilimi düzenle'),
                    ),
                  ],
                  const SizedBox(height: 32),
                  FilledButton.tonal(
                    onPressed: () async {
                      await ref.read(authControllerProvider.notifier).logout();
                      if (context.mounted) context.go('/auth/login');
                    },
                    child: const Text('Çıkış yap'),
                  ),
                ],
              );
            },
          ),
    );
  }
}

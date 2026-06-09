import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/models/domain_models.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/presentation/widgets/neo/neo_background.dart';
import '../../../core/presentation/widgets/penkrowd/animated_action_button.dart';
import '../../../core/presentation/widgets/penkrowd/skeleton_container.dart';
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
  bool _saving = false;
  bool _uploadingAvatar = false;
  final _picker = ImagePicker();

  @override
  void dispose() {
    _first.dispose();
    _last.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await ref.read(profileRemoteProvider).updateProfile(
            firstName: _first.text.trim(),
            lastName: _last.text.trim(),
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

  Future<void> _pickAndUploadAvatar() async {
    if (_uploadingAvatar || _saving) return;
    setState(() => _uploadingAvatar = true);
    try {
      final picked = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
        maxWidth: 1024,
      );
      if (picked == null) return;

      final url = await ref.read(profileRemoteProvider).uploadAvatar(filePath: picked.path);
      await ref.read(profileRemoteProvider).updateProfile(
            firstName: _first.text.trim(),
            lastName: _last.text.trim(),
            avatarUrl: url,
          );
      ref.invalidate(userProfileProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profil fotoğrafı güncellendi')));
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Yükleme hatası: $e')));
    } finally {
      if (mounted) setState(() => _uploadingAvatar = false);
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
            loading: () => const Center(child: SkeletonContainer(width: 220, height: 14, borderRadius: 8)),
            error: (e, _) => Center(child: Text('$e')),
            data: (p) {
              if (_first.text.isEmpty && _last.text.isEmpty) {
                _first.text = p.firstName;
                _last.text = p.lastName;
              }
              return ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.black, width: 3),
                      boxShadow: const [BoxShadow(color: Colors.black, blurRadius: 0, offset: Offset(4, 4))],
                    ),
                    child: Row(
                      children: [
                        GestureDetector(
                          onTap: _uploadingAvatar ? null : _pickAndUploadAvatar,
                          child: Stack(
                            children: [
                              CircleAvatar(
                                radius: 28,
                                backgroundImage: (p.avatarUrl != null && p.avatarUrl!.isNotEmpty)
                                    ? NetworkImage(p.avatarUrl!)
                                    : null,
                                child: (p.avatarUrl == null || p.avatarUrl!.isEmpty)
                                    ? Text(
                                        (p.firstName.isNotEmpty ? p.firstName[0] : '?').toUpperCase(),
                                        style: const TextStyle(fontWeight: FontWeight.w900),
                                      )
                                    : null,
                              ),
                              Positioned.fill(
                                child: AnimatedOpacity(
                                  opacity: _uploadingAvatar ? 1 : 0,
                                  duration: const Duration(milliseconds: 150),
                                  child: Container(
                                    decoration: const BoxDecoration(
                                      color: Color(0x88000000),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Center(
                                      child: SkeletonContainer(width: 20, height: 10, borderRadius: 6),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('${p.firstName} ${p.lastName}', style: Theme.of(context).textTheme.titleLarge),
                              const SizedBox(height: 2),
                              Text(p.email, style: Theme.of(context).textTheme.bodyMedium),
                              const SizedBox(height: 8),
                              AnimatedActionButton(
                                onTap: _uploadingAvatar ? null : _pickAndUploadAvatar,
                                width: 160,
                                height: 40,
                                color: Colors.white,
                                pressedColor: Colors.white,
                                borderColor: Colors.black,
                                borderWidth: 2,
                                borderRadius: 12,
                                shadowOffset: const Offset(3, 3),
                                child: Center(
                                  child: Text(
                                    _uploadingAvatar ? 'Yükleniyor…' : 'Fotoğrafı değiştir',
                                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12, color: Colors.black),
                                  ),
                                ),
                              ),
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
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.black, width: 3),
                      boxShadow: const [BoxShadow(color: Colors.black, blurRadius: 0, offset: Offset(4, 4))],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text('Kişisel bilgiler', style: Theme.of(context).textTheme.titleLarge),
                        const SizedBox(height: 12),
                        TextField(controller: _first, decoration: const InputDecoration(labelText: 'Ad')),
                        const SizedBox(height: 12),
                        TextField(controller: _last, decoration: const InputDecoration(labelText: 'Soyad')),
                        const SizedBox(height: 16),
                        AnimatedActionButton(
                          onTap: _saving ? null : _save,
                          width: double.infinity,
                          height: 48,
                          color: Theme.of(context).colorScheme.secondary,
                          pressedColor: Theme.of(context).colorScheme.secondary,
                          borderColor: Colors.black,
                          borderWidth: 3,
                          borderRadius: 14,
                          shadowOffset: const Offset(4, 4),
                          child: Center(
                            child: _saving
                                ? const SkeletonContainer(width: 120, height: 14, borderRadius: 8)
                                : const Text(
                                    'Kaydet',
                                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Colors.black),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (role == 'EXPERT') ...[
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF9100),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.black, width: 3),
                        boxShadow: const [BoxShadow(color: Colors.black, blurRadius: 0, offset: Offset(4, 4))],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text('Uzman profili', style: Theme.of(context).textTheme.titleLarge),
                          const SizedBox(height: 12),
                          AnimatedActionButton(
                            onTap: () => context.push('/expert-self'),
                            width: double.infinity,
                            height: 48,
                            color: Colors.white,
                            pressedColor: Colors.white,
                            borderColor: Colors.black,
                            borderWidth: 3,
                            borderRadius: 14,
                            shadowOffset: const Offset(4, 4),
                            child: const Center(
                              child: Text(
                                'Uzman profilimi düzenle',
                                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Colors.black),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF5252),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.black, width: 3),
                      boxShadow: const [BoxShadow(color: Colors.black, blurRadius: 0, offset: Offset(4, 4))],
                    ),
                    child: AnimatedActionButton(
                      onTap: () async {
                        await ref.read(authControllerProvider.notifier).logout();
                        if (context.mounted) context.go('/auth/login');
                      },
                      width: double.infinity,
                      height: 48,
                      color: Colors.white,
                      pressedColor: Colors.white,
                      borderColor: Colors.black,
                      borderWidth: 3,
                      borderRadius: 14,
                      shadowOffset: const Offset(4, 4),
                      child: const Center(
                        child: Text(
                          'Çıkış yap',
                          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Colors.black),
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

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/presentation/widgets/neo/neo_background.dart';
import '../../../core/presentation/widgets/penkrowd/animated_action_button.dart';
import '../../../core/presentation/widgets/penkrowd/skeleton_container.dart';
import '../../../core/network/api_exception.dart';
import '../controllers/auth_controller.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _first = TextEditingController();
  final _last = TextEditingController();
  String _role = 'CANDIDATE';
  bool _loading = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _first.dispose();
    _last.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _loading = true);
    try {
      await ref.read(authControllerProvider.notifier).register(
            email: _email.text.trim(),
            password: _password.text,
            firstName: _first.text.trim(),
            lastName: _last.text.trim(),
            role: _role,
          );
      if (!mounted) return;
      context.go('/home');
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return NeoBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(title: const Text('Kayıt')),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Expanded(
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.black, width: 3),
                      boxShadow: const [
                        BoxShadow(color: Colors.black, blurRadius: 0, offset: Offset(4, 4)),
                      ],
                    ),
                    child: ListView(
                      padding: EdgeInsets.zero,
                      children: [
                        TextField(
                          controller: _email,
                          decoration: const InputDecoration(labelText: 'E-posta'),
                          keyboardType: TextInputType.emailAddress,
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _password,
                          decoration: const InputDecoration(labelText: 'Şifre (min 8)'),
                          obscureText: true,
                        ),
                        const SizedBox(height: 12),
                        TextField(controller: _first, decoration: const InputDecoration(labelText: 'Ad')),
                        const SizedBox(height: 12),
                        TextField(controller: _last, decoration: const InputDecoration(labelText: 'Soyad')),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<String>(
                          // ignore: deprecated_member_use
                          value: _role,
                          decoration: const InputDecoration(labelText: 'Rol'),
                          items: const [
                            DropdownMenuItem(value: 'CANDIDATE', child: Text('Aday')),
                            DropdownMenuItem(value: 'EXPERT', child: Text('Uzman')),
                          ],
                          onChanged: (v) => setState(() => _role = v ?? 'CANDIDATE'),
                        ),
                        const SizedBox(height: 24),
                        AnimatedActionButton(
                          onTap: _loading ? null : _submit,
                          width: double.infinity,
                          height: 48,
                          color: const Color(0xFFFF9100),
                          pressedColor: const Color(0xFFFF9100),
                          borderColor: Colors.black,
                          borderWidth: 3,
                          borderRadius: 14,
                          shadowOffset: const Offset(4, 4),
                          child: Center(
                            child: _loading
                                ? const SkeletonContainer(width: 120, height: 14, borderRadius: 8)
                                : const Text(
                                    'Kayıt ol',
                                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Colors.black),
                                  ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        AnimatedActionButton(
                          onTap: () => context.go('/auth/login'),
                          width: double.infinity,
                          height: 46,
                          color: Colors.white,
                          pressedColor: Colors.white,
                          borderColor: Colors.black,
                          borderWidth: 3,
                          borderRadius: 14,
                          shadowOffset: const Offset(4, 4),
                          child: const Center(
                            child: Text(
                              'Zaten hesabım var',
                              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: Colors.black),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

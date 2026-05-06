import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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
    return Scaffold(
      appBar: AppBar(title: const Text('Kayıt')),
      body: ListView(
        padding: const EdgeInsets.all(24),
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
          FilledButton(
            onPressed: _loading ? null : _submit,
            child: _loading ? const CircularProgressIndicator() : const Text('Kayıt ol'),
          ),
          TextButton(
            onPressed: () => context.go('/auth/login'),
            child: const Text('Zaten hesabım var'),
          ),
        ],
      ),
    );
  }
}

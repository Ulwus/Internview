import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/presentation/widgets/neo/neo_background.dart';
import '../../../core/presentation/widgets/neo/neo_box.dart';
import '../../../core/presentation/widgets/neo/neo_button.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return NeoBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 40.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Spacer(),
                NeoBox(
                  color: const Color(0xFFFFD600), // Yellow
                  child: Column(
                    children: [
                      const Icon(Icons.people_alt, size: 80, color: Colors.black),
                      const SizedBox(height: 16),
                      const Text(
                        'Internview',
                        style: TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.w900,
                          color: Colors.black,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Mülakatlarını planla, yönet ve\nyapay zeka ile analiz et!',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                NeoButton(
                  color: const Color(0xFF00E5FF), // Cyan
                  onPressed: () {
                    context.push('/auth/login');
                  },
                  child: const Center(
                    child: Text(
                      'Giriş Yap',
                      style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                NeoButton(
                  color: const Color(0xFFFF9100), // Orange
                  onPressed: () {
                    context.push('/auth/register');
                  },
                  child: const Center(
                    child: Text(
                      'Kayıt Ol',
                      style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

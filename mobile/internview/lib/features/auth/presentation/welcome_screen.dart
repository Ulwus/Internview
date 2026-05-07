import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/presentation/widgets/neo/neo_background.dart';
import '../../../core/presentation/widgets/penkrowd/animated_action_button.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFD600),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.black, width: 3),
                    boxShadow: const [BoxShadow(color: Colors.black, blurRadius: 0, offset: Offset(4, 4))],
                  ),
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
                AnimatedActionButton(
                  onTap: () => context.push('/auth/login'),
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
                      'Giriş Yap',
                      style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: Colors.black),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                AnimatedActionButton(
                  onTap: () => context.push('/auth/register'),
                  width: double.infinity,
                  height: 48,
                  color: const Color(0xFFFF9100),
                  pressedColor: const Color(0xFFFF9100),
                  borderColor: Colors.black,
                  borderWidth: 3,
                  borderRadius: 14,
                  shadowOffset: const Offset(4, 4),
                  child: Text(
                    'Kayıt Ol',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                      color: Colors.black,
                    ),
                    textAlign: TextAlign.center,
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

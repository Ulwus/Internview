import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/presentation/widgets/neo/neo_background.dart';
import '../../../core/presentation/widgets/penkrowd/skeleton_container.dart';
import '../controllers/auth_controller.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _boot());
  }

  Future<void> _boot() async {
    await ref.read(authControllerProvider.notifier).restore();
    if (!mounted) return;
    final auth = ref.read(authControllerProvider);
    if (auth == null) {
      context.go('/auth/login');
      return;
    }
    final role = auth.role.toUpperCase();
    if (role == 'EXPERT') {
      context.go('/home');
    } else {
      context.go('/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    return NeoBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.black, width: 3),
                boxShadow: const [BoxShadow(color: Colors.black, blurRadius: 0, offset: Offset(4, 4))],
              ),
              child: const Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SkeletonContainer(width: 160, height: 18, borderRadius: 10),
                  SizedBox(height: 12),
                  SkeletonContainer(width: 220, height: 14, borderRadius: 10),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

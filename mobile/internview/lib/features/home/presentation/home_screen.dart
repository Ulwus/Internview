import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/controllers/auth_controller.dart';
import '../../booking/presentation/bookings_screen.dart';
import '../../profile/presentation/profile_screen.dart';
import 'dashboard_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    final isExpert = auth?.role.toUpperCase() == 'EXPERT';

    final pages = <Widget>[
      const DashboardScreen(),
      BookingsScreen(asExpert: isExpert),
      const ProfileScreen(),
    ];

    final dest = const [
      NavigationDestination(icon: Icon(Icons.home), label: 'Ana Sayfa'),
      NavigationDestination(icon: Icon(Icons.calendar_month), label: 'Randevular'),
      NavigationDestination(icon: Icon(Icons.person), label: 'Profil'),
    ];

    if (_index >= pages.length) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _index = 0);
      });
    }

    return Scaffold(
      body: IndexedStack(
        index: _index.clamp(0, pages.length - 1),
        children: pages,
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: Colors.black, width: 3)),
        ),
        child: NavigationBar(
          selectedIndex: _index.clamp(0, pages.length - 1),
          onDestinationSelected: (i) => setState(() => _index = i),
          destinations: dest,
        ),
      ),
    );
  }
}


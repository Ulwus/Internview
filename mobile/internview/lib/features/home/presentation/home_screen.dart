import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/controllers/auth_controller.dart';
import '../../booking/presentation/bookings_screen.dart';
import '../../expert/presentation/expert_list_screen.dart';
import '../../expert/presentation/expert_availability_screen.dart';
import '../../profile/presentation/profile_screen.dart';

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

    final pages = isExpert
        ? <Widget>[
            const ExpertAvailabilityScreen(),
            const BookingsScreen(asExpert: true),
            const ProfileScreen(),
          ]
        : <Widget>[
            const ExpertListScreen(),
            const BookingsScreen(asExpert: false),
            const ProfileScreen(),
          ];

    final dest = isExpert
        ? const [
            NavigationDestination(icon: Icon(Icons.event_available), label: 'Müsaitlik'),
            NavigationDestination(icon: Icon(Icons.calendar_month), label: 'Randevular'),
            NavigationDestination(icon: Icon(Icons.person), label: 'Profil'),
          ]
        : const [
            NavigationDestination(icon: Icon(Icons.search), label: 'Uzmanlar'),
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
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index.clamp(0, pages.length - 1),
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: dest,
      ),
    );
  }
}

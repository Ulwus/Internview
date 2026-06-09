import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/presentation/widgets/penkrowd/custom_bottom_nav_bar.dart';
import '../../auth/controllers/auth_controller.dart';
import '../../booking/presentation/bookings_screen.dart';
import '../../marketplace/presentation/marketplace_screen.dart';
import '../../profile/presentation/profile_screen.dart';
import 'dashboard_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _index = 0;
  late final PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _index);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    final isExpert = auth?.role.toUpperCase() == 'EXPERT';

    final pages = <Widget>[
      const DashboardScreen(),
      BookingsScreen(asExpert: isExpert),
      const MarketplaceScreen(),
      const ProfileScreen(),
    ];

    if (_index >= pages.length) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _index = 0);
      });
    }

    return Scaffold(
      extendBody: true,
      body: PageView(
        controller: _pageController,
        onPageChanged: (i) => setState(() => _index = i),
        children: pages,
      ),
      bottomNavigationBar: CustomBottomNavBar(
        selectedIndex: _index.clamp(0, pages.length - 1),
        onItemSelected: (i) {
          _pageController.animateToPage(
            i,
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeInOut,
          );
          setState(() => _index = i);
        },
      ),
    );
  }
}


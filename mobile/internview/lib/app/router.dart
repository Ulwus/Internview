import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/controllers/auth_controller.dart';
import '../features/auth/presentation/login_screen.dart';
import '../features/auth/presentation/register_screen.dart';
import '../features/auth/presentation/splash_screen.dart';
import '../features/auth/presentation/welcome_screen.dart';
import '../features/booking/presentation/booking_detail_screen.dart';
import '../features/booking/presentation/booking_create_screen.dart';
import '../features/booking/presentation/bookings_screen.dart';
import '../features/expert/presentation/expert_detail_screen.dart';
import '../features/expert/presentation/expert_availability_screen.dart';
import '../features/expert/presentation/expert_self_screen.dart';
import '../features/home/presentation/home_screen.dart';
import '../features/interview/presentation/interview_room_screen.dart';
import '../features/interview/presentation/interview_result_screen.dart';
import '../features/marketplace/presentation/shop_detail_screen.dart';
import '../features/marketplace/presentation/shop_me_screen.dart';
import '../features/marketplace/presentation/marketplace_screen.dart';
import 'session_listenable.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');

final goRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/splash',
    refreshListenable: sessionListenable,
    redirect: (context, state) {
      final container = ProviderScope.containerOf(context);
      final auth = container.read(authControllerProvider);
      final loc = state.matchedLocation;
      if (loc == '/splash') return null;
      final authRoute = loc.startsWith('/auth');
      if (auth == null && !authRoute) {
        return '/auth/welcome';
      }
      if (auth != null && authRoute) {
        return '/home';
      }
      return null;
    },
    routes: [
      GoRoute(path: '/splash', builder: (context, state) => const SplashScreen()),
      GoRoute(path: '/auth/welcome', builder: (context, state) => const WelcomeScreen()),
      GoRoute(path: '/auth/login', builder: (context, state) => const LoginScreen()),
      GoRoute(path: '/auth/register', builder: (context, state) => const RegisterScreen()),
      GoRoute(path: '/home', builder: (context, state) => const HomeScreen()),
      GoRoute(path: '/marketplace', builder: (context, state) => const MarketplaceScreen()),
      GoRoute(
        path: '/shop/:id',
        builder: (context, state) => ShopDetailScreen(shopId: state.pathParameters['id']!),
      ),
      GoRoute(path: '/shop-me', builder: (context, state) => const ShopMeScreen()),
      GoRoute(
        path: '/expert/:id',
        builder: (context, state) => ExpertDetailScreen(expertId: state.pathParameters['id']!),
      ),
      GoRoute(path: '/expert-self', builder: (context, state) => const ExpertSelfScreen()),
      GoRoute(path: '/expert-availability', builder: (context, state) => const ExpertAvailabilityScreen()),
      GoRoute(path: '/booking/create', builder: (context, state) => const BookingCreateScreen()),
      GoRoute(
        path: '/bookings',
        builder: (context, state) {
          final asExpert = state.uri.queryParameters['asExpert'] == '1';
          final tab = state.uri.queryParameters['tab'];
          return BookingsScreen(asExpert: asExpert, initialTab: tab);
        },
      ),
      GoRoute(
        path: '/booking/:id',
        builder: (context, state) => BookingDetailScreen(bookingId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/interview/:bookingId',
        builder: (context, state) => InterviewRoomScreen(bookingId: state.pathParameters['bookingId']!),
      ),
      GoRoute(
        path: '/interview/:bookingId/result',
        builder: (context, state) => InterviewResultScreen(bookingId: state.pathParameters['bookingId']!),
      ),
    ],
  );
});

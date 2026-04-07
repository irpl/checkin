import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../features/auth/screens/login_screen.dart';
import '../features/auth/screens/register_screen.dart';
import '../features/home/screens/home_screen.dart';
import '../features/campaigns/screens/campaign_detail_screen.dart';
import '../features/checkin/screens/checkin_screen.dart';
import '../features/invite/screens/invite_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    redirect: (context, state) {
      final session = Supabase.instance.client.auth.currentSession;
      final isLoggedIn = session != null;
      final isAuthRoute = state.matchedLocation == '/login' ||
          state.matchedLocation == '/register';

      // Allow invite routes to redirect to login with token preserved
      final isInviteRoute = state.matchedLocation.startsWith('/invite/');

      if (!isLoggedIn && !isAuthRoute && !isInviteRoute) {
        // If trying to access an invite route while not logged in,
        // redirect to login with a return URL
        if (state.matchedLocation.startsWith('/invite/')) {
          return '/login?redirect=${Uri.encodeComponent(state.matchedLocation)}';
        }
        return '/login';
      }

      if (isLoggedIn && isAuthRoute) {
        // Check for redirect parameter (e.g., after login from invite flow)
        final redirect = state.uri.queryParameters['redirect'];
        if (redirect != null) {
          return Uri.decodeComponent(redirect);
        }
        return '/';
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const HomeScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: '/campaigns/:id',
        builder: (context, state) => CampaignDetailScreen(
          campaignId: state.pathParameters['id']!,
        ),
      ),
      GoRoute(
        path: '/checkin/:campaignId',
        builder: (context, state) => CheckinScreen(
          campaignId: state.pathParameters['campaignId']!,
        ),
      ),
      GoRoute(
        path: '/invite/:token',
        builder: (context, state) => InviteScreen(
          token: state.pathParameters['token']!,
        ),
      ),
    ],
  );
});

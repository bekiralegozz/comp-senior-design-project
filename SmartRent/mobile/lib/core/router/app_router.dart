import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/models.dart';
import '../../screens/auth/login_screen.dart';
import '../../screens/auth/register_screen.dart';
import '../../screens/auth/wallet_connect_screen.dart';
import '../../screens/home_screen.dart';
import '../../screens/asset_details.dart';
import '../../screens/rental_screen.dart';
import '../../screens/profile_screen.dart';
import '../../screens/assets/create_asset_screen.dart';
import '../../screens/assets/my_assets_screen.dart';
import '../../screens/rentals/rental_details_screen.dart';
import '../../screens/rentals/create_rental_screen.dart';
import '../../screens/wallet/wallet_screen.dart';
import '../../screens/settings/settings_screen.dart';
import '../providers/auth_provider.dart';

final goRouterProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);

  return GoRouter(
    initialLocation: '/',
    debugLogDiagnostics: true,
    redirect: (context, state) {
      final isLoggedIn = authState.isAuthenticated;
      final isAuthRoute = state.matchedLocation.startsWith('/auth');

      // Redirect to login if not authenticated and not on auth route
      if (!isLoggedIn && !isAuthRoute) {
        return '/auth/login';
      }

      // Redirect to home if authenticated and on auth route
      if (isLoggedIn && isAuthRoute) {
        return '/';
      }

      return null;
    },
    routes: [
      // Auth Routes
      GoRoute(
        path: '/auth',
        redirect: (context, state) => '/auth/login',
      ),
      GoRoute(
        path: '/auth/login',
        name: 'login',
        pageBuilder: (context, state) => MaterialPage(
          key: state.pageKey,
          child: const LoginScreen(),
        ),
      ),
      GoRoute(
        path: '/auth/register',
        name: 'register',
        pageBuilder: (context, state) => MaterialPage(
          key: state.pageKey,
          child: const RegisterScreen(),
        ),
      ),
      GoRoute(
        path: '/auth/wallet',
        name: 'wallet-connect',
        pageBuilder: (context, state) => MaterialPage(
          key: state.pageKey,
          child: const WalletConnectScreen(),
        ),
      ),

      // Main Routes
      GoRoute(
        path: '/',
        name: 'home',
        pageBuilder: (context, state) => MaterialPage(
          key: state.pageKey,
          child: const HomeScreen(),
        ),
      ),

      // Asset Routes
      GoRoute(
        path: '/assets/create',
        name: 'create-asset',
        pageBuilder: (context, state) => MaterialPage(
          key: state.pageKey,
          child: const CreateAssetScreen(),
        ),
      ),
      GoRoute(
        path: '/assets/my-assets',
        name: 'my-assets',
        pageBuilder: (context, state) => MaterialPage(
          key: state.pageKey,
          child: const MyAssetsScreen(),
        ),
      ),
      GoRoute(
        path: '/asset/:id',
        name: 'asset-details',
        pageBuilder: (context, state) {
          final assetId = state.pathParameters['id']!;
          return MaterialPage(
            key: state.pageKey,
            child: AssetDetailsScreen(assetId: assetId),
          );
        },
      ),

      // Rental Routes
      GoRoute(
        path: '/rentals',
        name: 'rentals',
        pageBuilder: (context, state) => MaterialPage(
          key: state.pageKey,
          child: const RentalScreen(),
        ),
      ),
      GoRoute(
        path: '/rentals/create/:assetId',
        name: 'create-rental',
        pageBuilder: (context, state) {
          final assetId = state.pathParameters['assetId']!;
          return MaterialPage(
            key: state.pageKey,
            child: CreateRentalScreen(assetId: assetId),
          );
        },
      ),
      GoRoute(
        path: '/rental/:id',
        name: 'rental-details',
        pageBuilder: (context, state) {
          final rentalId = int.parse(state.pathParameters['id']!);
          return MaterialPage(
            key: state.pageKey,
            child: RentalDetailsScreen(rentalId: rentalId),
          );
        },
      ),

      // Wallet Routes
      GoRoute(
        path: '/wallet',
        name: 'wallet',
        pageBuilder: (context, state) => MaterialPage(
          key: state.pageKey,
          child: const WalletScreen(),
        ),
      ),

      // Profile & Settings
      GoRoute(
        path: '/profile',
        name: 'profile',
        pageBuilder: (context, state) => MaterialPage(
          key: state.pageKey,
          child: const ProfileScreen(),
        ),
      ),
      GoRoute(
        path: '/settings',
        name: 'settings',
        pageBuilder: (context, state) => MaterialPage(
          key: state.pageKey,
          child: const SettingsScreen(),
        ),
      ),
    ],
    errorPageBuilder: (context, state) => MaterialPage(
      key: state.pageKey,
      child: Scaffold(
        appBar: AppBar(title: const Text('Error')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
              const SizedBox(height: 16),
              const Text(
                'Page not found',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                state.error?.toString() ?? 'The requested page could not be found.',
                style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => context.go('/'),
                child: const Text('Go Home'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
});

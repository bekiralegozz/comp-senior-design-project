import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../screens/auth/wallet_connect_screen.dart';
import '../../screens/home_screen.dart';
import '../../screens/asset_details.dart';
import '../../screens/rental_screen.dart';
import '../../screens/profile_screen.dart';
import '../../screens/assets/create_asset_blockchain_screen.dart';
import '../../screens/assets/create_asset_screen.dart';
import '../../screens/assets/my_assets_screen.dart';
import '../../screens/rentals/rental_details_screen.dart';
import '../../screens/rentals/pay_rent_blockchain_screen.dart';
import '../../screens/wallet/wallet_screen.dart';
import '../../screens/wallet/wallet_connection_screen.dart';
import '../../screens/nft/nft_gallery_screen.dart';
import '../../screens/nft/nft_portfolio_screen.dart';
import '../../screens/settings/settings_screen.dart';
import '../providers/auth_provider.dart';

final goRouterProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);

  return GoRouter(
    initialLocation: '/',
    debugLogDiagnostics: true,
    redirect: (context, state) {
      final isLoggedIn = authState.isAuthenticated;
      final isWalletConnectRoute = state.matchedLocation == '/auth/wallet';

      // Redirect to wallet connect if not authenticated and not already there
      if (!isLoggedIn && !isWalletConnectRoute) {
        return '/auth/wallet';
      }

      // Redirect to home if authenticated and on wallet connect route
      if (isLoggedIn && isWalletConnectRoute) {
        return '/';
      }

      return null;
    },
    routes: [
      // Auth Routes (SIWE Wallet-Only)
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
          child: const CreateAssetScreen(), // New: User-signed mint
        ),
      ),
      GoRoute(
        path: '/assets/create-legacy',
        name: 'create-asset-legacy',
        pageBuilder: (context, state) => MaterialPage(
          key: state.pageKey,
          child: const CreateAssetBlockchainScreen(), // Old: Backend-signed
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
        path: '/rentals/pay/:assetId',
        name: 'pay-rent',
        pageBuilder: (context, state) {
          final assetId = state.pathParameters['assetId']!;
          return MaterialPage(
            key: state.pageKey,
            child: PayRentBlockchainScreen(assetId: assetId),
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
      GoRoute(
        path: '/wallet-connection',
        name: 'wallet-connection',
        pageBuilder: (context, state) => MaterialPage(
          key: state.pageKey,
          child: const WalletConnectionScreen(),
        ),
      ),

      // NFT Routes
      GoRoute(
        path: '/nft-gallery',
        name: 'nft-gallery',
        pageBuilder: (context, state) => MaterialPage(
          key: state.pageKey,
          child: const NftGalleryScreen(),
        ),
      ),
      GoRoute(
        path: '/nft-portfolio',
        name: 'nft-portfolio',
        pageBuilder: (context, state) {
          final walletAddress = state.uri.queryParameters['wallet'];
          return MaterialPage(
            key: state.pageKey,
            child: NftPortfolioScreen(walletAddress: walletAddress),
          );
        },
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

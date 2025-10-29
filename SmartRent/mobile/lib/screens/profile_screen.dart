import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../constants/config.dart';
import '../services/models.dart';
import '../services/api_service.dart';

/// Provider for current user profile
final currentUserProvider = StateNotifierProvider<CurrentUserNotifier, AsyncValue<User?>>((ref) {
  return CurrentUserNotifier();
});

class CurrentUserNotifier extends StateNotifier<AsyncValue<User?>> {
  CurrentUserNotifier() : super(const AsyncValue.loading()) {
    _loadUser();
  }

  Future<void> _loadUser() async {
    try {
      // TODO: Get current user from authentication/storage
      // For now, we'll simulate a user
      await Future.delayed(const Duration(seconds: 1));
      
      // Simulated user data
      final user = User(
        id: 1,
        email: 'demo@smartrent.com',
        displayName: 'Demo User',
        walletAddress: '0x742d35Cc6565C42cF791F93d2b6e7b0b29c2b0c3',
        createdAt: DateTime.now().subtract(const Duration(days: 30)),
      );
      
      state = AsyncValue.data(user);
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }

  Future<void> refreshUser() async {
    await _loadUser();
  }
}

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final userState = ref.watch(currentUserProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              // TODO: Navigate to settings
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Settings coming soon!')),
              );
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await ref.read(currentUserProvider.notifier).refreshUser();
        },
        child: userState.when(
          data: (user) => user != null 
              ? _buildProfileContent(context, theme, user)
              : _buildSignInPrompt(context, theme),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stack) => Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.error_outline,
                  size: 64,
                  color: AppColors.error,
                ),
                const SizedBox(height: AppSpacing.md),
                Text('Failed to load profile'),
                const SizedBox(height: AppSpacing.sm),
                ElevatedButton(
                  onPressed: () => ref.read(currentUserProvider.notifier).refreshUser(),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProfileContent(BuildContext context, ThemeData theme, User user) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        children: [
          // Profile Header
          _buildProfileHeader(theme, user),
          const SizedBox(height: AppSpacing.lg),

          // Wallet Section
          _buildWalletSection(context, theme, user),
          const SizedBox(height: AppSpacing.lg),

          // Stats Section
          _buildStatsSection(theme, user),
          const SizedBox(height: AppSpacing.lg),

          // Menu Items
          _buildMenuSection(context, theme, user),
        ],
      ),
    );
  }

  Widget _buildProfileHeader(ThemeData theme, User user) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary.withOpacity(0.1),
            AppColors.secondary.withOpacity(0.1),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Column(
        children: [
          CircleAvatar(
            radius: 48,
            backgroundColor: AppColors.primary,
            child: Text(
              (user.fullName ?? user.username)[0].toUpperCase(),
              style: theme.textTheme.headlineMedium?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            user.fullName ?? user.username,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            '@${user.username}',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AppColors.grey,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (user.isVerified)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: AppSpacing.xs,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.success.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.verified,
                        size: 16,
                        color: AppColors.success,
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Text(
                        'Verified',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.success,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWalletSection(BuildContext context, ThemeData theme, User user) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(AppRadius.md),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.account_balance_wallet,
                color: AppColors.primary,
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                'Wallet',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: AppSpacing.xs,
                ),
                decoration: BoxDecoration(
                  color: user.walletAddress != null
                      ? AppColors.success.withOpacity(0.1)
                      : AppColors.warning.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Text(
                  user.walletAddress != null ? 'Connected' : 'Not Connected',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: user.walletAddress != null
                        ? AppColors.success
                        : AppColors.warning,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          if (user.walletAddress != null) ...[
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Address',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.grey,
                        ),
                      ),
                      Text(
                        '${user.walletAddress!.substring(0, 6)}...${user.walletAddress!.substring(user.walletAddress!.length - 4)}',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontFamily: 'monospace',
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () {
                    // TODO: Copy to clipboard
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Address copied to clipboard')),
                    );
                  },
                  icon: const Icon(Icons.copy, size: 20),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      // TODO: Show wallet balance and transactions
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Wallet details coming soon!')),
                      );
                    },
                    icon: const Icon(Icons.visibility),
                    label: const Text('View Details'),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                ElevatedButton.icon(
                  onPressed: () {
                    // TODO: Disconnect wallet
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Disconnect wallet coming soon!')),
                    );
                  },
                  icon: const Icon(Icons.logout),
                  label: const Text('Disconnect'),
                ),
              ],
            ),
          ] else ...[
            Text(
              'Connect your wallet to start renting and earning',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppColors.grey,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  // TODO: Connect wallet
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Wallet connection coming soon!')),
                  );
                },
                icon: const Icon(Icons.account_balance_wallet),
                label: const Text('Connect Wallet'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatsSection(ThemeData theme, User user) {
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(theme, '12', 'Assets Listed', Icons.inventory_2_outlined),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: _buildStatCard(theme, '8', 'Rentals', Icons.handshake_outlined),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: _buildStatCard(theme, '4.8', 'Rating', Icons.star_outlined),
        ),
      ],
    );
  }

  Widget _buildStatCard(ThemeData theme, String value, String label, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(AppRadius.md),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, color: AppColors.primary, size: 24),
          const SizedBox(height: AppSpacing.xs),
          Text(
            value,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: AppColors.primary,
            ),
          ),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppColors.grey,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildMenuSection(BuildContext context, ThemeData theme, User user) {
    return Column(
      children: [
        _buildMenuItem(
          context,
          theme,
          'My Assets',
          Icons.inventory_2_outlined,
          () {
            // TODO: Navigate to user's assets
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('My assets coming soon!')),
            );
          },
        ),
        _buildMenuItem(
          context,
          theme,
          'Transaction History',
          Icons.receipt_long_outlined,
          () {
            // TODO: Navigate to transaction history
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Transaction history coming soon!')),
            );
          },
        ),
        _buildMenuItem(
          context,
          theme,
          'Favorites',
          Icons.favorite_outlined,
          () {
            // TODO: Navigate to favorites
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Favorites coming soon!')),
            );
          },
        ),
        _buildMenuItem(
          context,
          theme,
          'Notifications',
          Icons.notifications_outlined,
          () {
            // TODO: Navigate to notifications settings
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Notifications settings coming soon!')),
            );
          },
        ),
        _buildMenuItem(
          context,
          theme,
          'Privacy & Security',
          Icons.security_outlined,
          () {
            // TODO: Navigate to privacy settings
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Privacy settings coming soon!')),
            );
          },
        ),
        _buildMenuItem(
          context,
          theme,
          'Help & Support',
          Icons.help_outline,
          () {
            // TODO: Navigate to help
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Help & support coming soon!')),
            );
          },
        ),
        _buildMenuItem(
          context,
          theme,
          'About',
          Icons.info_outline,
          () {
            _showAboutDialog(context);
          },
        ),
        _buildMenuItem(
          context,
          theme,
          'Sign Out',
          Icons.logout,
          () {
            _showSignOutDialog(context);
          },
          isDestructive: true,
        ),
      ],
    );
  }

  Widget _buildMenuItem(
    BuildContext context,
    ThemeData theme,
    String title,
    IconData icon,
    VoidCallback onTap, {
    bool isDestructive = false,
  }) {
    return ListTile(
      leading: Icon(
        icon,
        color: isDestructive ? AppColors.error : AppColors.primary,
      ),
      title: Text(
        title,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: isDestructive ? AppColors.error : null,
        ),
      ),
      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
      onTap: onTap,
    );
  }

  Widget _buildSignInPrompt(BuildContext context, ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.person_outline,
              size: 80,
              color: AppColors.grey,
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'Welcome to SmartRent',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Sign in to access your profile, rentals, and more',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppColors.grey,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.lg),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  // TODO: Navigate to sign in
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Sign in coming soon!')),
                  );
                },
                child: const Text('Sign In'),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            TextButton(
              onPressed: () {
                // TODO: Navigate to sign up
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Sign up coming soon!')),
                );
              },
              child: const Text('Create Account'),
            ),
          ],
        ),
      ),
    );
  }

  void _showAboutDialog(BuildContext context) {
    showAboutDialog(
      context: context,
      applicationName: AppConfig.appName,
      applicationVersion: AppConfig.appVersion,
      applicationLegalese: '© 2023 SmartRent. All rights reserved.',
      children: [
        const SizedBox(height: AppSpacing.md),
        const Text(
          'SmartRent is a blockchain-enabled rental and asset-sharing platform '
          'that allows you to rent anything, anywhere, anytime with complete security.',
        ),
      ],
    );
  }

  void _showSignOutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              // TODO: Implement sign out
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Signed out successfully')),
              );
            },
            child: Text(
              'Sign Out',
              style: TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
  }
}









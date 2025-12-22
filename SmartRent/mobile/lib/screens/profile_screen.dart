import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../constants/config.dart';
import '../core/providers/auth_provider.dart';
import '../core/providers/wallet_provider.dart';

/// ==========================================================
/// PROFILE SCREEN - BLOCKCHAIN MIGRATION VERSION
/// ==========================================================
///
/// User profile is now wallet-based.
/// No database profile - only blockchain wallet address.

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final authState = ref.watch(authStateProvider);
    final walletState = ref.watch(walletProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => context.go('/settings'),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.read(walletProvider.notifier).refreshBalance();
        },
        child: authState.isAuthenticated
            ? _buildProfileContent(context, theme, ref, authState, walletState)
            : _buildConnectWalletPrompt(context, theme),
      ),
    );
  }

  Widget _buildProfileContent(
    BuildContext context,
    ThemeData theme,
    WidgetRef ref,
    AuthState authState,
    WalletState walletState,
  ) {
    final walletAddress = authState.walletAddress ?? walletState.address ?? '';
    final shortAddress = walletAddress.isNotEmpty
        ? '${walletAddress.substring(0, 6)}...${walletAddress.substring(walletAddress.length - 4)}'
        : 'Unknown';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        children: [
          // Profile Header
          _buildProfileHeader(theme, walletAddress, shortAddress),
          const SizedBox(height: AppSpacing.lg),

          // Wallet Section
          _buildWalletSection(context, theme, walletAddress, walletState),
          const SizedBox(height: AppSpacing.lg),

          // Stats Section
          _buildStatsSection(theme),
          const SizedBox(height: AppSpacing.lg),

          // Menu Items
          _buildMenuSection(context, theme, ref),
        ],
      ),
    );
  }

  Widget _buildProfileHeader(ThemeData theme, String walletAddress, String shortAddress) {
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
            child: Icon(
              Icons.account_balance_wallet,
              size: 48,
                color: Colors.white,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            shortAddress,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              fontFamily: 'monospace',
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
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
                Icon(Icons.check_circle, size: 16, color: AppColors.success),
                      const SizedBox(width: AppSpacing.xs),
                      Text(
                  'Wallet Connected',
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
    );
  }

  Widget _buildWalletSection(
    BuildContext context,
    ThemeData theme,
    String walletAddress,
    WalletState walletState,
  ) {
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
              Icon(Icons.account_balance_wallet, color: AppColors.primary),
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
                  color: AppColors.secondary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Text(
                  'Polygon',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.secondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
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
                      walletAddress.isNotEmpty
                          ? '${walletAddress.substring(0, 10)}...${walletAddress.substring(walletAddress.length - 8)}'
                          : 'Not connected',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontFamily: 'monospace',
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () {
                  if (walletAddress.isNotEmpty) {
                    Clipboard.setData(ClipboardData(text: walletAddress));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Address copied to clipboard')),
                    );
                  }
                  },
                  icon: const Icon(Icons.copy, size: 20),
                ),
              ],
            ),
          const Divider(height: AppSpacing.lg),
            Row(
              children: [
                Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Balance',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.grey,
                  ),
                ),
                    Text(
                      walletState.balance != null
                          ? '${walletState.balance} MATIC'
                          : 'Loading...',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                ),
              ],
            ),
              ),
              TextButton.icon(
                onPressed: () {
                  // Open PolygonScan
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('View on PolygonScan coming soon!')),
                  );
                },
                icon: const Icon(Icons.open_in_new, size: 16),
                label: const Text('View'),
              ),
            ],
            ),
        ],
      ),
    );
  }

  Widget _buildStatsSection(ThemeData theme) {
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(theme, '0', 'NFT Assets', Icons.token),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: _buildStatCard(theme, '0', 'Rentals', Icons.handshake_outlined),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: _buildStatCard(theme, '-', 'Rating', Icons.star_outlined),
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

  Widget _buildMenuSection(BuildContext context, ThemeData theme, WidgetRef ref) {
    return Column(
      children: [
        _buildMenuItem(
          context,
          theme,
          'My NFT Portfolio',
          Icons.collections_outlined,
          () {
            final walletAddress = ref.read(authStateProvider).walletAddress ?? '';
            context.go('/nft-portfolio?wallet=$walletAddress');
          },
        ),
        _buildMenuItem(
          context,
          theme,
          'Transaction History',
          Icons.receipt_long_outlined,
          () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Transaction history coming soon!')),
            );
          },
        ),
        _buildMenuItem(
          context,
          theme,
          'Help & Support',
          Icons.help_outline,
          () {
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
          () => _showAboutDialog(context),
        ),
        _buildMenuItem(
          context,
          theme,
          'Disconnect Wallet',
          Icons.logout,
          () => _showDisconnectDialog(context, ref),
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

  Widget _buildConnectWalletPrompt(BuildContext context, ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.account_balance_wallet_outlined,
              size: 80,
              color: AppColors.grey,
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'Connect Your Wallet',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Connect your wallet to access your profile,\nNFT assets, and rentals on the blockchain',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppColors.grey,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.lg),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => context.go('/auth/wallet'),
                icon: const Icon(Icons.account_balance_wallet),
                label: const Text('Connect Wallet'),
              ),
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
      applicationLegalese: '© 2024 SmartRent. All rights reserved.',
      children: [
        const SizedBox(height: AppSpacing.md),
        const Text(
          'SmartRent is a blockchain-based rental and asset-sharing platform '
          'running on Polygon. Rent anything, anywhere, anytime with complete security.',
        ),
      ],
    );
  }

  void _showDisconnectDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Disconnect Wallet'),
        content: const Text('Are you sure you want to disconnect your wallet?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop();
              await ref.read(authStateProvider.notifier).logout();
              if (context.mounted) {
                context.go('/auth/wallet');
              }
            },
            child: Text(
              'Disconnect',
              style: TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
  }
}

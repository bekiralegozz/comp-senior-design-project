import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/providers/auth_provider.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        children: [
          // Account Section
          _buildSectionHeader(context, 'Wallet Identity'),
          ListTile(
            leading: const Icon(Icons.account_balance_wallet_outlined),
            title: const Text('Connected Wallet'),
            subtitle: Text(
              authState.walletAddress != null
                  ? '${authState.walletAddress!.substring(0, 6)}...${authState.walletAddress!.substring(authState.walletAddress!.length - 4)}'
                  : 'Not connected',
            ),
            trailing: const Icon(Icons.copy_outlined),
            onTap: () {
              if (authState.walletAddress != null) {
                // Copy wallet address to clipboard
                // Clipboard.setData(ClipboardData(text: authState.walletAddress!));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Wallet address copied')),
                );
              }
            },
          ),
          const Divider(),

          // App Settings
          _buildSectionHeader(context, 'App Settings'),
          SwitchListTile(
            secondary: const Icon(Icons.notifications_outlined),
            title: const Text('Push Notifications'),
            subtitle: const Text('Receive updates about your rentals'),
            value: true,
            onChanged: (value) {
              // Handle notification toggle
            },
          ),
          SwitchListTile(
            secondary: const Icon(Icons.dark_mode_outlined),
            title: const Text('Dark Mode'),
            subtitle: const Text('Enable dark theme'),
            value: false,
            onChanged: (value) {
              // Handle theme toggle
            },
          ),
          const Divider(),

          // Help & Support
          _buildSectionHeader(context, 'Help & Support'),
          ListTile(
            leading: const Icon(Icons.help_outline),
            title: const Text('Help Center'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              // Open help center
            },
          ),
          ListTile(
            leading: const Icon(Icons.privacy_tip_outlined),
            title: const Text('Privacy Policy'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              // Open privacy policy
            },
          ),
          ListTile(
            leading: const Icon(Icons.description_outlined),
            title: const Text('Terms of Service'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              // Open terms of service
            },
          ),
          const Divider(),

          // Disconnect Wallet
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text(
              'Disconnect Wallet',
              style: TextStyle(color: Colors.red),
            ),
            onTap: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Disconnect Wallet'),
                  content: const Text('Are you sure you want to disconnect your wallet?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      child: const Text('Disconnect'),
                    ),
                  ],
                ),
              );

              if (confirm == true) {
                await ref.read(authStateProvider.notifier).logout();
                // Navigate to wallet connect screen after logout
                if (context.mounted) {
                  context.go('/auth/wallet');
                }
              }
            },
          ),
          const SizedBox(height: 24),

          // Version Info
          Center(
            child: Text(
              'Version 1.0.0',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Theme.of(context).primaryColor,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}

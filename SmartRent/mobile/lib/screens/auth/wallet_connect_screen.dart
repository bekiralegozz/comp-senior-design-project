import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../core/providers/auth_provider.dart';

class WalletConnectScreen extends ConsumerStatefulWidget {
  const WalletConnectScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<WalletConnectScreen> createState() => _WalletConnectScreenState();
}

class _WalletConnectScreenState extends ConsumerState<WalletConnectScreen> {
  @override
  void initState() {
    super.initState();
    _checkExistingSession();
  }

  /// Check if there's an existing wallet session
  Future<void> _checkExistingSession() async {
    final authState = ref.read(authStateProvider);
    if (authState.isAuthenticated) {
      // Already authenticated, redirect to home
      if (mounted) {
        context.go('/');
      }
    }
  }

  /// Handle wallet connection and SIWE authentication
  Future<void> _handleWalletConnect() async {
    try {
      final success = await ref.read(authStateProvider.notifier).connectWalletAndAuthenticate();

      if (!mounted) return;

      if (success) {
        // Success - navigate to home
        await Future.delayed(const Duration(milliseconds: 500));
        if (mounted) {
          context.go('/');
        }
      } else {
        // Failed - show error
        final errorMessage = ref.read(authStateProvider).error ?? 
            'Wallet connection failed. Please try again.';
        _showErrorSnackBar(errorMessage);
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error during wallet connect: $e');
      }
      _showErrorSnackBar('An error occurred: ${e.toString()}');
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 5),
        action: SnackBarAction(
          label: 'Dismiss',
          textColor: Colors.white,
          onPressed: () {},
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Logo/Icon
                Icon(
                  Icons.account_balance_wallet_outlined,
                  size: 100,
                  color: Theme.of(context).primaryColor,
                ),
                const SizedBox(height: 32),

                // Title
                Text(
                  'Welcome to SmartRent',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),

                // Subtitle
                Text(
                  'Decentralized Real Estate Platform',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Colors.grey[600],
                      ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 48),

                // Info Card
                Card(
                  elevation: 0,
                  color: Colors.blue[50],
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: Colors.blue[200]!),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Icon(Icons.info_outline, color: Colors.blue[700], size: 32),
                        const SizedBox(height: 12),
                        Text(
                          'Connect Your Wallet',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.blue[900],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'You\'ll need a Web3 wallet to use SmartRent. We use Sign-In With Ethereum (SIWE) for secure, decentralized authentication.',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.blue[800],
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 32),

                // QR Code - Show when wcUri is available (both web and mobile)
                if (authState.wcUri != null && authState.wcUri!.isNotEmpty) ...[
                  Card(
                    elevation: 2,
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          Icon(Icons.qr_code_2, size: 40, color: Theme.of(context).primaryColor),
                          const SizedBox(height: 12),
                          Text(
                            'Scan with your wallet app',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 20),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.grey[300]!),
                            ),
                            child: QrImageView(
                              data: authState.wcUri!,
                              version: QrVersions.auto,
                              size: 220,
                              backgroundColor: Colors.white,
                              eyeStyle: QrEyeStyle(
                                eyeShape: QrEyeShape.square,
                                color: Theme.of(context).primaryColor,
                              ),
                              dataModuleStyle: QrDataModuleStyle(
                                dataModuleShape: QrDataModuleShape.square,
                                color: Colors.black,
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.blue[50],
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              authState.statusMessage ?? 'Waiting for wallet approval...',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Colors.blue[900],
                                fontWeight: FontWeight.w500,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'MetaMask • Trust Wallet • Rainbow',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: Colors.grey[600],
                                ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],

                // Connect Button (hide when QR code is shown)
                if (!authState.isAuthenticated && authState.wcUri == null) ...[
                  ElevatedButton.icon(
                    onPressed: authState.isLoading ? null : _handleWalletConnect,
                    icon: authState.isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Icon(Icons.account_balance_wallet),
                    label: Text(
                      authState.isLoading
                          ? authState.statusMessage ?? 'Connecting...'
                          : 'Connect Wallet',
                    ),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],
                
                // Cancel button when connecting
                if (authState.isLoading && authState.wcUri != null) ...[
                  OutlinedButton.icon(
                    onPressed: () {
                      ref.read(authStateProvider.notifier).logout();
                    },
                    icon: const Icon(Icons.close),
                    label: const Text('Cancel'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],

                // Already Connected
                if (authState.isAuthenticated) ...[
                  Card(
                    color: Colors.green[50],
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          const Icon(Icons.check_circle, color: Colors.green, size: 48),
                          const SizedBox(height: 16),
                          const Text(
                            'Wallet Connected',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            authState.walletAddress ?? '',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  fontFamily: 'monospace',
                                ),
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () => context.go('/'),
                    child: const Text('Continue to App'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ],

                const SizedBox(height: 24),

                // Help Text
                Text(
                  kIsWeb
                      ? 'Scan the QR code with your mobile wallet app or use a browser extension like MetaMask.'
                      : 'Tap "Connect Wallet" to open your wallet app and approve the connection.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey[600],
                      ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),

                // Supported Wallets
                Text(
                  'Supported Wallets',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Colors.grey[500],
                        fontWeight: FontWeight.w600,
                      ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 8,
                  children: [
                    _buildWalletChip('MetaMask'),
                    _buildWalletChip('Trust Wallet'),
                    _buildWalletChip('Rainbow'),
                    _buildWalletChip('WalletConnect'),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWalletChip(String name) {
    return Chip(
      label: Text(
        name,
        style: const TextStyle(fontSize: 12),
      ),
      backgroundColor: Colors.grey[200],
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../core/providers/wallet_provider.dart';

/// Wallet Connect Button
/// Shows wallet connection status and allows connection/disconnection
class WalletConnectButton extends ConsumerWidget {
  const WalletConnectButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final walletState = ref.watch(walletProvider);
    final walletNotifier = ref.read(walletProvider.notifier);

    if (walletState.isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (walletState.isConnected && walletState.address != null) {
      return _buildConnectedWallet(context, walletState, walletNotifier);
    }

    return _buildConnectButton(context, walletState, walletNotifier);
  }

  Widget _buildConnectedWallet(
    BuildContext context,
    WalletState state,
    WalletNotifier notifier,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.green[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.green[300]!),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_circle, color: Colors.green[700], size: 20),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _truncateAddress(state.address!),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              if (state.balance != null)
                Text(
                  '${state.balance} ETH',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
            ],
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.logout, size: 20),
            onPressed: () async {
              final confirm = await _showDisconnectDialog(context);
              if (confirm == true) {
                await notifier.disconnect();
              }
            },
            tooltip: 'Disconnect',
          ),
        ],
      ),
    );
  }

  Widget _buildConnectButton(
    BuildContext context,
    WalletState state,
    WalletNotifier notifier,
  ) {
    return ElevatedButton.icon(
      onPressed: () async {
        if (kIsWeb) {
          // WEB: Show QR code dialog first
          await _showWebConnectDialog(context, notifier);
        } else {
          // MOBILE: Show connecting dialog and launch wallet
          await _showMobileConnectDialog(context, notifier);
        }
      },
      icon: const Icon(Icons.account_balance_wallet),
      label: const Text('Connect Wallet'),
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      ),
    );
  }

  /// Web connection flow (QR code) - SIMPLIFIED VERSION
  Future<void> _showWebConnectDialog(
    BuildContext context,
    WalletNotifier notifier,
  ) async {
    try {
      // Start connection
      final connectFuture = notifier.connect();
      
      // Wait for URI to be generated
      await Future.delayed(const Duration(milliseconds: 1000));
      
      // Get the WC URI from state
      String? wcUri = notifier.state.wcUri;
      
      // Retry if needed
      if (wcUri == null) {
        await Future.delayed(const Duration(milliseconds: 500));
        wcUri = notifier.state.wcUri;
      }
      
      if (wcUri != null && wcUri.isNotEmpty) {
        // Show full screen modal instead of dialog
        if (context.mounted) {
          await Navigator.of(context).push(
            MaterialPageRoute(
              fullscreenDialog: true,
              builder: (ctx) => Scaffold(
                appBar: AppBar(
                  title: const Text('Connect Wallet'),
                  leading: IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(ctx).pop(),
                  ),
                ),
                body: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          'Scan this QR code with your mobile wallet',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Trust Wallet, MetaMask, etc.',
                          style: TextStyle(fontSize: 14, color: Colors.grey),
                        ),
                        const SizedBox(height: 32),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 10,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: QrImageView(
                            data: wcUri!,
                            version: QrVersions.auto,
                            size: 250,
                          ),
                        ),
                        const SizedBox(height: 32),
                        const CircularProgressIndicator(),
                        const SizedBox(height: 16),
                        const Text(
                          'Waiting for approval...',
                          style: TextStyle(fontSize: 14, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        }
        
        // Connection completed or cancelled
        final success = await connectFuture;
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(success ? '✅ Wallet connected!' : '❌ Connection cancelled'),
              backgroundColor: success ? Colors.green : Colors.orange,
            ),
          );
        }
      } else {
        throw Exception('Failed to generate QR code');
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Mobile connection flow (deep link)
  Future<void> _showMobileConnectDialog(
    BuildContext context,
    WalletNotifier notifier,
  ) async {
    // Show connecting dialog
    if (context.mounted) {
      _showConnectingDialog(context);
    }

    try {
      final success = await notifier.connect();
      
      if (context.mounted) {
        Navigator.of(context).pop(); // Close connecting dialog
        
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Wallet connected successfully'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('❌ Failed to connect wallet'),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.of(context).pop(); // Close connecting dialog
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  /// Show QR code dialog (Web platform)
  Future<void> _showQRCodeDialog(BuildContext context, String uri) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Connect Your Wallet'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Scan this QR code with your mobile wallet app',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 8),
              const Text(
                '(Trust Wallet, MetaMask, etc.)',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: QrImageView(
                  data: uri,
                  version: QrVersions.auto,
                  size: 250,
                  backgroundColor: Colors.white,
                ),
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.blue.shade700, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Waiting for approval in your wallet app...',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.blue.shade700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  Future<bool?> _showDisconnectDialog(BuildContext context) {
    return showDialog<bool>(
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
  }

  void _showConnectingDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 24),
            const Text(
              'Opening your wallet app...',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Please approve the connection in your wallet',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  Icon(Icons.info_outline, color: Colors.blue[700], size: 20),
                  const SizedBox(height: 8),
                  Text(
                    'If the wallet app doesn\'t open automatically, please make sure you have Trust Wallet or MetaMask installed.',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.blue[700],
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _truncateAddress(String address) {
    if (address.length <= 12) return address;
    return '${address.substring(0, 6)}...${address.substring(address.length - 4)}';
  }
}


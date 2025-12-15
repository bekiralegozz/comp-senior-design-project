import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../providers/wallet_provider.dart';

class WalletConnectionScreen extends StatefulWidget {
  const WalletConnectionScreen({Key? key}) : super(key: key);

  @override
  State<WalletConnectionScreen> createState() => _WalletConnectionScreenState();
}

class _WalletConnectionScreenState extends State<WalletConnectionScreen> {
  final TextEditingController _privateKeyController = TextEditingController();
  bool _isPrivateKeyVisible = false;
  String? _error;

  @override
  void dispose() {
    _privateKeyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final walletProvider = Provider.of<WalletProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Connect Wallet'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Logo or illustration
            Icon(
              Icons.account_balance_wallet,
              size: 80,
              color: Theme.of(context).primaryColor,
            ),
            const SizedBox(height: 24),
            
            // Title
            const Text(
              'Connect Your Wallet',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            
            // Subtitle
            Text(
              'Choose a connection method below',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 40),
            
            // Demo Connection Button
            _buildConnectionCard(
              icon: Icons.science,
              title: 'Demo Wallet',
              subtitle: 'Connect with test wallet for demo',
              color: Colors.purple,
              onTap: walletProvider.isLoading ? null : () => _connectDemo(walletProvider),
            ),
            const SizedBox(height: 16),
            
            // Private Key Connection
            _buildConnectionCard(
              icon: Icons.vpn_key,
              title: 'Private Key',
              subtitle: 'Import wallet with private key',
              color: Colors.orange,
              onTap: walletProvider.isLoading ? null : () => _showPrivateKeyDialog(walletProvider),
            ),
            const SizedBox(height: 16),
            
            // WalletConnect (coming soon)
            _buildConnectionCard(
              icon: Icons.qr_code_scanner,
              title: 'WalletConnect',
              subtitle: 'Coming soon - Scan QR with MetaMask',
              color: Colors.blue,
              onTap: null, // Disabled for now
              isDisabled: true,
            ),
            
            if (_error != null) ...[
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: Colors.red),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _error!,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            
            const SizedBox(height: 40),
            
            // Info section
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.blue.shade700, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Important Information',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.blue.shade700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildInfoItem('• Network: Polygon Mainnet (Chain ID: 137)'),
                  _buildInfoItem('• Your private keys are stored securely on your device'),
                  _buildInfoItem('• Never share your private key with anyone'),
                  _buildInfoItem('• Make sure you have MATIC for gas fees'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConnectionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback? onTap,
    bool isDisabled = false,
  }) {
    return Card(
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: isDisabled ? Colors.grey.shade200 : null,
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDisabled ? Colors.grey.shade400 : color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  color: isDisabled ? Colors.grey.shade600 : color,
                  size: 32,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: isDisabled ? Colors.grey.shade600 : null,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 14,
                        color: isDisabled ? Colors.grey.shade500 : Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                color: isDisabled ? Colors.grey.shade400 : Colors.grey.shade400,
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 13,
          color: Colors.blue.shade900,
        ),
      ),
    );
  }

  Future<void> _connectDemo(WalletProvider walletProvider) async {
    setState(() => _error = null);
    
    final success = await walletProvider.connectDemo();
    
    if (success && mounted) {
      context.go('/');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Demo wallet connected successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      setState(() => _error = 'Failed to connect demo wallet');
    }
  }

  Future<void> _showPrivateKeyDialog(WalletProvider walletProvider) async {
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Import Private Key'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enter your wallet private key:',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _privateKeyController,
              obscureText: !_isPrivateKeyVisible,
              decoration: InputDecoration(
                hintText: '0x...',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: Icon(
                    _isPrivateKeyVisible ? Icons.visibility_off : Icons.visibility,
                  ),
                  onPressed: () {
                    setState(() {
                      _isPrivateKeyVisible = !_isPrivateKeyVisible;
                    });
                  },
                ),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning_amber, color: Colors.red.shade700, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Never share your private key!',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.red.shade900,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => _importPrivateKey(walletProvider),
            child: const Text('Import'),
          ),
        ],
      ),
    );
  }

  Future<void> _importPrivateKey(WalletProvider walletProvider) async {
    final privateKey = _privateKeyController.text.trim();
    
    if (privateKey.isEmpty) {
      setState(() => _error = 'Please enter a private key');
      return;
    }

    Navigator.pop(context); // Close dialog
    setState(() => _error = null);
    
    final success = await walletProvider.connectWithPrivateKey(privateKey);
    
    if (success && mounted) {
      context.go('/');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Wallet connected successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      setState(() => _error = 'Failed to import wallet. Check your private key.');
    }
  }
}

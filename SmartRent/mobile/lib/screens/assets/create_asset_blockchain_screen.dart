import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:web3dart/web3dart.dart';
import 'package:convert/convert.dart';

import '../../constants/config.dart';
import '../../constants/blockchain_config.dart';
import '../../services/models.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/providers/wallet_provider.dart';
import '../../services/blockchain_service.dart';
import '../../services/wallet_service.dart';
import '../../widgets/success_dialog.dart';
import '../../widgets/error_dialog.dart';
import '../../widgets/wallet_connect_button.dart';

/// Provider for asset categories (from API)
final assetCategoriesProviderBlockchain = FutureProvider<List<String>>((ref) async {
  // Return default categories since we're not using API for this
  return [
    'housing',
    'vehicles',
    'electronics',
    'tools',
    'furniture',
    'sports',
    'books',
    'clothing',
    'other'
  ];
});

class CreateAssetBlockchainScreen extends ConsumerStatefulWidget {
  const CreateAssetBlockchainScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<CreateAssetBlockchainScreen> createState() =>
      _CreateAssetBlockchainScreenState();
}

class _CreateAssetBlockchainScreenState
    extends ConsumerState<CreateAssetBlockchainScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _totalSupplyController = TextEditingController();
  final _metadataUriController = TextEditingController();

  String _selectedCategory = 'other';
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    
    // Initialize blockchain service
    _initializeBlockchain();
  }
  
  Future<void> _initializeBlockchain() async {
    try {
      final blockchainService = BlockchainService();
      await blockchainService.initialize();
      print('✅ BlockchainService initialized');
    } catch (e) {
      print('❌ Error initializing blockchain service: $e');
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _totalSupplyController.dispose();
    _metadataUriController.dispose();
    super.dispose();
  }

  Future<void> _createAssetOnBlockchain() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Check wallet connection
    final walletState = ref.read(walletProvider);
    if (!walletState.isConnected || walletState.address == null) {
      _showError('Please connect your wallet first');
      return;
    }

    final authState = ref.read(authStateProvider);
    if (authState.profile == null) {
      _showError('You must be logged in');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Get services
      final walletService = WalletService();
      final blockchainService = BlockchainService();

      // Generate unique token ID (in production, this should be managed more carefully)
      final tokenId = BigInt.from(DateTime.now().millisecondsSinceEpoch);
      final totalSupply = BigInt.from(int.parse(_totalSupplyController.text));
      final initialOwner =
          EthereumAddress.fromHex(walletState.address!);
      final metadataUri = _metadataUriController.text.trim();

      // Show transaction dialog
      if (!mounted) return;
      final result = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: const Text('Creating Asset on Blockchain'),
          content: const Text('Please confirm the transaction in your wallet'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                print('🔘 Confirm button pressed');
                try {
                  print('🔍 Getting blockchain service...');
                  
                  // Call Building1122.mintInitialSupply()
                  final contract = blockchainService.getBuildingContract();
                  print('🔍 Contract: ${contract?.address.hex ?? "NULL"}');
                  
                  if (contract == null) {
                    throw Exception('Contract not initialized');
                  }
                  
                  print('🔍 Encoding function call...');
                  final function = contract.function('mintInitialSupply');
                  final encodedData = function.encodeCall([
                    tokenId,
                    initialOwner,
                    totalSupply,
                    metadataUri,
                  ]);
                  print('✅ Encoded data: 0x${hex.encode(encodedData).substring(0, 20)}...');
                  
                  print('📤 Sending transaction to wallet...');
                  final txHash = await walletService.sendTransaction(
                    to: contract.address.hex,
                    value: EtherAmount.zero(),
                    data: '0x${hex.encode(encodedData)}',
                    gas: BlockchainConfig.defaultGasLimit,
                  );
                  
                  print('✅ Transaction hash: $txHash');
                  
                  final success = txHash != null && txHash.isNotEmpty;
                  if (context.mounted) {
                    Navigator.of(context).pop(success);
                  }
                } catch (e) {
                  print('❌ ERROR in confirm: $e');
                  if (context.mounted) {
                    Navigator.of(context).pop(false);
                  }
                  rethrow; // Re-throw to see in outer catch
                }
              },
              child: const Text('Confirm'),
            ),
          ],
        ),
      );

      if (result == true && mounted) {
        await showSuccessDialog(
          context,
          title: 'Asset Created!',
          message:
              'Asset "${_nameController.text}" has been successfully created on blockchain.',
          transactionHash: 'Token ID: $tokenId',
          onClose: () => context.pop(),
        );
      }
    } catch (e) {
      if (mounted) {
        await showErrorDialog(
          context,
          title: 'Failed to Create Asset',
          message: parseErrorMessage(e),
          details: e.toString(),
          onRetry: _createAssetOnBlockchain,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showError(String message) {
    setState(() {
      _errorMessage = message;
      _isLoading = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.error,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final categoriesAsync = ref.watch(assetCategoriesProviderBlockchain);
    final walletState = ref.watch(walletProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Asset (Blockchain)'),
        elevation: 0,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.md),
          children: [
            // Wallet Connection Warning
            if (!walletState.isConnected)
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                margin: const EdgeInsets.only(bottom: AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.warning.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(color: AppColors.warning),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.warning, color: AppColors.warning),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Text(
                            'Please connect your wallet to create an asset on blockchain',
                            style: theme.textTheme.bodyMedium,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    const WalletConnectButton(),
                  ],
                ),
              ),

            // Header
            Text(
              'Blockchain Asset Creation',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'This will create an ERC-1155 token on Sepolia testnet',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppColors.grey,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),

            // Asset Name
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Asset Name *',
                hintText: 'e.g., Luxury Apartment #101',
                prefixIcon: Icon(Icons.home_outlined),
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter asset name';
                }
                return null;
              },
            ),
            const SizedBox(height: AppSpacing.md),

            // Category Dropdown
            categoriesAsync.when(
              data: (categories) => DropdownButtonFormField<String>(
                value: _selectedCategory,
                decoration: const InputDecoration(
                  labelText: 'Category *',
                  prefixIcon: Icon(Icons.category_outlined),
                  border: OutlineInputBorder(),
                ),
                items: categories.map((category) {
                  return DropdownMenuItem(
                    value: category,
                    child: Text(category.toUpperCase()),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _selectedCategory = value);
                  }
                },
              ),
              loading: () => const LinearProgressIndicator(),
              error: (_, __) => const SizedBox.shrink(),
            ),
            const SizedBox(height: AppSpacing.md),

            // Total Supply (Fractional Shares)
            TextFormField(
              controller: _totalSupplyController,
              decoration: const InputDecoration(
                labelText: 'Total Supply (Shares) *',
                hintText: '1000',
                helperText: 'Number of fractional shares for this asset',
                prefixIcon: Icon(Icons.pie_chart),
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
              ],
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter total supply';
                }
                final supply = int.tryParse(value);
                if (supply == null || supply <= 0) {
                  return 'Enter valid supply (minimum 1)';
                }
                return null;
              },
            ),
            const SizedBox(height: AppSpacing.md),

            // Description
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Description',
                hintText: 'Describe your asset...',
                prefixIcon: Icon(Icons.description_outlined),
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: AppSpacing.md),

            // Metadata URI (Optional)
            TextFormField(
              controller: _metadataUriController,
              decoration: const InputDecoration(
                labelText: 'Metadata URI (Optional)',
                hintText: 'ipfs://... or https://...',
                helperText:
                    'Link to IPFS or web URL with asset metadata (JSON)',
                prefixIcon: Icon(Icons.link_outlined),
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value != null && value.trim().isNotEmpty) {
                  final uri = Uri.tryParse(value);
                  if (uri == null || !uri.hasScheme) {
                    return 'Enter valid URI';
                  }
                }
                return null;
              },
            ),
            const SizedBox(height: AppSpacing.xl),

            // Error Message
            if (_errorMessage != null) ...[
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.error.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(color: AppColors.error),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: AppColors.error),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: AppColors.error,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),
            ],

            // Create Button
            ElevatedButton(
              onPressed: (_isLoading || !walletState.isConnected)
                  ? null
                  : _createAssetOnBlockchain,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                minimumSize: const Size.fromHeight(50),
              ),
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Text(
                      'Create on Blockchain',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
            const SizedBox(height: AppSpacing.sm),

            // Info Text
            Container(
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: AppColors.info.withOpacity(0.1),
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline,
                      size: 16, color: AppColors.info),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: Text(
                      'Transaction will require gas fees (ETH)',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.info,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.sm),

            // Cancel Button
            OutlinedButton(
              onPressed: _isLoading ? null : () => context.pop(),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                minimumSize: const Size.fromHeight(50),
              ),
              child: const Text('Cancel'),
            ),
          ],
        ),
      ),
    );
  }
}


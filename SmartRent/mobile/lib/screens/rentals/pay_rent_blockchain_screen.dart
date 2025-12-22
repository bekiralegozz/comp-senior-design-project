import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:web3dart/web3dart.dart';

import '../../constants/config.dart';
import '../../constants/blockchain_config.dart';
import '../../services/models.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/providers/wallet_provider.dart';
import '../../services/blockchain_service.dart';
import '../../services/wallet_service.dart';
import '../../services/api_service.dart';
import '../../widgets/success_dialog.dart';
import '../../widgets/error_dialog.dart';
import '../../widgets/wallet_connect_button.dart';

/// Provider for fetching asset details
final rentAssetProvider = FutureProvider.family<Asset, String>((ref, assetId) async {
  // TODO: Fetch asset details from blockchain or NFT service
  // For now, return a placeholder asset
  return Asset(
    id: assetId,
    title: 'Asset $assetId',
    imageUrl: null,
    category: null,
    pricePerDay: 0.0,
    currency: 'MATIC',
    location: null,
    isAvailable: true,
    tokenId: null,
    createdAt: DateTime.now(),
  );
});

/// Provider for fetching asset owners from blockchain
final assetOwnersProvider =
    FutureProvider.family<List<String>, int>((ref, tokenId) async {
  // This would query blockchain for all owners
  // For now, return empty list (will be populated from API or blockchain events)
  return [];
});

class PayRentBlockchainScreen extends ConsumerStatefulWidget {
  final String assetId;

  const PayRentBlockchainScreen({
    Key? key,
    required this.assetId,
  }) : super(key: key);

  @override
  ConsumerState<PayRentBlockchainScreen> createState() =>
      _PayRentBlockchainScreenState();
}

class _PayRentBlockchainScreenState
    extends ConsumerState<PayRentBlockchainScreen> {
  final _rentAmountController = TextEditingController();
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
      print('✅ BlockchainService initialized (Pay Rent)');
    } catch (e) {
      print('❌ Error initializing blockchain service: $e');
    }
  }

  @override
  void dispose() {
    _rentAmountController.dispose();
    super.dispose();
  }

  Future<void> _payRent() async {
    if (_rentAmountController.text.trim().isEmpty) {
      _showError('Please enter rent amount');
      return;
    }

    final rentAmount = double.tryParse(_rentAmountController.text);
    if (rentAmount == null || rentAmount <= 0) {
      _showError('Please enter valid rent amount');
      return;
    }

    // Check wallet connection and authentication
    final authState = ref.read(authStateProvider);
    if (!authState.isAuthenticated || authState.walletAddress == null) {
      _showError('Please connect your wallet first');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Get asset details
      final assetAsync = await ref.read(rentAssetProvider(widget.assetId).future);
      final asset = assetAsync;

      if (asset == null || asset.tokenId == null) {
        _showError('Asset not found or not on blockchain');
        return;
      }

      // Get services
      final walletService = WalletService();
      final blockchainService = BlockchainService();

      // Get asset owners (this should ideally come from blockchain or cached DB)
      // For now, we'll use a placeholder list
      final List<EthereumAddress> owners = [
        // In production, query blockchain for all token holders
        // For demo: use asset owner
        if (asset.owner?.walletAddress != null)
          EthereumAddress.fromHex(asset.owner!.walletAddress!),
      ];

      if (owners.isEmpty) {
        _showError('No owners found for this asset');
        return;
      }

      final assetId = BigInt.from(asset.tokenId!);
      final ethAmount = EtherAmount.fromUnitAndValue(
        EtherUnit.ether,
        rentAmount,
      );

      // Show transaction dialog
      if (!mounted) return;
      final result = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: const Text('Paying Rent on Blockchain'),
          content: Text('Please confirm the transaction in your wallet\nAmount: $rentAmount ETH'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                try {
                  // Call RentalManager.payRent()
                  final txHash = await blockchainService.payRent(
                    assetId: assetId.toInt(),
                    amount: rentAmount.toString(),
                    owners: owners.map((addr) => addr.hex).toList(),
                  );

                  final success = txHash.isNotEmpty;
                  if (context.mounted) {
                    Navigator.of(context).pop(success);
                  }
                } catch (e) {
                  if (context.mounted) {
                    Navigator.of(context).pop(false);
                  }
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
          title: 'Rent Paid!',
          message:
              'Successfully paid $rentAmount ETH.\nDistributed to ${owners.length} owner(s) proportionally.',
          onClose: () => context.pop(),
        );
      }
    } catch (e) {
      if (mounted) {
        await showErrorDialog(
          context,
          title: 'Failed to Pay Rent',
          message: parseErrorMessage(e),
          details: e.toString(),
          onRetry: _payRent,
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
    final assetAsync = ref.watch(rentAssetProvider(widget.assetId));
    final walletState = ref.watch(walletProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pay Rent (Blockchain)'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: assetAsync.when(
        data: (asset) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
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
                                'Please connect your wallet to pay rent',
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

                // Asset Info Card
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    border: Border.all(color: AppColors.lightGrey),
                  ),
                  child: Row(
                    children: [
                      // Asset Image
                      ClipRRect(
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                        child: asset.imageUrl != null
                            ? Image.network(
                                asset.imageUrl!,
                                width: 80,
                                height: 80,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return Container(
                                    width: 80,
                                    height: 80,
                                    color: AppColors.lightGrey,
                                    child: const Icon(Icons.home, size: 40),
                                  );
                                },
                              )
                            : Container(
                                width: 80,
                                height: 80,
                                color: AppColors.lightGrey,
                                child: const Icon(Icons.home, size: 40),
                              ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      // Asset Details
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              asset.title ?? 'Unnamed Asset',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            if (asset.tokenId != null)
                              Text(
                                'Token ID: ${asset.tokenId}',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: AppColors.grey,
                                ),
                              ),
                            const SizedBox(height: AppSpacing.xs),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.xs,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.success.withOpacity(0.1),
                                borderRadius:
                                    BorderRadius.circular(AppRadius.xs),
                              ),
                              child: Text(
                                'On Blockchain',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: AppColors.success,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: AppSpacing.xl),

                // Rent Amount Input
                Text(
                  'Rent Payment',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),

                TextFormField(
                  controller: _rentAmountController,
                  decoration: const InputDecoration(
                    labelText: 'Rent Amount (ETH) *',
                    hintText: '0.1',
                    helperText: 'Amount will be distributed to all owners',
                    prefixIcon: Icon(Icons.attach_money),
                    suffixText: 'ETH',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,6}')),
                  ],
                ),

                const SizedBox(height: AppSpacing.xl),

                // Wallet Balance
                if (walletState.balance != null)
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    decoration: BoxDecoration(
                      color: AppColors.info.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.account_balance_wallet,
                            size: 16, color: AppColors.info),
                        const SizedBox(width: AppSpacing.xs),
                        Text(
                          'Your Balance: ${walletState.balance} ETH',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AppColors.info,
                          ),
                        ),
                      ],
                    ),
                  ),

                const SizedBox(height: AppSpacing.md),

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
                        const Icon(Icons.error_outline,
                            color: AppColors.error),
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

                // Pay Rent Button
                ElevatedButton(
                  onPressed:
                      (_isLoading || !walletState.isConnected) ? null : _payRent,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding:
                        const EdgeInsets.symmetric(vertical: AppSpacing.md),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text(
                          'Pay Rent on Blockchain',
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
                          'Rent will be automatically distributed to all asset owners proportionally',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AppColors.info,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline,
                  size: 48, color: AppColors.error),
              const SizedBox(height: AppSpacing.md),
              Text(
                'Failed to load asset',
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                error.toString(),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColors.grey,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}


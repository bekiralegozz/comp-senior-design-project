import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../services/nft_service.dart';
import '../../services/nft_models.dart';
import '../../services/api_service.dart';
import '../../services/rental_service.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/providers/wallet_provider.dart';
import '../../core/providers/asset_provider.dart';
import '../../constants/config.dart';
import 'package:web3dart/web3dart.dart';

class NftPortfolioScreen extends ConsumerStatefulWidget {
  final String? walletAddress;

  const NftPortfolioScreen({
    Key? key,
    this.walletAddress,
  }) : super(key: key);

  @override
  ConsumerState<NftPortfolioScreen> createState() => _NftPortfolioScreenState();
}

class _NftPortfolioScreenState extends ConsumerState<NftPortfolioScreen> {
  // Services needed for operations (not for data loading - that's done by provider)
  final NftService _nftService = NftService();
  final RentalService _rentalService = RentalService();

  @override
  Widget build(BuildContext context) {
    // Use the Riverpod provider for NFT holdings (async & cached like marketplace)
    final holdingsState = ref.watch(nftHoldingsProvider(widget.walletAddress));

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/'),
        ),
        title: const Text('My NFT Portfolio'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () =>
                ref.invalidate(nftHoldingsProvider(widget.walletAddress)),
          ),
        ],
      ),
      body: _buildBody(holdingsState),
    );
  }

  Widget _buildBody(NftHoldingsState holdingsState) {
    if (holdingsState.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (holdingsState.error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(holdingsState.error!, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () =>
                  ref.invalidate(nftHoldingsProvider(widget.walletAddress)),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (holdingsState.holdings.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No NFTs found',
              style: TextStyle(fontSize: 18, color: Colors.grey[600]),
            ),
            const SizedBox(height: 8),
            Text(
              'Browse marketplace to buy fractional shares',
              style: TextStyle(color: Colors.grey[500]),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(nftHoldingsProvider(widget.walletAddress));
      },
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: holdingsState.holdings.length,
        itemBuilder: (context, index) {
          final holding = holdingsState.holdings[index];
          return _buildNftCard(holding, holdingsState.tokensWithRentalListings);
        },
      ),
    );
  }

  Widget _buildNftCard(
      UserNftHolding holding, Set<int> tokensWithRentalListings) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _showNftDetails(holding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image
            AspectRatio(
              aspectRatio: 16 / 9,
              child: holding.imageUrl.isNotEmpty
                  ? Image.network(
                      holding.imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          color: Colors.grey[300],
                          child:
                              const Icon(Icons.image_not_supported, size: 64),
                        );
                      },
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return Center(
                          child: CircularProgressIndicator(
                            value: loadingProgress.expectedTotalBytes != null
                                ? loadingProgress.cumulativeBytesLoaded /
                                    loadingProgress.expectedTotalBytes!
                                : null,
                          ),
                        );
                      },
                    )
                  : Container(
                      color: Colors.grey[300],
                      child: const Icon(Icons.home, size: 64),
                    ),
            ),

            // Info
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title
                  Text(
                    holding.name,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Token ID
                  Text(
                    'Token ID: #${holding.tokenId}',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Shares info
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Your Shares',
                              style: TextStyle(
                                color: Colors.grey[700],
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${holding.shares.toString()}',
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue,
                              ),
                            ),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              'Ownership',
                              style: TextStyle(
                                color: Colors.grey[700],
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${holding.ownershipPercentage.toStringAsFixed(2)}%',
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.green,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Action buttons
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _sellShares(holding),
                          icon: const Icon(Icons.sell, size: 14),
                          label: const Text('Sell',
                              style: TextStyle(fontSize: 12)),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 8),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Builder(
                          builder: (context) {
                            final hasRentalListing = tokensWithRentalListings
                                .contains(holding.tokenId);
                            final canRent =
                                holding.isTopShareholder && !hasRentalListing;

                            String tooltipMessage;
                            if (hasRentalListing) {
                              tooltipMessage = 'Already listed for rent';
                            } else if (holding.isTopShareholder) {
                              tooltipMessage = 'List your property for rent';
                            } else {
                              tooltipMessage =
                                  'Only the top shareholder can list for rent';
                            }

                            return Tooltip(
                              message: tooltipMessage,
                              child: ElevatedButton.icon(
                                onPressed: canRent
                                    ? () => _createRentalListing(holding)
                                    : () {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              hasRentalListing
                                                  ? 'This property is already listed for rent'
                                                  : 'Only the top shareholder can list for rent\n'
                                                      'Your ownership: ${holding.ownershipPercentage.toStringAsFixed(1)}%',
                                            ),
                                            backgroundColor: hasRentalListing
                                                ? Colors.orange[700]
                                                : Colors.grey[700],
                                            duration:
                                                const Duration(seconds: 3),
                                          ),
                                        );
                                      },
                                icon: Icon(
                                  hasRentalListing
                                      ? Icons.check_circle
                                      : Icons.home_work,
                                  size: 14,
                                  color:
                                      canRent ? Colors.white : Colors.grey[600],
                                ),
                                label: Text(
                                  hasRentalListing ? 'Listed' : 'Rent',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: canRent
                                        ? Colors.white
                                        : Colors.grey[600],
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: canRent
                                      ? Colors.orange
                                      : Colors.grey[300],
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 8),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _viewOnOpenSea(holding.tokenId),
                          icon: const Icon(Icons.open_in_new, size: 14),
                          label:
                              const Text('Sea', style: TextStyle(fontSize: 12)),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 8),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showNftDetails(UserNftHolding holding) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, scrollController) {
          return Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: ListView(
              controller: scrollController,
              padding: const EdgeInsets.all(24),
              children: [
                // Handle bar
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),

                // Title
                Text(
                  holding.name,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Token ID: #${holding.tokenId}',
                  style: TextStyle(color: Colors.grey[600]),
                ),
                const Divider(height: 32),

                // Ownership details
                _detailRow('Your Shares',
                    '${holding.shares} / ${holding.totalShares}'),
                _detailRow('Ownership',
                    '${holding.ownershipPercentage.toStringAsFixed(2)}%'),
                _detailRow(
                    'Estimated Value', '${holding.estimatedValue} MATIC'),

                const SizedBox(height: 24),

                // Action buttons
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    _sellShares(holding);
                  },
                  icon: const Icon(Icons.sell),
                  label: const Text('Sell Shares'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.all(16),
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () => _viewOnOpenSea(holding.tokenId),
                  icon: const Icon(Icons.open_in_new),
                  label: const Text('View on OpenSea'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.all(16),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(color: Colors.grey[600]),
          ),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  void _sellShares(UserNftHolding holding) async {
    // First, check how many shares are already listed
    int totalListedShares = 0;
    try {
      final walletAddress = ref.read(walletAddressProvider);
      if (walletAddress != null) {
        final myListingsResult =
            await ApiService().getMyListings(walletAddress);
        final List<dynamic> listings = myListingsResult['listings'] ?? [];

        // Calculate total shares already listed for this token
        for (var listing in listings) {
          if (listing['token_id'] == holding.tokenId &&
              listing['is_active'] == true) {
            totalListedShares += (listing['shares_remaining'] as num).toInt();
          }
        }
      }
    } catch (e) {
      print('Error fetching listings: $e');
    }

    final maxAvailableShares = holding.shares - totalListedShares;

    if (maxAvailableShares <= 0) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'All your ${holding.name} shares are already listed!\n'
              'Total owned: ${holding.shares}, Already listed: $totalListedShares',
            ),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 5),
          ),
        );
      }
      return;
    }

    final sharesController = TextEditingController();
    final priceController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool isLoading = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Handle bar
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 20),
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),

                  // Title
                  Text(
                    'Sell ${holding.name}',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Total owned: ${holding.shares} shares\n'
                    'Already listed: $totalListedShares shares\n'
                    'Available to list: $maxAvailableShares shares',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 24),

                  // Shares input
                  TextFormField(
                    controller: sharesController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Shares to sell',
                      hintText: 'Max: $maxAvailableShares',
                      border: const OutlineInputBorder(),
                      suffixText: 'shares',
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Enter number of shares';
                      }
                      final shares = int.tryParse(value);
                      if (shares == null || shares <= 0) {
                        return 'Enter a valid number';
                      }
                      if (shares > maxAvailableShares) {
                        return 'Max $maxAvailableShares shares available';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Price input
                  TextFormField(
                    controller: priceController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Price per share',
                      hintText: '0.001',
                      border: OutlineInputBorder(),
                      suffixText: 'POL',
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Enter price per share';
                      }
                      final price = double.tryParse(value);
                      if (price == null || price <= 0) {
                        return 'Enter a valid price';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),

                  // Summary
                  if (sharesController.text.isNotEmpty &&
                      priceController.text.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Total Value:'),
                          Text(
                            '${((int.tryParse(sharesController.text) ?? 0) * (double.tryParse(priceController.text) ?? 0)).toStringAsFixed(4)} POL',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 24),

                  // Create Listing button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: isLoading
                          ? null
                          : () async {
                              if (!formKey.currentState!.validate()) return;

                              setModalState(() => isLoading = true);

                              try {
                                await _createListing(
                                  holding: holding,
                                  shares: int.parse(sharesController.text),
                                  pricePerShare:
                                      double.parse(priceController.text),
                                );
                                if (mounted) Navigator.pop(context);
                              } catch (e) {
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Error: $e'),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                }
                              } finally {
                                setModalState(() => isLoading = false);
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.all(16),
                        backgroundColor: Colors.green,
                      ),
                      child: isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text(
                              'Create Listing',
                              style:
                                  TextStyle(fontSize: 16, color: Colors.white),
                            ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Cancel button
                  SizedBox(
                    width: double.infinity,
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _createListing({
    required UserNftHolding holding,
    required int shares,
    required double pricePerShare,
  }) async {
    final apiService = ApiService();
    final walletService = ref.read(walletServiceProvider);
    final walletAddress = widget.walletAddress;

    if (walletAddress == null) {
      throw Exception('Wallet not connected');
    }

    // Step 1: Check if asset is registered in SmartRentHub
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Checking asset registration...'),
          duration: Duration(seconds: 2),
        ),
      );
    }

    final isRegistered = await apiService.isAssetRegistered(holding.tokenId);

    // Step 1a: If not registered, register it first
    if (!isRegistered) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content:
                Text('Asset not registered. Registering in SmartRentHub...'),
            duration: Duration(seconds: 3),
            backgroundColor: Colors.orange,
          ),
        );
      }

      // Prepare registration transaction
      final registerResult = await apiService.prepareRegisterAsset(
        tokenId: holding.tokenId,
        owner: walletAddress,
      );

      if (registerResult['success'] != true) {
        throw Exception(
            registerResult['error'] ?? 'Failed to prepare asset registration');
      }

      // Send registration transaction
      final registerTxHash = await walletService.sendTransaction(
        to: registerResult['contract_address'] as String,
        value: EtherAmount.zero(),
        data: registerResult['function_data'] as String,
        gas: 500000, // Increased for complex contract operations
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                '⏳ Waiting for asset registration...\nTX: ${registerTxHash.substring(0, 10)}...'),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 60),
          ),
        );
      }

      // Wait for registration to complete
      final registerSuccess = await apiService
          .waitForTransaction(registerTxHash, maxWaitSeconds: 60);

      if (!registerSuccess) {
        throw Exception('Asset registration failed');
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Asset registered in SmartRentHub!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    }

    // Step 2: Check if SmartRentHub is approved
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Checking approval status...'),
          duration: Duration(seconds: 2),
        ),
      );
    }

    final isApproved = await apiService.checkApproval(walletAddress);

    // Step 2a: If not approved, request approval first
    if (!isApproved) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('First-time setup: Approving SmartRentHub...'),
            duration: Duration(seconds: 3),
            backgroundColor: Colors.orange,
          ),
        );
      }

      // Prepare approval transaction
      final approvalResult = await apiService.prepareApproval();

      if (approvalResult['success'] != true) {
        throw Exception(
            approvalResult['error'] ?? 'Failed to prepare approval');
      }

      // Send approval transaction
      final approvalTxHash = await walletService.sendTransaction(
        to: approvalResult['contract_address'] as String,
        value: EtherAmount.zero(),
        data: approvalResult['function_data'] as String,
        gas: 150000, // Increased for safety
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Approval granted! TX: ${approvalTxHash.substring(0, 10)}...'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
      }

      // Wait for transaction to be confirmed on blockchain
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content:
                Text('⏳ Waiting for approval to be confirmed on blockchain...'),
            duration: Duration(seconds: 10),
            backgroundColor: Colors.orange,
          ),
        );
      }

      // Poll blockchain to verify approval (max 30 seconds)
      bool approvalConfirmed = false;
      for (int i = 0; i < 15; i++) {
        await Future.delayed(const Duration(seconds: 2));
        approvalConfirmed = await apiService.checkApproval(walletAddress);
        if (approvalConfirmed) {
          break;
        }
      }

      if (!approvalConfirmed) {
        throw Exception(
            'Approval transaction not confirmed. Please try again.');
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Approval confirmed on blockchain!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    }

    // Step 3: Prepare listing transaction
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Creating listing...'),
          duration: Duration(seconds: 2),
        ),
      );
    }

    final prepareResult = await apiService.prepareCreateListing(
      tokenId: holding.tokenId,
      sharesForSale: shares,
      pricePerSharePol: pricePerShare,
    );

    if (prepareResult['success'] != true) {
      throw Exception(prepareResult['error'] ?? 'Failed to prepare listing');
    }

    final contractAddress = prepareResult['contract_address'] as String;
    final functionData = prepareResult['function_data'] as String;

    // Step 4: Send listing transaction via WalletConnect
    final txHash = await walletService.sendTransaction(
      to: contractAddress,
      value: EtherAmount.zero(),
      data: functionData.startsWith('0x') ? functionData : '0x$functionData',
      gas: 500000, // Increased for createListing storage operations
    );

    // Step 5: Wait for transaction to be mined
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              '⏳ Transaction sent! Waiting for blockchain confirmation...\nTX: ${txHash.substring(0, 10)}...'),
          backgroundColor: Colors.orange,
          duration: const Duration(seconds: 60),
        ),
      );
    }

    // Wait for confirmation (max 60 seconds)
    try {
      final success =
          await apiService.waitForTransaction(txHash, maxWaitSeconds: 60);

      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  '✅ Listing created successfully!\nTX: ${txHash.substring(0, 10)}...'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 5),
            ),
          );

          // Refresh holdings and marketplace
          ref.invalidate(nftHoldingsProvider(widget.walletAddress));
          ref.invalidate(listingsProvider);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  '❌ Transaction failed on blockchain!\nTX: ${txHash.substring(0, 10)}...'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 5),
            ),
          );
        }
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                '⚠️ Transaction timeout. Check transaction manually.\nTX: ${txHash.substring(0, 10)}...'),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  void _viewOnOpenSea(int tokenId) {
    final url = _nftService.getOpenSeaUrl(tokenId);
    Clipboard.setData(ClipboardData(text: url));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('OpenSea URL copied: $url'),
        action: SnackBarAction(
          label: 'OK',
          onPressed: () {},
        ),
      ),
    );
  }

  // ============================================
  // RENTAL LISTING CREATION
  // ============================================

  void _createRentalListing(UserNftHolding holding) async {
    final priceController = TextEditingController();

    final result = await showDialog<double>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.home_work, color: Colors.orange[700]),
            const SizedBox(width: 8),
            const Text('List Property for Rent'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Property Info
              Card(
                color: Colors.orange[50],
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        holding.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text('Token ID: #${holding.tokenId}'),
                      Text(
                          'Your Shares: ${holding.shares} / ${holding.totalShares}'),
                      Text(
                          'Ownership: ${holding.ownershipPercentage.toStringAsFixed(1)}%'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Property Traits
              if (holding.location.isNotEmpty ||
                  holding.activeDays.isNotEmpty) ...[
                const Text(
                  'Property Details:',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 8),
                if (holding.location.isNotEmpty)
                  Row(
                    children: [
                      Icon(Icons.location_on,
                          size: 16, color: Colors.grey[600]),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          holding.location,
                          style: TextStyle(color: Colors.grey[700]),
                        ),
                      ),
                    ],
                  ),
                if (holding.activeDays.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.calendar_today,
                          size: 16, color: Colors.grey[600]),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          'Active Days: ${holding.activeDays}',
                          style: TextStyle(color: Colors.grey[700]),
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 16),
              ],

              // Price Input
              const Text(
                'Price per Night (POL):',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: priceController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  hintText: 'e.g. 0.5',
                  prefixIcon: const Icon(Icons.attach_money),
                  suffixText: 'POL',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  filled: true,
                  fillColor: Colors.grey[100],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Renters will be able to search by location and active days',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              final priceText = priceController.text.trim();
              if (priceText.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please enter a price'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }
              final price = double.tryParse(priceText);
              if (price == null || price <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please enter a valid price'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }
              Navigator.pop(context, price);
            },
            icon: const Icon(Icons.check),
            label: const Text('Create Listing'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
            ),
          ),
        ],
      ),
    );

    if (result != null && mounted) {
      _processRentalListing(holding, result);
    }
  }

  Future<void> _processRentalListing(
      UserNftHolding holding, double pricePerNight) async {
    try {
      final walletService = ref.read(walletServiceProvider);
      final walletAddress = widget.walletAddress;

      if (walletAddress == null) {
        throw Exception('Wallet not connected');
      }

      // Show loading dialog
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Preparing rental listing...'),
            duration: Duration(seconds: 2),
          ),
        );
      }

      // Prepare transaction from backend
      final txData = await _rentalService.prepareCreateRentalListing(
        tokenId: holding.tokenId,
        pricePerNightPol: pricePerNight,
        ownerAddress: walletAddress,
      );

      if (txData['success'] != true) {
        throw Exception(txData['error'] ?? 'Failed to prepare rental listing');
      }

      final contractAddress = txData['contract_address'] as String;
      final functionData = txData['function_data'] as String;

      // Send transaction via WalletConnect
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Creating rental listing...'),
            duration: Duration(seconds: 2),
          ),
        );
      }

      final txHash = await walletService.sendTransaction(
        to: contractAddress,
        value: EtherAmount.zero(),
        data: functionData.startsWith('0x') ? functionData : '0x$functionData',
        gas: 500000,
      );

      if (!mounted) return;

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '✅ Rental listing created!\n'
            'Price: $pricePerNight POL/night\n'
            'TX: ${txHash.substring(0, 10)}...',
          ),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 5),
        ),
      );

      // Refresh holdings
      ref.invalidate(nftHoldingsProvider(widget.walletAddress));
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Failed to create rental listing: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }
}

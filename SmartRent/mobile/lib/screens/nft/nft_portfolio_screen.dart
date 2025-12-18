import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/nft_service.dart';
import '../../services/nft_models.dart';
import '../../services/api_service.dart';
import '../../core/providers/wallet_provider.dart';
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
  final NftService _nftService = NftService();
  List<UserNftHolding> _holdings = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadHoldings();
  }

  Future<void> _loadHoldings() async {
    if (widget.walletAddress == null) {
      setState(() {
        _error = 'Wallet not connected';
        _isLoading = false;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final holdings = await _nftService.getUserHoldings(widget.walletAddress!);
      setState(() {
        _holdings = holdings;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My NFT Portfolio'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadHoldings,
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(_error!, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadHoldings,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_holdings.isEmpty) {
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
      onRefresh: _loadHoldings,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _holdings.length,
        itemBuilder: (context, index) {
          final holding = _holdings[index];
          return _buildNftCard(holding);
        },
      ),
    );
  }

  Widget _buildNftCard(UserNftHolding holding) {
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
                          child: const Icon(Icons.image_not_supported, size: 64),
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
                          icon: const Icon(Icons.sell, size: 16),
                          label: const Text('Sell'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _viewOnOpenSea(holding.tokenId),
                          icon: const Icon(Icons.open_in_new, size: 16),
                          label: const Text('OpenSea'),
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
                _detailRow('Your Shares', '${holding.shares} / ${holding.totalShares}'),
                _detailRow('Ownership', '${holding.ownershipPercentage.toStringAsFixed(2)}%'),
                _detailRow('Estimated Value', '${holding.estimatedValue} MATIC'),
                
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

  void _sellShares(UserNftHolding holding) {
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
                    'Available: ${holding.shares} shares (${holding.ownershipPercentage.toStringAsFixed(1)}%)',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 24),
                  
                  // Shares input
                  TextFormField(
                    controller: sharesController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Shares to sell',
                      hintText: 'Max: ${holding.shares}',
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
                      if (shares > holding.shares) {
                        return 'Max ${holding.shares} shares';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  
                  // Price input
                  TextFormField(
                    controller: priceController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
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
                  if (sharesController.text.isNotEmpty && priceController.text.isNotEmpty)
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
                                  pricePerShare: double.parse(priceController.text),
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
                              style: TextStyle(fontSize: 16, color: Colors.white),
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
    
    // Step 1: First need to approve SmartRentHub to transfer tokens
    // For now, we'll skip approval check and assume user has approved
    // TODO: Add approval check and approval flow
    
    // Step 2: Prepare listing transaction
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
    
    // Step 3: Send transaction via WalletConnect
    final txHash = await walletService.sendTransaction(
      to: contractAddress,
      value: EtherAmount.zero(),
      data: functionData.startsWith('0x') ? functionData : '0x$functionData',
      gas: 200000,
    );
    
    // Step 4: Show success
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Listing created! TX: ${txHash.substring(0, 10)}...'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 5),
        ),
      );
      
      // Refresh holdings
      _loadHoldings();
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
}

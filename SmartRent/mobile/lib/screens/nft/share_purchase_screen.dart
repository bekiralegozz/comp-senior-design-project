import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/nft_service.dart';
import '../../services/nft_models.dart';

class SharePurchaseScreen extends StatefulWidget {
  final NftAsset asset;
  final String? walletAddress;

  const SharePurchaseScreen({
    Key? key,
    required this.asset,
    this.walletAddress,
  }) : super(key: key);

  @override
  State<SharePurchaseScreen> createState() => _SharePurchaseScreenState();
}

class _SharePurchaseScreenState extends State<SharePurchaseScreen> {
  final NftService _nftService = NftService();
  final TextEditingController _sharesController = TextEditingController();
  
  List<ShareListing> _listings = [];
  ShareListing? _selectedListing;
  bool _isLoading = true;
  bool _isPurchasing = false;
  String? _error;
  int _shareAmount = 0;
  double _totalPrice = 0.0;

  @override
  void initState() {
    super.initState();
    _loadListings();
    _sharesController.addListener(_updateTotalPrice);
  }

  @override
  void dispose() {
    _sharesController.dispose();
    super.dispose();
  }

  Future<void> _loadListings() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final listings = await _nftService.getMarketplaceListings(widget.asset.tokenId);
      setState(() {
        _listings = listings.where((l) => l.isActive).toList();
        if (_listings.isNotEmpty) {
          _selectedListing = _listings.first;
        }
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  void _updateTotalPrice() {
    final shares = int.tryParse(_sharesController.text) ?? 0;
    if (_selectedListing != null) {
      final price = _nftService.calculateTotalPrice(
        _selectedListing!.pricePerShare,
        shares,
      );
      setState(() {
        _shareAmount = shares;
        _totalPrice = price;
      });
    }
  }

  Future<void> _purchaseShares() async {
    if (widget.walletAddress == null) {
      _showError('Please connect your wallet first');
      return;
    }

    if (_selectedListing == null) {
      _showError('Please select a listing');
      return;
    }

    if (_shareAmount <= 0) {
      _showError('Please enter a valid amount of shares');
      return;
    }

    if (_shareAmount > _selectedListing!.sharesAvailable) {
      _showError('Not enough shares available');
      return;
    }

    // Show confirmation dialog
    final confirmed = await _showConfirmationDialog();
    if (!confirmed) return;

    setState(() {
      _isPurchasing = true;
      _error = null;
    });

    try {
      final request = SharePurchaseRequest(
        tokenId: widget.asset.tokenId,
        sellerAddress: _selectedListing!.seller,
        shareAmount: _shareAmount,
        pricePerShare: _selectedListing!.pricePerShare,
        buyerAddress: widget.walletAddress!,
      );

      final txHash = await _nftService.buyShares(request);

      if (mounted) {
        _showSuccessDialog(txHash);
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isPurchasing = false;
      });
      _showError('Purchase failed: ${e.toString()}');
    }
  }

  Future<bool> _showConfirmationDialog() async {
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Purchase'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Asset: ${widget.asset.name}'),
            const SizedBox(height: 8),
            Text('Shares: $_shareAmount'),
            Text('Price per share: ${_nftService.formatMatic(_selectedListing!.pricePerShare)}'),
            const Divider(height: 24),
            Text(
              'Total: ${_nftService.formatMatic(_totalPrice)}',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'This transaction will be executed on Polygon Mainnet.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    ) ?? false;
  }

  void _showSuccessDialog(String txHash) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green, size: 32),
            SizedBox(width: 12),
            Text('Purchase Successful!'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('You have successfully purchased $_shareAmount shares!'),
            const SizedBox(height: 16),
            const Text('Transaction Hash:', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(
              txHash,
              style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: () {
                final url = _nftService.getPolygonScanTxUrl(txHash);
                Clipboard.setData(ClipboardData(text: url));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Transaction URL copied!')),
                );
              },
              icon: const Icon(Icons.copy, size: 16),
              label: const Text('Copy PolygonScan Link'),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              Navigator.pop(context); // Return to previous screen
            },
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Buy Shares'),
      ),
      body: _buildBody(),
      bottomNavigationBar: _buildBottomBar(),
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
              onPressed: _loadListings,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_listings.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.store_outlined, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            const Text(
              'No shares available for sale',
              style: TextStyle(fontSize: 18),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Asset card
          _buildAssetCard(),
          const SizedBox(height: 24),
          
          // Listings
          const Text(
            'Available Listings',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          ..._listings.map((listing) => _buildListingCard(listing)),
          
          const SizedBox(height: 24),
          
          // Share amount input
          const Text(
            'Number of Shares',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _sharesController,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(
              hintText: 'Enter amount',
              border: const OutlineInputBorder(),
              suffixText: _selectedListing != null
                  ? 'Max: ${_selectedListing!.sharesAvailable}'
                  : '',
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Price summary
          if (_shareAmount > 0) _buildPriceSummary(),
        ],
      ),
    );
  }

  Widget _buildAssetCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: widget.asset.imageUrl.isNotEmpty
                  ? Image.network(
                      widget.asset.imageUrl,
                      width: 80,
                      height: 80,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          width: 80,
                          height: 80,
                          color: Colors.grey[300],
                          child: const Icon(Icons.image_not_supported),
                        );
                      },
                    )
                  : Container(
                      width: 80,
                      height: 80,
                      color: Colors.grey[300],
                      child: const Icon(Icons.home),
                    ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.asset.name,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Token ID: #${widget.asset.tokenId}',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Total Shares: ${widget.asset.totalShares}',
                    style: TextStyle(color: Colors.grey[700]),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildListingCard(ShareListing listing) {
    final isSelected = _selectedListing?.listingId == listing.listingId;
    
    return Card(
      color: isSelected ? Colors.blue.shade50 : null,
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedListing = listing;
            _updateTotalPrice();
          });
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Radio<String>(
                value: listing.listingId,
                groupValue: _selectedListing?.listingId,
                onChanged: (value) {
                  setState(() {
                    _selectedListing = listing;
                    _updateTotalPrice();
                  });
                },
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Seller: ${listing.seller.substring(0, 6)}...${listing.seller.substring(listing.seller.length - 4)}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text('Price: ${_nftService.formatMatic(listing.pricePerShare)} per share'),
                    Text('Available: ${listing.sharesAvailable} shares'),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPriceSummary() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.green.shade200),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Shares:'),
              Text('$_shareAmount', style: const TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Price per share:'),
              Text(
                _nftService.formatMatic(_selectedListing!.pricePerShare),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const Divider(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Total Price:',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              Text(
                _nftService.formatMatic(_totalPrice),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: ElevatedButton(
          onPressed: _isPurchasing || _shareAmount <= 0
              ? null
              : _purchaseShares,
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.all(16),
          ),
          child: _isPurchasing
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text(
                  'Purchase Shares',
                  style: TextStyle(fontSize: 16),
                ),
        ),
      ),
    );
  }
}

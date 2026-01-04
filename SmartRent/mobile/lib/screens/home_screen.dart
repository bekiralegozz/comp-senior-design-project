import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:web3dart/web3dart.dart';

import '../constants/config.dart';
import '../services/models.dart';
import '../services/api_service.dart';
import '../services/wallet_service.dart';
import '../services/rental_service.dart';
import '../services/rental_models.dart';
import '../components/asset_card.dart';
import '../components/wallet_info_widget.dart';
import '../core/providers/auth_provider.dart';
import '../core/providers/asset_provider.dart'; // Includes listingsProvider, MarketplaceListing
import '../core/providers/wallet_provider.dart';

/// ==========================================================
/// HOME SCREEN - BLOCKCHAIN MIGRATION VERSION
/// ==========================================================
///
/// Uses blockchain-based providers for asset data.
/// Categories are now static (from config).

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

enum SortBy { highestPrice, lowestPrice }

class _HomeScreenState extends ConsumerState<HomeScreen> with SingleTickerProviderStateMixin {
  final _searchController = TextEditingController();
  String _selectedCategory = '';
  late TabController _tabController;
  
  // Marketplace filters and sorting
  SortBy? _sortBy;
  bool _filterAffordable = false;
  bool _filterMyListings = false;
  
  // Rental service and state
  final _rentalService = RentalService();
  List<RentalListing> _rentalListings = [];
  bool _isLoadingRentals = false;
  String? _lastWalletAddress; // Track wallet changes

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    
    // Listen to tab changes to refresh Rentplace when opened
    _tabController.addListener(() {
      if (_tabController.index == 2 && mounted) { // Index 2 is Rentplace
        _checkAndRefreshRentals();
      }
    });
  }
  
  /// Check if wallet changed and refresh rentals if needed
  void _checkAndRefreshRentals() {
    final currentWallet = ref.read(walletProvider).address;
    
    // Refresh if:
    // 1. First time loading (list empty)
    // 2. Wallet changed since last load
    if (_rentalListings.isEmpty || currentWallet != _lastWalletAddress) {
      _lastWalletAddress = currentWallet;
      _loadRentalListings();
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final assetListState = ref.watch(assetListProvider(null));
    final categories = ref.watch(assetCategoriesProvider);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Icon(
              Icons.home_work,
              color: AppColors.primary,
              size: 28,
            ),
            const SizedBox(width: 8),
            const Text(
              'SmartRent',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
          ],
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.primary,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.grey,
          tabs: const [
            Tab(
              icon: Icon(Icons.home_outlined),
              text: 'Home',
            ),
            Tab(
              icon: Icon(Icons.storefront_outlined),
              text: 'Marketplace',
            ),
            Tab(
              icon: Icon(Icons.key_outlined),
              text: 'Rentplace',
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Notifications coming soon!')),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.account_balance_wallet_outlined),
            onPressed: () {
              context.go('/auth/wallet');
            },
          ),
          IconButton(
            icon: const Icon(Icons.token_outlined),
            tooltip: 'NFT Gallery',
            onPressed: () {
              context.go('/nft-gallery');
            },
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) async {
              if (value == 'logout') {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Logout'),
                    content: const Text('Are you sure you want to disconnect your wallet?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(true),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.red,
                        ),
                        child: const Text('Disconnect'),
                      ),
                    ],
                  ),
                );

                if (confirm == true && mounted) {
                  await ref.read(authStateProvider.notifier).logout();
                  if (mounted) {
                    context.go('/auth/wallet');
                  }
                }
              } else if (value == 'settings') {
                context.go('/settings');
              } else if (value == 'nft-portfolio') {
                final walletAddress = ref.read(walletAddressProvider);
                context.go('/nft-portfolio?wallet=${walletAddress ?? ''}');
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'nft-portfolio',
                child: Row(
                  children: [
                    Icon(Icons.account_balance_wallet, size: 20),
                    SizedBox(width: 8),
                    Text('My NFT Portfolio'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'settings',
                child: Row(
                  children: [
                    Icon(Icons.settings_outlined, size: 20),
                    SizedBox(width: 8),
                    Text('Settings'),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(Icons.logout, size: 20, color: Colors.red),
                    SizedBox(width: 8),
                    Text('Disconnect Wallet', style: TextStyle(color: Colors.red)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Home Tab
          RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(assetListProvider(null));
            },
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Welcome Header
                  _buildWelcomeHeader(theme),
                  const SizedBox(height: AppSpacing.lg),

                  // Search Bar
                  _buildSearchBar(theme),
                  const SizedBox(height: AppSpacing.lg),

                  // Quick Stats
                  _buildQuickStats(theme, assetListState),
                  const SizedBox(height: AppSpacing.lg),

                  // Categories
                  _buildCategoriesSection(categories, theme),
                  const SizedBox(height: AppSpacing.lg),

                  // Featured Assets - DISABLED (assets shown in My NFTs only)
                  // _buildFeaturedAssetsSection(assetListState, theme),
                  // const SizedBox(height: AppSpacing.lg),

                  // Quick Actions
                  _buildQuickActions(theme),
                ],
              ),
            ),
          ),
          // Marketplace Tab
          _buildMarketplaceTab(theme),
          // Rentplace Tab
          _buildRentplaceTab(theme),
        ],
      ),
    );
  }

  Widget _buildWelcomeHeader(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Wallet Info Widget
        const WalletInfoWidget(),
        const SizedBox(height: AppSpacing.md),
        
        // Welcome Banner
        Container(
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Welcome to SmartRent',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Rent anything, anywhere, anytime with blockchain security',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: AppColors.darkGrey,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSearchBar(ThemeData theme) {
    return Container(
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Search for assets...',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: () {
              // TODO: Show filter options
            },
          ),
          filled: true,
          fillColor: theme.cardColor,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
            borderSide: BorderSide.none,
          ),
        ),
        onSubmitted: (value) {
          if (value.isNotEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Searching for "$value"...')),
            );
          }
        },
      ),
    );
  }

  Widget _buildQuickStats(ThemeData theme, AssetListState assetListState) {
    final assetCount = assetListState.assets.length;
    
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            theme,
            'Available Assets',
            assetListState.isLoading ? '...' : assetCount.toString(),
            Icons.inventory_2_outlined,
            AppColors.primary,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: _buildStatCard(
            theme,
            'On Blockchain',
            assetListState.isLoading ? '...' : assetCount.toString(),
            Icons.token,
            AppColors.success,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: _buildStatCard(
            theme,
            'Network',
            'Polygon',
            Icons.lan,
            AppColors.secondary,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(
    ThemeData theme,
    String title,
    String value,
    IconData icon,
    Color color,
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
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: AppSpacing.xs),
          Text(
            value,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            title,
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppColors.grey,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildCategoriesSection(List<String> categories, ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Browse Categories',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        SizedBox(
          height: 100,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: categories.length,
            itemBuilder: (context, index) {
              final category = categories[index];
              final isSelected = _selectedCategory == category;
              
              return Padding(
                padding: EdgeInsets.only(
                  right: index < categories.length - 1 ? AppSpacing.sm : 0,
                ),
                child: _buildCategoryCard(
                  theme,
                  category,
                  isSelected,
                  () {
                    setState(() {
                      _selectedCategory = isSelected ? '' : category;
                    });
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryCard(
    ThemeData theme,
    String category,
    bool isSelected,
    VoidCallback onTap,
  ) {
    final color = AppColors.categoryColors[category] ?? AppColors.grey;
    
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 80,
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.2) : theme.cardColor,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(
            color: isSelected ? color : Colors.transparent,
            width: 2,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              AssetCategories.icons[category] ?? Icons.category,
              color: color,
              size: 32,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              AssetCategories.getDisplayName(category),
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeaturedAssetsSection(AssetListState assetListState, ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Featured Assets',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            TextButton(
              onPressed: () {
                _tabController.animateTo(1);
              },
              child: const Text('See All'),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        _buildAssetContent(assetListState, theme, isFeatured: true),
      ],
    );
  }

  Widget _buildAssetContent(AssetListState state, ThemeData theme, {bool isFeatured = false}) {
    if (state.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    
    if (state.error != null) {
      return Center(
        child: Column(
          children: [
            Icon(Icons.error_outline, color: AppColors.error, size: 48),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Error loading assets',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              state.error!,
              style: theme.textTheme.bodySmall?.copyWith(color: AppColors.grey),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.md),
            ElevatedButton(
              onPressed: () => ref.invalidate(assetListProvider(null)),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    final assets = state.assets;
    
    if (assets.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(AppSpacing.xl),
        decoration: BoxDecoration(
          color: AppColors.lightGrey,
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Column(
          children: [
            Icon(Icons.inventory_2_outlined, size: 64, color: AppColors.grey),
            const SizedBox(height: AppSpacing.md),
            Text(
              'No Assets Yet',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'NFT assets from the blockchain will appear here.\nCreate your first asset to get started!',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppColors.grey,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            ElevatedButton.icon(
              onPressed: () => context.push('/assets/create'),
              icon: const Icon(Icons.add),
              label: const Text('Create Asset'),
            ),
          ],
        ),
      );
    }

    if (isFeatured) {
      return SizedBox(
        height: 320,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          itemCount: assets.take(10).length,
          itemBuilder: (context, index) {
            final asset = assets[index];
            return Padding(
              padding: EdgeInsets.only(
                right: index < assets.length - 1 ? AppSpacing.sm : 0,
              ),
              child: SizedBox(
                width: 220,
                height: 320,
                child: AssetCard(
                  asset: asset,
                  onTap: () => context.go('/asset/${asset.id}'),
                  compact: false,
                ),
              ),
            );
          },
        ),
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildQuickActions(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quick Actions',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          children: [
            Expanded(
              child: _buildActionButton(
                theme,
                'Create NFT',
                Icons.add_circle_outline,
                AppColors.primary,
                () => context.push('/assets/create'),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: _buildActionButton(
                theme,
                'My Rentals',
                Icons.receipt_long_outlined,
                AppColors.secondary,
                () => context.go('/rentals'),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            Expanded(
              child: _buildActionButton(
                theme,
                'NFT Gallery',
                Icons.collections_outlined,
                Colors.purple,
                () => context.go('/nft-gallery'),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: _buildActionButton(
                theme,
                'My NFTs',
                Icons.account_balance_wallet,
                Colors.green,
                () {
                  final walletAddress = ref.read(walletAddressProvider);
                  context.go('/nft-portfolio?wallet=${walletAddress ?? ''}');
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionButton(
    ThemeData theme,
    String title,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: AppSpacing.sm),
            Text(
              title,
              style: theme.textTheme.titleSmall?.copyWith(
                color: color,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMarketplaceTab(ThemeData theme) {
    final listingsState = ref.watch(listingsProvider);
    final walletAddress = ref.watch(walletAddressProvider);
    
    // Get user's balance for filtering (convert String to double)
    final walletState = ref.watch(walletProvider);
    final userBalance = walletState.balance != null 
        ? double.tryParse(walletState.balance!) 
        : null;

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(listingsProvider);
      },
      child: Column(
        children: [
          // Filter and Sort buttons
          Container(
            padding: const EdgeInsets.all(AppSpacing.sm),
            child: Row(
              children: [
                // Sort button
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _showSortOptions(theme),
                    icon: const Icon(Icons.sort),
                    label: Text(_sortBy == null 
                        ? 'Sort' 
                        : _sortBy == SortBy.highestPrice 
                            ? 'Highest Price' 
                            : 'Lowest Price'),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                // Filter button
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _showFilterOptions(theme),
                    icon: Icon(
                      Icons.filter_list,
                      color: (_filterAffordable || _filterMyListings) ? AppColors.primary : null,
                    ),
                    label: Text(
                      (_filterAffordable || _filterMyListings) 
                          ? 'Filter (${(_filterAffordable ? 1 : 0) + (_filterMyListings ? 1 : 0)})' 
                          : 'Filter',
                      style: TextStyle(
                        color: (_filterAffordable || _filterMyListings) ? AppColors.primary : null,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Listings
          Expanded(
            child: listingsState.isLoading
                ? const Center(child: CircularProgressIndicator())
                : listingsState.error != null
                    ? _buildMarketplaceError(theme, listingsState.error!)
                    : listingsState.listings.isEmpty
                        ? _buildEmptyMarketplace(theme)
                        : _buildListingsGrid(
                            theme, 
                            _filterAndSortListings(
                              listingsState.listings,
                              userBalance,
                              walletAddress,
                            ),
                          ),
          ),
        ],
      ),
    );
  }

  Widget _buildMarketplaceError(ThemeData theme, String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: AppColors.error),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Failed to load marketplace',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              error,
              style: theme.textTheme.bodySmall?.copyWith(color: AppColors.grey),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.lg),
            ElevatedButton(
              onPressed: () => ref.invalidate(listingsProvider),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyMarketplace(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.storefront_outlined,
              size: 80,
              color: AppColors.primary.withOpacity(0.5),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'No Active Listings',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Be the first to list your fractional NFT shares!',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppColors.grey,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xl),
            ElevatedButton.icon(
              onPressed: () {
                final walletAddress = ref.read(walletAddressProvider);
                context.go('/nft-portfolio?wallet=${walletAddress ?? ''}');
              },
              icon: const Icon(Icons.sell),
              label: const Text('Sell My Shares'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildListingsGrid(ThemeData theme, List<MarketplaceListing> listings) {
    return ListView.builder(
      padding: const EdgeInsets.all(AppSpacing.md),
      itemCount: listings.length,
      itemBuilder: (context, index) {
        final listing = listings[index];
        return _buildListingCard(theme, listing);
      },
    );
  }

  Widget _buildListingCard(ThemeData theme, MarketplaceListing listing) {
    final walletAddress = ref.watch(walletAddressProvider);
    final isOwnListing = walletAddress != null && 
                         listing.seller.toLowerCase() == walletAddress.toLowerCase();
    
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      child: InkWell(
        onTap: () {
          // TODO: Navigate to listing detail
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Listing #${listing.listingId} - Coming soon!')),
          );
        },
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadius.md)),
              child: listing.assetImage.isNotEmpty
                  ? Image.network(
                      listing.assetImage,
                      height: 150,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        height: 150,
                        color: AppColors.lightGrey,
                        child: const Icon(Icons.home, size: 48, color: AppColors.grey),
                      ),
                    )
                  : Container(
                      height: 150,
                      color: AppColors.lightGrey,
                      child: const Center(
                        child: Icon(Icons.home, size: 48, color: AppColors.grey),
                      ),
                    ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title and Token ID
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          listing.assetName,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '#${listing.tokenId}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  
                  // Shares info
                  Row(
                    children: [
                      Icon(Icons.pie_chart_outline, size: 16, color: AppColors.grey),
                      const SizedBox(width: 4),
                      Text(
                        '${listing.sharesRemaining} / ${listing.totalShares} shares',
                        style: theme.textTheme.bodySmall?.copyWith(color: AppColors.grey),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '(${listing.percentageForSale.toStringAsFixed(1)}%)',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  
                  // Price
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Price per share',
                            style: theme.textTheme.bodySmall?.copyWith(color: AppColors.grey),
                          ),
                          Text(
                            '${listing.pricePerSharePol.toStringAsFixed(4)} POL',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                      isOwnListing
                          ? Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                OutlinedButton.icon(
                                  onPressed: () => _showEditListingDialog(listing),
                                  icon: const Icon(Icons.edit, size: 16),
                                  label: const Text('Edit', style: TextStyle(fontSize: 13)),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: AppColors.primary,
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    minimumSize: const Size(0, 32),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                OutlinedButton.icon(
                                  onPressed: () => _removeListing(listing),
                                  icon: const Icon(Icons.delete, size: 16),
                                  label: const Text('Remove', style: TextStyle(fontSize: 13)),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: AppColors.error,
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    minimumSize: const Size(0, 32),
                                  ),
                                ),
                              ],
                            )
                          : ElevatedButton(
                              onPressed: () => _showBuyDialog(listing),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.success,
                              ),
                              child: const Text('Buy'),
                            ),
                    ],
                  ),
                  
                  // Seller
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'Seller: ${listing.seller.substring(0, 6)}...${listing.seller.substring(listing.seller.length - 4)}',
                    style: theme.textTheme.bodySmall?.copyWith(color: AppColors.grey),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showBuyDialog(MarketplaceListing listing) {
    final sharesController = TextEditingController(text: '1');
    final formKey = GlobalKey<FormState>();
    bool isLoading = false;
    int sharesToBuy = 1;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          final totalCost = sharesToBuy * listing.pricePerSharePol;
          
          return Container(
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
                      'Buy ${listing.assetName}',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Available: ${listing.sharesRemaining} shares @ ${listing.pricePerSharePol.toStringAsFixed(4)} POL each',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 24),
                    
                    // Shares input
                    TextFormField(
                      controller: sharesController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Shares to buy',
                        hintText: 'Max: ${listing.sharesRemaining}',
                        border: const OutlineInputBorder(),
                        suffixText: 'shares',
                      ),
                      onChanged: (value) {
                        setModalState(() {
                          sharesToBuy = int.tryParse(value) ?? 0;
                        });
                      },
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Enter number of shares';
                        }
                        final shares = int.tryParse(value);
                        if (shares == null || shares <= 0) {
                          return 'Enter a valid number';
                        }
                        if (shares > listing.sharesRemaining) {
                          return 'Max ${listing.sharesRemaining} shares';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),
                    
                    // Summary
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.green.shade200),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Price per share:'),
                              Text('${listing.pricePerSharePol.toStringAsFixed(4)} POL'),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Shares to buy:'),
                              Text('$sharesToBuy'),
                            ],
                          ),
                          const Divider(height: 24),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Total Cost:',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                              Text(
                                '${totalCost.toStringAsFixed(4)} POL',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                  color: Colors.green,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    
                    // Buy button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: isLoading
                            ? null
                            : () async {
                                if (!formKey.currentState!.validate()) return;
                                
                                setModalState(() => isLoading = true);
                                
                                try {
                                  await _executeBuy(
                                    listing: listing,
                                    sharesToBuy: sharesToBuy,
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
                            : Text(
                                'Buy for ${totalCost.toStringAsFixed(4)} POL',
                                style: const TextStyle(fontSize: 16, color: Colors.white),
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
          );
        },
      ),
    );
  }

  Future<void> _executeBuy({
    required MarketplaceListing listing,
    required int sharesToBuy,
  }) async {
    final apiService = ApiService();
    final walletService = ref.read(walletServiceProvider);
    
    // Step 1: Prepare buy transaction
    final prepareResult = await apiService.prepareBuyListing(
      listingId: listing.listingId,
      sharesToBuy: sharesToBuy,
    );
    
    if (prepareResult['success'] != true) {
      throw Exception(prepareResult['error'] ?? 'Failed to prepare buy transaction');
    }
    
    final contractAddress = prepareResult['contract_address'] as String;
    final functionData = prepareResult['function_data'] as String;
    final valueWei = BigInt.parse(prepareResult['value_wei'] as String);
    
    // Step 2: Send transaction via WalletConnect (with POL value)
    final txHash = await walletService.sendTransaction(
      to: contractAddress,
      value: EtherAmount.inWei(valueWei),
      data: functionData.startsWith('0x') ? functionData : '0x$functionData',
      gas: 300000,
    );
    
    // Step 3: Show pending message
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('⏳ Waiting for transaction to complete...\nTX: ${txHash.substring(0, 10)}...'),
          backgroundColor: Colors.orange,
          duration: const Duration(seconds: 60),
        ),
      );
    }
    
    // Step 4: Wait for transaction to be mined
    final success = await apiService.waitForTransaction(txHash, maxWaitSeconds: 60);
    
    if (!success) {
      throw Exception('Transaction failed or timed out');
    }
    
    // Step 5: Show success and refresh
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ Purchase successful! TX: ${txHash.substring(0, 10)}...'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 5),
        ),
      );
      
      // Refresh listings - now the blockchain is updated!
      ref.invalidate(listingsProvider);
      
      // Also refresh user's assets
      ref.invalidate(allAssetsProvider);
    }
  }

  // Filter and sort listings
  List<MarketplaceListing> _filterAndSortListings(
    List<MarketplaceListing> listings,
    double? userBalance,
    String? walletAddress,
  ) {
    var filtered = listings;
    
    // Apply "Listed by Me" filter
    if (_filterMyListings && walletAddress != null) {
      filtered = filtered.where((listing) {
        return listing.seller.toLowerCase() == walletAddress.toLowerCase();
      }).toList();
    }
    
    // Apply affordable filter
    if (_filterAffordable && userBalance != null) {
      filtered = filtered.where((listing) {
        return listing.pricePerSharePol <= userBalance;
      }).toList();
    }
    
    // Apply sorting
    if (_sortBy != null) {
      filtered = List.from(filtered);
      if (_sortBy == SortBy.highestPrice) {
        filtered.sort((a, b) => b.pricePerSharePol.compareTo(a.pricePerSharePol));
      } else {
        filtered.sort((a, b) => a.pricePerSharePol.compareTo(b.pricePerSharePol));
      }
    }
    
    return filtered;
  }

  void _showSortOptions(ThemeData theme) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Sort By',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            ListTile(
              leading: Icon(
                Icons.arrow_downward,
                color: _sortBy == SortBy.highestPrice ? AppColors.primary : null,
              ),
              title: const Text('Highest Price'),
              selected: _sortBy == SortBy.highestPrice,
              onTap: () {
                setState(() => _sortBy = SortBy.highestPrice);
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: Icon(
                Icons.arrow_upward,
                color: _sortBy == SortBy.lowestPrice ? AppColors.primary : null,
              ),
              title: const Text('Lowest Price'),
              selected: _sortBy == SortBy.lowestPrice,
              onTap: () {
                setState(() => _sortBy = SortBy.lowestPrice);
                Navigator.pop(context);
              },
            ),
            if (_sortBy != null)
              ListTile(
                leading: const Icon(Icons.clear),
                title: const Text('Clear Sort'),
                onTap: () {
                  setState(() => _sortBy = null);
                  Navigator.pop(context);
                },
              ),
          ],
        ),
      ),
    );
  }

  void _showFilterOptions(ThemeData theme) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Filter',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            CheckboxListTile(
              title: const Text('Listed by Me'),
              subtitle: const Text('Only show my listings'),
              value: _filterMyListings,
              onChanged: (value) {
                setState(() => _filterMyListings = value ?? false);
                Navigator.pop(context);
              },
            ),
            CheckboxListTile(
              title: const Text('Affordable NFTs'),
              subtitle: const Text('Only show shares within my balance'),
              value: _filterAffordable,
              onChanged: (value) {
                setState(() => _filterAffordable = value ?? false);
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  // Remove listing
  Future<void> _removeListing(MarketplaceListing listing) async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Listing'),
        content: Text(
          'Are you sure you want to remove this listing?\n\n'
          '${listing.sharesRemaining} shares will be unlisted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    // Show loading dialog
    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: Card(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Sign transaction in wallet...', style: TextStyle(fontSize: 16)),
                ],
              ),
            ),
          ),
        ),
      );
    }

    try {
      final apiService = ApiService();
      final walletService = ref.read(walletServiceProvider);

      // Prepare cancel transaction
      final prepareResult = await apiService.prepareCancelListing(listing.listingId);

      if (prepareResult['success'] != true) {
        throw Exception(prepareResult['error'] ?? 'Failed to prepare cancel');
      }

      // Send transaction
      final txHash = await walletService.sendTransaction(
        to: prepareResult['contract_address'] as String,
        value: EtherAmount.zero(),
        data: prepareResult['function_data'] as String,
        gas: 200000,
      );

      // Update loading message
      if (mounted) {
        Navigator.pop(context); // Close loading dialog
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => Center(
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 16),
                    Text('Waiting for confirmation...\n${txHash.substring(0, 10)}...', 
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 16)),
                  ],
                ),
              ),
            ),
          ),
        );
      }

      // Wait for confirmation
      final success = await apiService.waitForTransaction(txHash, maxWaitSeconds: 60);
      
      // Close loading dialog
      if (mounted) Navigator.pop(context);

      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('✅ Listing removed!\nTX: ${txHash.substring(0, 10)}...'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 5),
            ),
          );
          ref.invalidate(listingsProvider);
        } else {
          throw Exception('Transaction failed');
        }
      }
    } catch (e) {
      // Close loading dialog if open
      if (mounted) Navigator.pop(context);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Failed to remove listing: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  // Edit listing (cancel + create new)
  void _showEditListingDialog(MarketplaceListing listing) {
    final sharesController = TextEditingController(
      text: listing.sharesRemaining.toString(),
    );
    final priceController = TextEditingController(
      text: listing.pricePerSharePol.toStringAsFixed(4),
    );
    final formKey = GlobalKey<FormState>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
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
                  'Edit Listing - ${listing.assetName}',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 24),
                
                // Shares input
                TextFormField(
                  controller: sharesController,
                  decoration: const InputDecoration(
                    labelText: 'Number of Shares',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter number of shares';
                    }
                    final shares = int.tryParse(value);
                    if (shares == null || shares <= 0) {
                      return 'Shares must be greater than 0';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                
                // Price input
                TextFormField(
                  controller: priceController,
                  decoration: const InputDecoration(
                    labelText: 'Price per Share (POL)',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter price';
                    }
                    final price = double.tryParse(value);
                    if (price == null || price <= 0) {
                      return 'Price must be greater than 0';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),
                
                // Update button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () async {
                      if (!formKey.currentState!.validate()) return;
                      
                      final shares = int.parse(sharesController.text);
                      final price = double.parse(priceController.text);
                      
                      Navigator.pop(context);
                      await _executeEditListing(listing, shares, price);
                    },
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.all(16),
                      backgroundColor: AppColors.primary,
                    ),
                    child: const Text(
                      'Update Listing',
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
    );
  }

  // Execute edit listing (cancel old + create new)
  Future<void> _executeEditListing(
    MarketplaceListing oldListing,
    int newShares,
    double newPrice,
  ) async {
    // Show loading dialog for Step 1
    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: Card(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Step 1/2: Sign cancel transaction...', 
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16)),
                ],
              ),
            ),
          ),
        ),
      );
    }

    try {
      final apiService = ApiService();
      final walletService = ref.read(walletServiceProvider);

      // Step 1: Cancel old listing
      final cancelResult = await apiService.prepareCancelListing(oldListing.listingId);
      if (cancelResult['success'] != true) {
        throw Exception('Failed to prepare cancel: ${cancelResult['error']}');
      }

      final cancelTxHash = await walletService.sendTransaction(
        to: cancelResult['contract_address'] as String,
        value: EtherAmount.zero(),
        data: cancelResult['function_data'] as String,
        gas: 200000,
      );

      // Update loading message - waiting for cancel confirmation
      if (mounted) {
        Navigator.pop(context); // Close previous dialog
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => Center(
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 16),
                    Text('Step 1/2: Waiting for confirmation...\n${cancelTxHash.substring(0, 10)}...', 
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 16)),
                  ],
                ),
              ),
            ),
          ),
        );
      }

      final cancelSuccess = await apiService.waitForTransaction(cancelTxHash);
      if (!cancelSuccess) {
        throw Exception('Cancel transaction failed');
      }

      // Step 2: Create new listing
      if (mounted) {
        Navigator.pop(context); // Close previous dialog
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const Center(
            child: Card(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Step 2/2: Sign new listing transaction...', 
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 16)),
                  ],
                ),
              ),
            ),
          ),
        );
      }

      final createResult = await apiService.prepareCreateListing(
        tokenId: oldListing.tokenId,
        sharesForSale: newShares,
        pricePerSharePol: newPrice,
      );

      if (createResult['success'] != true) {
        throw Exception('Failed to prepare new listing: ${createResult['error']}');
      }

      final createTxHash = await walletService.sendTransaction(
        to: createResult['contract_address'] as String,
        value: EtherAmount.zero(),
        data: createResult['function_data'] as String,
        gas: 500000,
      );

      // Update loading message - waiting for create confirmation
      if (mounted) {
        Navigator.pop(context); // Close previous dialog
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => Center(
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 16),
                    Text('Step 2/2: Waiting for confirmation...\n${createTxHash.substring(0, 10)}...', 
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 16)),
                  ],
                ),
              ),
            ),
          ),
        );
      }

      final createSuccess = await apiService.waitForTransaction(createTxHash);
      
      // Close loading dialog
      if (mounted) Navigator.pop(context);

      if (mounted) {
        if (createSuccess) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('✅ Listing updated!\nNew: $newShares shares @ $newPrice POL'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 5),
            ),
          );
          ref.invalidate(listingsProvider);
        } else {
          throw Exception('Create transaction failed');
        }
      }
    } catch (e) {
      // Close loading dialog if open
      if (mounted) Navigator.pop(context);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Failed to update listing: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }
  
  // ============================================
  // RENTAL FUNCTIONS
  // ============================================
  
  Future<void> _loadRentalListings() async {
    setState(() {
      _isLoadingRentals = true;
    });
    
    try {
      final listings = await _rentalService.getAllRentalListings();
      setState(() {
        _rentalListings = listings;
        _isLoadingRentals = false;
      });
    } catch (e) {
      print('Error loading rental listings: $e');
      setState(() {
        _isLoadingRentals = false;
      });
    }
  }

  Widget _buildRentplaceTab(ThemeData theme) {
    // Rentals are loaded automatically when tab is opened (see initState)
    
    return RefreshIndicator(
      onRefresh: _loadRentalListings,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with back button
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () {
                    _tabController.animateTo(0); // Go back to Home tab
                  },
                ),
                Text(
                  'Rent Properties',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            
            // Info Banner
            Container(
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.orange.withOpacity(0.1),
                    Colors.deepOrange.withOpacity(0.1),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(
                  color: Colors.orange.withOpacity(0.3),
                  width: 2,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: Colors.orange[700],
                    size: 40,
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Rental Marketplace',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Colors.orange[900],
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          'Browse and rent properties directly from NFT holders',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: Colors.orange[800],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            
            // Rental Listings Section
            if (_isLoadingRentals)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(AppSpacing.xl),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (_rentalListings.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  child: Column(
                    children: [
                      Icon(
                        Icons.home_outlined,
                        size: 80,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      Text(
                        'No Rentals Available',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        'Be the first to list your property for rent!',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: AppColors.grey,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              )
            else
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 0.75,
                  crossAxisSpacing: AppSpacing.md,
                  mainAxisSpacing: AppSpacing.md,
                ),
                itemCount: _rentalListings.length,
                itemBuilder: (context, index) {
                  final listing = _rentalListings[index];
                  return _buildRentalListingCard(listing, theme);
                },
              ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildRentalListingCard(RentalListing listing, ThemeData theme) {
    final imageUrl = listing.imageUrl ?? '';
    final propertyName = listing.propertyName ?? 'Property #${listing.tokenId}';
    
    // Check if this is user's listing
    final walletState = ref.watch(walletProvider);
    final userAddress = walletState.address?.toLowerCase() ?? '';
    final isMyListing = userAddress.isNotEmpty && listing.owner.toLowerCase() == userAddress;
    
    return Card(
      clipBehavior: Clip.antiAlias,
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: InkWell(
        onTap: () {
          // TODO: Navigate to rental detail screen
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Rental details coming soon!'),
              duration: Duration(seconds: 2),
            ),
          );
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Property Image
            AspectRatio(
              aspectRatio: 16 / 9,
              child: imageUrl.isNotEmpty
                  ? Image.network(
                      imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          color: Colors.grey[200],
                          child: const Icon(
                            Icons.home,
                            size: 48,
                            color: Colors.grey,
                          ),
                        );
                      },
                    )
                  : Container(
                      color: Colors.grey[200],
                      child: const Icon(
                        Icons.home,
                        size: 48,
                        color: Colors.grey,
                      ),
                    ),
            ),
            
            // Property Info
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.sm),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Property Name
                    Text(
                      propertyName,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    
                    // Price per night
                    Row(
                      children: [
                        Icon(
                          Icons.nights_stay,
                          size: 16,
                          color: Colors.orange[700],
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${double.tryParse(listing.pricePerNight)?.toStringAsFixed(4) ?? '0.0000'} POL/night',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: Colors.orange[700],
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    
                    // Location
                    if (listing.location != null && listing.location!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.location_on,
                            size: 14,
                            color: Colors.grey[600],
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              listing.location!,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: Colors.grey[700],
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                    
                    // Active Days
                    if (listing.activeDays != null && listing.activeDays!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.calendar_today,
                            size: 14,
                            color: Colors.grey[600],
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              listing.activeDays!,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: Colors.grey[700],
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                    
                    const Spacer(),
                    
                    // Buttons - different for owner vs renter
                    if (isMyListing)
                      // Owner buttons: Edit & Remove
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => _editRentalListing(listing),
                              icon: const Icon(Icons.edit, size: 14),
                              label: const Text('Edit', style: TextStyle(fontSize: 12)),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 8),
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () => _removeRentalListing(listing),
                              icon: const Icon(Icons.delete, size: 14),
                              label: const Text('Remove', style: TextStyle(fontSize: 12)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                                padding: const EdgeInsets.symmetric(vertical: 8),
                              ),
                            ),
                          ),
                        ],
                      )
                    else
                      // Renter button: Book Now
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () => _bookRental(listing),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange,
                            padding: const EdgeInsets.symmetric(vertical: 8),
                          ),
                          child: const Text(
                            'Book Now',
                            style: TextStyle(fontSize: 12),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================
  // RENTAL LISTING MANAGEMENT
  // ============================================
  
  Future<void> _editRentalListing(RentalListing listing) async {
    final priceController = TextEditingController(text: listing.pricePerNight);
    
    final result = await showDialog<double>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.edit, color: Colors.orange[700]),
            const SizedBox(width: 8),
            const Text('Edit Rental Price'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              listing.propertyName ?? 'Property #${listing.tokenId}',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text('Current price: ${double.tryParse(listing.pricePerNight)?.toStringAsFixed(4) ?? '0.0000'} POL/night'),
            const SizedBox(height: 16),
            TextField(
              controller: priceController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'New Price per Night',
                hintText: 'e.g. 0.5',
                prefixIcon: const Icon(Icons.attach_money),
                suffixText: 'POL',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
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
            onPressed: () {
              final priceText = priceController.text.trim();
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
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            child: const Text('Update'),
          ),
        ],
      ),
    );
    
    if (result != null && mounted) {
      await _processEditRentalListing(listing, result);
    }
  }
  
  Future<void> _processEditRentalListing(RentalListing listing, double newPrice) async {
    try {
      final walletService = ref.read(walletServiceProvider);
      final walletState = ref.read(walletProvider);
      final walletAddress = walletState.address;
      
      if (walletAddress == null) {
        throw Exception('Wallet not connected');
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Updating rental listing...'),
            duration: Duration(seconds: 2),
          ),
        );
      }
      
      // Step 1: Cancel old listing
      final cancelData = await _rentalService.prepareCancelRentalListing(listing.listingId);
      
      if (cancelData['success'] != true) {
        throw Exception(cancelData['error'] ?? 'Failed to prepare cancel');
      }
      
      final cancelTxHash = await walletService.sendTransaction(
        to: cancelData['contract_address'],
        value: EtherAmount.zero(),
        data: cancelData['function_data'].startsWith('0x') 
            ? cancelData['function_data'] 
            : '0x${cancelData['function_data']}',
        gas: 300000,
      );
      
      if (!mounted) return;
      
      // Wait a bit for transaction to be mined
      await Future.delayed(const Duration(seconds: 3));
      
      // Step 2: Create new listing with new price
      final createData = await _rentalService.prepareCreateRentalListing(
        tokenId: listing.tokenId,
        pricePerNightPol: newPrice,
        ownerAddress: walletAddress,
      );
      
      if (createData['success'] != true) {
        throw Exception(createData['error'] ?? 'Failed to prepare new listing');
      }
      
      final createTxHash = await walletService.sendTransaction(
        to: createData['contract_address'],
        value: EtherAmount.zero(),
        data: createData['function_data'].startsWith('0x') 
            ? createData['function_data'] 
            : '0x${createData['function_data']}',
        gas: 500000,
      );
      
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '✅ Rental listing updated!\n'
            'New price: $newPrice POL/night',
          ),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 5),
        ),
      );
      
      // Refresh listings
      await _loadRentalListings();
      
    } catch (e) {
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Failed to update listing: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }
  
  Future<void> _removeRentalListing(RentalListing listing) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning, color: Colors.red[700]),
            const SizedBox(width: 8),
            const Text('Remove Rental Listing'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Are you sure you want to remove this listing?',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(listing.propertyName ?? 'Property #${listing.tokenId}'),
            Text('Price: ${double.tryParse(listing.pricePerNight)?.toStringAsFixed(4) ?? '0.0000'} POL/night'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    
    if (confirmed == true && mounted) {
      await _processRemoveRentalListing(listing);
    }
  }
  
  Future<void> _processRemoveRentalListing(RentalListing listing) async {
    try {
      final walletService = ref.read(walletServiceProvider);
      final walletState = ref.read(walletProvider);
      final walletAddress = walletState.address;
      
      if (walletAddress == null) {
        throw Exception('Wallet not connected');
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Removing rental listing...'),
            duration: Duration(seconds: 2),
          ),
        );
      }
      
      final cancelData = await _rentalService.prepareCancelRentalListing(listing.listingId);
      
      if (cancelData['success'] != true) {
        throw Exception(cancelData['error'] ?? 'Failed to prepare cancel');
      }
      
      final txHash = await walletService.sendTransaction(
        to: cancelData['contract_address'],
        value: EtherAmount.zero(),
        data: cancelData['function_data'].startsWith('0x') 
            ? cancelData['function_data'] 
            : '0x${cancelData['function_data']}',
        gas: 300000,
      );
      
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ Rental listing removed!\nTX: ${txHash.substring(0, 10)}...'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 5),
        ),
      );
      
      // Refresh listings
      await _loadRentalListings();
      
    } catch (e) {
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Failed to remove listing: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  // Old _buildAllAssetsTab kept for reference but not used
  Widget _buildAllAssetsTabOld(ThemeData theme) {
    final assetListState = ref.watch(allAssetsProvider);

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(allAssetsProvider);
      },
      child: Builder(
        builder: (context) {
          if (assetListState.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (assetListState.error != null) {
            return SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error_outline, size: 64, color: AppColors.error),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      'Error loading assets',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: AppColors.error,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      assetListState.error!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.grey,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    ElevatedButton(
                      onPressed: () => ref.invalidate(assetListProvider(null)),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            );
          }

          final assets = assetListState.assets;

          if (assets.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.inventory_2_outlined, size: 64, color: AppColors.grey),
                  const SizedBox(height: AppSpacing.md),
                  Icon(
                    Icons.inventory_2_outlined,
                    size: 64,
                    color: AppColors.grey.withOpacity(0.5),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    'No Assets Yet',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'Create your first NFT asset on the blockchain',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: AppColors.grey,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  ElevatedButton.icon(
                    onPressed: () => context.push('/assets/create'),
                    icon: const Icon(Icons.add),
                    label: const Text('Create NFT Asset'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 16,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(AppSpacing.md),
            itemCount: assets.length,
            itemBuilder: (context, index) {
              final asset = assets[index];
              return Padding(
                padding: EdgeInsets.only(
                  bottom: index < assets.length - 1 ? AppSpacing.md : 0,
                ),
                child: AssetCard(
                  asset: asset,
                  onTap: () => context.go('/asset/${asset.id}'),
                ),
              );
            },
          );
        },
      ),
    );
  }
  
  // ============================================
  // RENTAL BOOKING
  // ============================================
  
  Future<void> _bookRental(RentalListing listing) async {
    try {
      // Show loading
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );
      
      // Fetch booked dates from backend
      final bookedTimestamps = await _rentalService.getBookedDates(listing.listingId);
      
      if (!mounted) return;
      Navigator.pop(context); // Close loading
      
      // Convert timestamps to DateTime (UTC, normalized to midnight)
      final bookedDates = bookedTimestamps.map((timestamp) {
        // Timestamp is already UTC midnight from smart contract
        final utcDate = DateTime.fromMillisecondsSinceEpoch(timestamp * 1000, isUtc: true);
        // Convert to local date for comparison (only date part, ignore time)
        return DateTime(utcDate.year, utcDate.month, utcDate.day);
      }).toList();
      
      // Show date picker with blocked dates
      final dateRange = await showDateRangePicker(
        context: context,
        firstDate: DateTime.now(),
        lastDate: DateTime.now().add(const Duration(days: 365)),
        builder: (context, child) {
          return Theme(
            data: Theme.of(context).copyWith(
              colorScheme: ColorScheme.light(
                primary: Colors.orange,
                onPrimary: Colors.white,
                surface: Colors.white,
                onSurface: Colors.black,
              ),
            ),
            child: child!,
          );
        },
        selectableDayPredicate: (DateTime date, DateTime? rangeStart, DateTime? rangeEnd) {
          // Check if this date is already booked
          for (var bookedDate in bookedDates) {
            if (date.year == bookedDate.year &&
                date.month == bookedDate.month &&
                date.day == bookedDate.day) {
              return false; // Date is booked, not selectable
            }
          }
          return true; // Date is available
        },
      );
      
      if (dateRange == null || !mounted) return;
      
      // Calculate nights and total price
      final checkIn = dateRange.start;
      final checkOut = dateRange.end;
      final nights = checkOut.difference(checkIn).inDays;
      
      if (nights <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please select at least one night'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
      
      final pricePerNight = double.tryParse(listing.pricePerNight) ?? 0.0;
      final totalPrice = pricePerNight * nights;
      
      // Show confirmation dialog
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Row(
            children: [
              Icon(Icons.calendar_month, color: Colors.orange[700]),
              const SizedBox(width: 8),
              const Text('Confirm Booking'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                listing.propertyName ?? 'Property #${listing.tokenId}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 16),
              _buildBookingRow('Check-in:', '${checkIn.day}/${checkIn.month}/${checkIn.year}'),
              const SizedBox(height: 8),
              _buildBookingRow('Check-out:', '${checkOut.day}/${checkOut.month}/${checkOut.year}'),
              const SizedBox(height: 8),
              _buildBookingRow('Nights:', '$nights'),
              const SizedBox(height: 8),
              _buildBookingRow('Price per night:', '${pricePerNight.toStringAsFixed(4)} POL'),
              const Divider(height: 24),
              _buildBookingRow(
                'Total Price:',
                '${totalPrice.toStringAsFixed(4)} POL',
                isTotal: true,
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
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
              ),
              child: const Text('Confirm & Pay'),
            ),
          ],
        ),
      );
      
      if (confirmed == true && mounted) {
        await _processRentalBooking(listing, checkIn, checkOut, totalPrice);
      }
      
    } catch (e) {
      if (!mounted) return;
      
      // Close any open dialogs
      Navigator.of(context).popUntil((route) => route.isFirst);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Error: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }
  
  Widget _buildBookingRow(String label, String value, {bool isTotal = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
            fontSize: isTotal ? 16 : 14,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontWeight: isTotal ? FontWeight.bold : FontWeight.w600,
            fontSize: isTotal ? 16 : 14,
            color: isTotal ? Colors.orange[700] : Colors.black87,
          ),
        ),
      ],
    );
  }
  
  Future<void> _processRentalBooking(
    RentalListing listing,
    DateTime checkIn,
    DateTime checkOut,
    double totalPrice,
  ) async {
    try {
      final walletService = ref.read(walletServiceProvider);
      final walletState = ref.read(walletProvider);
      final walletAddress = walletState.address;
      
      if (walletAddress == null) {
        throw Exception('Wallet not connected');
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Preparing booking transaction...'),
            duration: Duration(seconds: 2),
          ),
        );
      }
      
      // Convert DateTime to Unix timestamp (UTC midnight)
      // Normalize to midnight UTC to match smart contract's date handling
      final checkInUtc = DateTime.utc(checkIn.year, checkIn.month, checkIn.day);
      final checkOutUtc = DateTime.utc(checkOut.year, checkOut.month, checkOut.day);
      final checkInTimestamp = checkInUtc.millisecondsSinceEpoch ~/ 1000;
      final checkOutTimestamp = checkOutUtc.millisecondsSinceEpoch ~/ 1000;
      
      // Prepare transaction from backend
      final txData = await _rentalService.prepareRentAsset(
        listingId: listing.listingId,
        checkInDate: checkInTimestamp,
        checkOutDate: checkOutTimestamp,
        renterAddress: walletAddress,
      );
      
      if (txData['success'] != true) {
        throw Exception(txData['error'] ?? 'Failed to prepare booking');
      }
      
      // Send transaction with payment
      final txHash = await walletService.sendTransaction(
        to: txData['contract_address'],
        value: EtherAmount.fromBigInt(EtherUnit.wei, BigInt.parse(txData['value_wei'])),
        data: txData['function_data'].startsWith('0x') 
            ? txData['function_data'] 
            : '0x${txData['function_data']}',
        gas: 800000, // Higher gas for complex rental transaction
      );
      
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '✅ Booking confirmed!\n'
            'TX: ${txHash.substring(0, 10)}...',
          ),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 5),
        ),
      );
      
      // Refresh listings
      await _loadRentalListings();
      
    } catch (e) {
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Failed to book rental: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }
}

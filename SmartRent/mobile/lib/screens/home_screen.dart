import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:web3dart/web3dart.dart';

import '../constants/config.dart';
import '../services/models.dart';
import '../services/api_service.dart';
import '../services/wallet_service.dart';
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

class _HomeScreenState extends ConsumerState<HomeScreen> with SingleTickerProviderStateMixin {
  final _searchController = TextEditingController();
  String _selectedCategory = '';
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
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
          // Marketplace Tab (Coming Soon)
          _buildMarketplaceTab(theme),
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

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(listingsProvider);
      },
      child: listingsState.isLoading
          ? const Center(child: CircularProgressIndicator())
          : listingsState.error != null
              ? _buildMarketplaceError(theme, listingsState.error!)
              : listingsState.listings.isEmpty
                  ? _buildEmptyMarketplace(theme)
                  : _buildListingsGrid(theme, listingsState.listings),
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
                      ElevatedButton(
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
    
    // Step 3: Show success
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Purchase successful! TX: ${txHash.substring(0, 10)}...'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 5),
        ),
      );
      
      // Refresh listings
      ref.invalidate(listingsProvider);
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
}

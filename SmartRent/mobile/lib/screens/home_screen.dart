import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart' as provider;

import '../constants/config.dart';
import '../services/models.dart';
import '../services/api_service.dart';
import '../components/asset_card.dart';
import '../components/wallet_info_widget.dart';
import '../core/providers/auth_provider.dart';
import '../providers/wallet_provider.dart';

/// Provider for featured assets
final featuredAssetsProvider = FutureProvider<List<Asset>>((ref) async {
  final apiService = ApiService();
  await apiService.initialize();
  return await apiService.getAssets(limit: 10, availableOnly: true);
});

/// Provider for asset categories
final categoriesProvider = FutureProvider<List<String>>((ref) async {
  final apiService = ApiService();
  await apiService.initialize();
  return await apiService.getAssetCategories();
});

/// Provider for all assets
final allAssetsProvider = FutureProvider<List<Asset>>((ref) async {
  final apiService = ApiService();
  await apiService.initialize();
  return await apiService.getAssets(limit: 100, availableOnly: true);
});

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
    final featuredAssets = ref.watch(featuredAssetsProvider);
    final categories = ref.watch(categoriesProvider);

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
              icon: Icon(Icons.list_outlined),
              text: 'All Assets',
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () {
              // TODO: Show notifications
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Notifications coming soon!')),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.account_balance_wallet_outlined),
            onPressed: () {
              context.go('/wallet-connection');
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
                    content: const Text('Are you sure you want to logout?'),
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
                        child: const Text('Logout'),
                      ),
                    ],
                  ),
                );

                if (confirm == true && mounted) {
                  await ref.read(authStateProvider.notifier).logout();
                  if (mounted) {
                    context.go('/auth/login');
                  }
                }
              } else if (value == 'settings') {
                context.go('/settings');
              } else if (value == 'nft-portfolio') {
                final walletProvider = provider.Provider.of<WalletProvider>(context, listen: false);
                final wallet = walletProvider.walletAddress ?? '';
                context.go('/nft-portfolio?wallet=$wallet');
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
                    Text('Logout', style: TextStyle(color: Colors.red)),
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
              ref.invalidate(featuredAssetsProvider);
              ref.invalidate(categoriesProvider);
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
                  _buildQuickStats(theme),
                  const SizedBox(height: AppSpacing.lg),

                  // Categories
                  _buildCategoriesSection(categories, theme),
                  const SizedBox(height: AppSpacing.lg),

                  // Featured Assets
                  _buildFeaturedAssetsSection(featuredAssets, theme),
                  const SizedBox(height: AppSpacing.lg),

                  // Quick Actions
                  _buildQuickActions(theme),
                ],
              ),
            ),
          ),
          // All Assets Tab
          _buildAllAssetsTab(theme),
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
          // TODO: Implement search
          if (value.isNotEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Searching for "$value"...')),
            );
          }
        },
      ),
    );
  }

  Widget _buildQuickStats(ThemeData theme) {
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            theme,
            'Available Assets',
            '150+',
            Icons.inventory_2_outlined,
            AppColors.primary,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: _buildStatCard(
            theme,
            'Active Rentals',
            '23',
            Icons.handshake_outlined,
            AppColors.success,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: _buildStatCard(
            theme,
            'Happy Users',
            '500+',
            Icons.people_outline,
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

  Widget _buildCategoriesSection(
    AsyncValue<List<String>> categories,
    ThemeData theme,
  ) {
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
        categories.when(
          data: (data) => SizedBox(
            height: 100,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: data.length,
              itemBuilder: (context, index) {
                final category = data[index];
                final isSelected = _selectedCategory == category;
                
                return Padding(
                  padding: EdgeInsets.only(
                    right: index < data.length - 1 ? AppSpacing.sm : 0,
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
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stack) => Text('Error loading categories: $error'),
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

  Widget _buildFeaturedAssetsSection(
    AsyncValue<List<Asset>> featuredAssets,
    ThemeData theme,
  ) {
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
                // Switch to All Assets tab
                _tabController.animateTo(1);
              },
              child: const Text('See All'),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        featuredAssets.when(
          data: (assets) => assets.isEmpty
              ? const Center(
                  child: Text('No assets available at the moment'),
                )
              : SizedBox(
                  height: 320,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: assets.length,
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
                ),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stack) => Center(
            child: Column(
              children: [
                Text('Error loading assets: $error'),
                ElevatedButton(
                  onPressed: () => ref.invalidate(featuredAssetsProvider),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
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
                'List Asset',
                Icons.add_circle_outline,
                AppColors.primary,
                () {
                  // Navigate to create asset screen
                  context.push('/assets/create');
                },
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
                () {
                  context.go('/nft-gallery');
                },
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
                  final walletProvider = provider.Provider.of<WalletProvider>(context, listen: false);
                  final wallet = walletProvider.walletAddress ?? '';
                  context.go('/nft-portfolio?wallet=$wallet');
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

  Widget _buildAllAssetsTab(ThemeData theme) {
    final allAssets = ref.watch(allAssetsProvider);

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(allAssetsProvider);
      },
      child: allAssets.when(
        data: (assets) {
          if (assets.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.inventory_2_outlined,
                    size: 64,
                    color: AppColors.grey,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    'No assets available',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: AppColors.grey,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Check back later for new listings',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.grey,
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
        loading: () => const Center(
          child: CircularProgressIndicator(),
        ),
        error: (error, stack) => SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.error_outline,
                  size: 64,
                  color: AppColors.error,
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  'Error loading assets',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: AppColors.error,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  error.toString(),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.grey,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 5,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: AppSpacing.md),
                ElevatedButton(
                  onPressed: () => ref.invalidate(allAssetsProvider),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}










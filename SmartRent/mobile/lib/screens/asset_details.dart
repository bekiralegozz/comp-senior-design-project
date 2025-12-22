import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../constants/config.dart';
import '../services/models.dart';
import '../core/providers/asset_provider.dart';

/// ==========================================================
/// ASSET DETAILS SCREEN - BLOCKCHAIN MIGRATION VERSION
/// ==========================================================
///
/// Displays asset details from blockchain via NFT service.
/// Uses assetDetailProvider which fetches from smart contracts.

class AssetDetailsScreen extends ConsumerWidget {
  final String assetId;

  const AssetDetailsScreen({Key? key, required this.assetId}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    
    // Try to parse assetId as tokenId (int)
    final tokenId = int.tryParse(assetId);
    
    if (tokenId == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Asset Details')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 64, color: AppColors.error),
              const SizedBox(height: AppSpacing.md),
              Text('Invalid asset ID: $assetId'),
            ],
          ),
        ),
      );
    }
    
    final assetState = ref.watch(assetDetailProvider(tokenId));

    return Scaffold(
      body: Builder(
        builder: (context) {
          if (assetState.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          
          if (assetState.error != null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 64, color: AppColors.error),
                  const SizedBox(height: AppSpacing.md),
                  Text('Failed to load asset details'),
                  const SizedBox(height: AppSpacing.sm),
                  Text(assetState.error!, style: TextStyle(color: AppColors.grey)),
                  const SizedBox(height: AppSpacing.md),
                  ElevatedButton(
                    onPressed: () => ref.invalidate(assetDetailProvider(tokenId)),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }
          
          if (assetState.asset != null) {
            return _buildAssetDetails(context, theme, assetState.asset!);
          }
          
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.inventory_2_outlined, size: 64, color: AppColors.grey),
                const SizedBox(height: AppSpacing.md),
                Text('Asset not found on blockchain'),
              ],
            ),
          );
        },
      ),
      bottomNavigationBar: assetState.asset != null
          ? _BottomRentBar(asset: assetState.asset!)
          : null,
    );
  }

  Widget _buildAssetDetails(BuildContext context, ThemeData theme, Asset asset) {
    return CustomScrollView(
      slivers: [
        // App Bar with Image
        SliverAppBar(
          expandedHeight: 300,
          pinned: true,
          flexibleSpace: FlexibleSpaceBar(
            background: asset.imageUrl != null && asset.imageUrl!.isNotEmpty
                ? CachedNetworkImage(
                    imageUrl: asset.imageUrl!,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppColors.categoryColors[asset.category]?.withOpacity(0.8) ?? 
                            AppColors.primary.withOpacity(0.8),
                            AppColors.categoryColors[asset.category]?.withOpacity(0.4) ?? 
                            AppColors.primary.withOpacity(0.4),
                          ],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                      ),
                      child: const Center(
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white70),
                        ),
                      ),
                    ),
                    errorWidget: (context, url, error) => Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppColors.categoryColors[asset.category]?.withOpacity(0.8) ?? 
                            AppColors.primary.withOpacity(0.8),
                            AppColors.categoryColors[asset.category]?.withOpacity(0.4) ?? 
                            AppColors.primary.withOpacity(0.4),
                          ],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                      ),
                      child: const Center(
                        child: Icon(Icons.image_not_supported, size: 80, color: Colors.white70),
                      ),
                    ),
                  )
                : Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppColors.categoryColors[asset.category]?.withOpacity(0.8) ?? 
                          AppColors.primary.withOpacity(0.8),
                          AppColors.categoryColors[asset.category]?.withOpacity(0.4) ?? 
                          AppColors.primary.withOpacity(0.4),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                    child: const Center(
                      child: Icon(Icons.image, size: 80, color: Colors.white),
                    ),
                  ),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.share),
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Share feature coming soon!')),
                );
              },
            ),
            IconButton(
              icon: const Icon(Icons.favorite_border),
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Favorites feature coming soon!')),
                );
              },
            ),
          ],
        ),
        
        // Asset Details Content
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title and Price
                _buildTitleSection(theme, asset),
                const SizedBox(height: AppSpacing.lg),
                
                // Blockchain Badge
                if (asset.isTokenized)
                  _buildBlockchainBadge(theme, asset),
                
                const SizedBox(height: AppSpacing.lg),
                
                // Asset Details
                _buildDetailsSection(theme, asset),
                const SizedBox(height: AppSpacing.lg),
                
                // Description
                if (asset.description != null && asset.description!.isNotEmpty)
                  _buildDescriptionSection(theme, asset),
                
                // Availability Status
                _buildAvailabilitySection(theme, asset),
                
                const SizedBox(height: AppSpacing.xxl),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTitleSection(ThemeData theme, Asset asset) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                asset.title ?? 'Unnamed Asset',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: AppSpacing.xs,
              ),
              decoration: BoxDecoration(
                color: (AppColors.categoryColors[asset.category ?? 'other'] ?? AppColors.primary)
                    .withOpacity(0.1),
                borderRadius: BorderRadius.circular(AppRadius.sm),
                border: Border.all(
                  color: AppColors.categoryColors[asset.category ?? 'other'] ?? AppColors.primary,
                ),
              ),
              child: Text(
                AssetCategories.getDisplayName(asset.category ?? 'other'),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColors.categoryColors[asset.category ?? 'other'] ?? AppColors.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              '${asset.pricePerDay ?? 0} ${asset.currency ?? 'MATIC'}',
              style: theme.textTheme.headlineMedium?.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            Text(
              'per day',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppColors.grey,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildBlockchainBadge(ThemeData theme, Asset asset) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.secondary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.secondary),
      ),
      child: Row(
        children: [
          Icon(Icons.token, color: AppColors.secondary),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'NFT Asset on Polygon',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.secondary,
                  ),
                ),
                Text(
                  'Token ID: #${asset.tokenId}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.grey,
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.verified, color: AppColors.success),
        ],
      ),
    );
  }

  Widget _buildDetailsSection(ThemeData theme, Asset asset) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Asset Details',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        _buildDetailRow(theme, 'Asset ID', '#${asset.id}'),
        _buildDetailRow(theme, 'Category', AssetCategories.getDisplayName(asset.category ?? 'other')),
        _buildDetailRow(theme, 'Currency', asset.currency ?? 'MATIC'),
        if (asset.tokenId != null)
          _buildDetailRow(theme, 'NFT Token ID', '#${asset.tokenId}'),
        if (asset.contractAddress != null)
          _buildDetailRow(theme, 'Contract', '${asset.contractAddress!.substring(0, 10)}...'),
        _buildDetailRow(
          theme, 
          'Listed on', 
          DateFormat('MMM dd, yyyy').format(asset.createdAt ?? DateTime.now()),
        ),
      ],
    );
  }

  Widget _buildDetailRow(ThemeData theme, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppColors.grey,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(value, style: theme.textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }

  Widget _buildDescriptionSection(ThemeData theme, Asset asset) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Description',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Text(asset.description!, style: theme.textTheme.bodyMedium),
        const SizedBox(height: AppSpacing.lg),
      ],
    );
  }

  Widget _buildAvailabilitySection(ThemeData theme, Asset asset) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: (asset.isAvailable ?? false)
            ? AppColors.success.withOpacity(0.1)
            : AppColors.warning.withOpacity(0.1),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
          color: (asset.isAvailable ?? false) ? AppColors.success : AppColors.warning,
        ),
      ),
      child: Row(
        children: [
          Icon(
            (asset.isAvailable ?? false) ? Icons.check_circle : Icons.schedule,
            color: (asset.isAvailable ?? false) ? AppColors.success : AppColors.warning,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  (asset.isAvailable ?? false) ? 'Available for Rent' : 'Currently Unavailable',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: (asset.isAvailable ?? false) ? AppColors.success : AppColors.warning,
                  ),
                ),
                Text(
                  (asset.isAvailable ?? false)
                      ? 'This asset is ready to be rented'
                      : 'This asset is currently being rented or unavailable',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.grey,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Fixed bottom bar with rent button
class _BottomRentBar extends StatelessWidget {
  final Asset asset;

  const _BottomRentBar({required this.asset});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${asset.pricePerDay ?? 0} ${asset.currency ?? 'MATIC'}/day',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                  Text(
                    'Plus gas fees',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.grey,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            ElevatedButton(
              onPressed: (asset.isAvailable ?? false)
                  ? () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Blockchain rental coming soon!'),
                        ),
                      );
                    }
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                  vertical: AppSpacing.md,
                ),
              ),
              child: const Text('Rent'),
            ),
          ],
        ),
      ),
    );
  }
}


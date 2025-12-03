import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../constants/config.dart';
import '../services/models.dart';
import '../services/api_service.dart';

/// Provider for asset details
final assetDetailsProvider = FutureProvider.family<Asset, String>((ref, assetId) async {
  final apiService = ApiService();
  await apiService.initialize();
  return await apiService.getAsset(assetId);
});

class AssetDetailsScreen extends ConsumerWidget {
  final String assetId;

  const AssetDetailsScreen({Key? key, required this.assetId}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final assetDetails = ref.watch(assetDetailsProvider(assetId));

    return Scaffold(
      body: assetDetails.when(
        data: (asset) => _buildAssetDetails(context, theme, asset),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: 64,
                color: AppColors.error,
              ),
              const SizedBox(height: AppSpacing.md),
              Text('Failed to load asset details'),
              const SizedBox(height: AppSpacing.sm),
              ElevatedButton(
                onPressed: () => ref.invalidate(assetDetailsProvider(assetId)),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
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
                        child: Icon(
                          Icons.image_not_supported,
                          size: 80,
                          color: Colors.white70,
                        ),
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
                      child: Icon(
                        Icons.image,
                        size: 80,
                        color: Colors.white,
                      ),
                    ),
                  ),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.share),
              onPressed: () {
                // TODO: Implement sharing
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Share feature coming soon!')),
                );
              },
            ),
            IconButton(
              icon: const Icon(Icons.favorite_border),
              onPressed: () {
                // TODO: Implement favorites
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
                
                // Owner Info
                _buildOwnerSection(context, theme, asset),
                const SizedBox(height: AppSpacing.lg),
                
                // Asset Details
                _buildDetailsSection(theme, asset),
                const SizedBox(height: AppSpacing.lg),
                
                // Description
                if (asset.description != null && asset.description!.isNotEmpty)
                  _buildDescriptionSection(theme, asset),
                
                // Location
                if (asset.location != null && asset.location!.isNotEmpty)
                  _buildLocationSection(theme, asset),
                
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
                asset.title,
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
                color: (AppColors.categoryColors[asset.category] ?? AppColors.primary)
                    .withOpacity(0.1),
                borderRadius: BorderRadius.circular(AppRadius.sm),
                border: Border.all(
                  color: AppColors.categoryColors[asset.category] ?? AppColors.primary,
                ),
              ),
              child: Text(
                AssetCategories.getDisplayName(asset.category),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColors.categoryColors[asset.category] ?? AppColors.primary,
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
              '${asset.pricePerDay} ${asset.currency == "USD" ? "token" : asset.currency}',
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

  Widget _buildOwnerSection(BuildContext context, ThemeData theme, Asset asset) {
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
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: AppColors.primary.withOpacity(0.1),
            child: Text(
              (asset.owner?.fullName ?? asset.owner?.username ?? 'U')[0].toUpperCase(),
              style: theme.textTheme.titleMedium?.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Owned by',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.grey,
                  ),
                ),
                Text(
                  asset.owner?.fullName ?? asset.owner?.username ?? 'Anonymous',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (asset.owner?.isVerified == true)
                  Row(
                    children: [
                      Icon(
                        Icons.verified,
                        size: 16,
                        color: AppColors.success,
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Text(
                        'Verified Owner',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.success,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.message_outlined),
            onPressed: () {
              // TODO: Implement messaging
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Messaging coming soon!')),
              );
            },
          ),
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
        _buildDetailRow(theme, 'Category', AssetCategories.getDisplayName(asset.category)),
        _buildDetailRow(theme, 'Currency', asset.currency == "USD" ? "token" : asset.currency),
        if (asset.tokenId != null)
          _buildDetailRow(theme, 'NFT Token ID', '#${asset.tokenId}'),
        if (asset.iotDeviceId != null)
          _buildDetailRow(theme, 'IoT Device', asset.iotDeviceId!),
        _buildDetailRow(
          theme, 
          'Listed on', 
          DateFormat('MMM dd, yyyy').format(asset.createdAt),
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
            child: Text(
              value,
              style: theme.textTheme.bodyMedium,
            ),
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
        Text(
          asset.description!,
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: AppSpacing.lg),
      ],
    );
  }

  Widget _buildLocationSection(ThemeData theme, Asset asset) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Location',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          children: [
            Icon(
              Icons.location_on_outlined,
              color: AppColors.primary,
              size: 20,
            ),
            const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: Text(
                asset.location!,
                style: theme.textTheme.bodyMedium,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
      ],
    );
  }

  Widget _buildAvailabilitySection(ThemeData theme, Asset asset) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: asset.isAvailable 
            ? AppColors.success.withOpacity(0.1)
            : AppColors.warning.withOpacity(0.1),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
          color: asset.isAvailable ? AppColors.success : AppColors.warning,
        ),
      ),
      child: Row(
        children: [
          Icon(
            asset.isAvailable ? Icons.check_circle : Icons.schedule,
            color: asset.isAvailable ? AppColors.success : AppColors.warning,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  asset.isAvailable ? 'Available for Rent' : 'Currently Unavailable',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: asset.isAvailable ? AppColors.success : AppColors.warning,
                  ),
                ),
                Text(
                  asset.isAvailable 
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
                    '${asset.pricePerDay} ${asset.currency == "USD" ? "token" : asset.currency}/day',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                  Text(
                    'Plus applicable fees',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.grey,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            ElevatedButton(
              onPressed: asset.isAvailable
                  ? () {
                      // TODO: Navigate to rental creation
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Rental booking coming soon!')),
                      );
                    }
                  : null,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                  vertical: AppSpacing.md,
                ),
              ),
              child: const Text('Rent Now'),
            ),
          ],
        ),
      ),
    );
  }
}










import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../constants/config.dart';
import '../services/models.dart';

class AssetCard extends StatelessWidget {
  final Asset asset;
  final VoidCallback? onTap;
  final bool showOwner;
  final bool compact;

  const AssetCard({
    Key? key,
    required this.asset,
    this.onTap,
    this.showOwner = true,
    this.compact = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(AppRadius.md),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Asset Image
            _buildAssetImage(theme),
            
            // Asset Details
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title and Category
                  _buildTitleSection(theme),
                  
                  const SizedBox(height: AppSpacing.sm),
                  
                  // Price
                  _buildPriceSection(theme),
                  
                  if (!compact) ...[
                    const SizedBox(height: AppSpacing.sm),
                    
                    // Location
                    if (asset.location != null && asset.location!.isNotEmpty)
                      _buildLocationSection(theme),
                    
                    // Owner (if enabled)
                    if (showOwner && asset.owner != null)
                      _buildOwnerSection(theme),
                  ],
                  
                  const SizedBox(height: AppSpacing.sm),
                  
                  // Status and Actions
                  _buildStatusSection(theme),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAssetImage(ThemeData theme) {
    final categoryColor = AppColors.categoryColors[asset.category] ?? AppColors.primary;
    
    return Container(
      height: compact ? 120 : 160,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            categoryColor.withOpacity(0.8),
            categoryColor.withOpacity(0.4),
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(AppRadius.md),
          topRight: Radius.circular(AppRadius.md),
        ),
      ),
      child: Stack(
        children: [
          // Placeholder for actual image
          const Center(
            child: Icon(
              Icons.image,
              size: 48,
              color: Colors.white,
            ),
          ),
          
          // Availability badge
          Positioned(
            top: AppSpacing.sm,
            right: AppSpacing.sm,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: AppSpacing.xs,
              ),
              decoration: BoxDecoration(
                color: asset.isAvailable 
                    ? AppColors.success 
                    : AppColors.warning,
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: Text(
                asset.isAvailable ? 'Available' : 'Rented',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          
          // Category badge
          Positioned(
            top: AppSpacing.sm,
            left: AppSpacing.sm,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: AppSpacing.xs,
              ),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.6),
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    AssetCategories.icons[asset.category] ?? Icons.category,
                    size: 14,
                    color: Colors.white,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Text(
                    AssetCategories.getDisplayName(asset.category),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTitleSection(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          asset.title,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        if (asset.description != null && asset.description!.isNotEmpty && !compact)
          Text(
            asset.description!,
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppColors.grey,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
      ],
    );
  }

  Widget _buildPriceSection(ThemeData theme) {
    return Row(
      children: [
        Text(
          '${asset.pricePerDay}',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(width: AppSpacing.xs),
        Text(
          '${asset.currency}/day',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: AppColors.grey,
          ),
        ),
        const Spacer(),
        if (asset.tokenId != null)
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.xs,
              vertical: 2,
            ),
            decoration: BoxDecoration(
              color: AppColors.secondary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(AppRadius.xs),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.token,
                  size: 12,
                  color: AppColors.secondary,
                ),
                const SizedBox(width: 2),
                Text(
                  'NFT',
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontSize: 10,
                    color: AppColors.secondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildLocationSection(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Row(
        children: [
          Icon(
            Icons.location_on_outlined,
            size: 16,
            color: AppColors.grey,
          ),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Text(
              asset.location!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.grey,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOwnerSection(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Row(
        children: [
          CircleAvatar(
            radius: 10,
            backgroundColor: AppColors.primary.withOpacity(0.1),
            child: Text(
              (asset.owner!.fullName ?? asset.owner!.username)[0].toUpperCase(),
              style: theme.textTheme.bodySmall?.copyWith(
                fontSize: 10,
                color: AppColors.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Text(
              asset.owner!.fullName ?? asset.owner!.username,
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.grey,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (asset.owner!.isVerified)
            Icon(
              Icons.verified,
              size: 14,
              color: AppColors.success,
            ),
        ],
      ),
    );
  }

  Widget _buildStatusSection(ThemeData theme) {
    return Row(
      children: [
        // IoT indicator
        if (asset.iotDeviceId != null)
          Container(
            margin: const EdgeInsets.only(right: AppSpacing.xs),
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.xs,
              vertical: 2,
            ),
            decoration: BoxDecoration(
              color: AppColors.info.withOpacity(0.1),
              borderRadius: BorderRadius.circular(AppRadius.xs),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.sensors,
                  size: 12,
                  color: AppColors.info,
                ),
                const SizedBox(width: 2),
                Text(
                  'IoT',
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontSize: 10,
                    color: AppColors.info,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        
        const Spacer(),
        
        // Quick action button
        if (asset.isAvailable)
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: AppSpacing.xs,
            ),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Text(
              'Rent',
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
      ],
    );
  }
}









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
          mainAxisSize: MainAxisSize.min,
          children: [
            // Asset Image
            _buildAssetImage(theme),
            
            // Asset Details
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: AppSpacing.xs,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Title and Category
                  _buildTitleSection(theme),
                  
                  const SizedBox(height: 4),
                  
                  // Price
                  _buildPriceSection(theme),
                  
                  if (!compact) ...[
                    const SizedBox(height: 4),
                    
                    // Location
                    if (asset.locationString.isNotEmpty && asset.locationString != 'Unknown')
                      _buildLocationSection(theme),
                    
                    // Owner (if enabled)
                    if (showOwner && asset.owner != null)
                      _buildOwnerSection(theme),
                  ],
                  
                  const SizedBox(height: 4),
                  
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
      height: compact ? 100 : 140,
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

          // Actual image or placeholder
          if (asset.imageUrl != null && asset.imageUrl!.isNotEmpty)
            ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(AppRadius.md),
                topRight: Radius.circular(AppRadius.md),
              ),
              child: CachedNetworkImage(
                imageUrl: asset.imageUrl!,
                width: double.infinity,
                height: double.infinity,
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(
                  color: categoryColor.withOpacity(0.3),
                  child: const Center(
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white70),
                    ),
                  ),
                ),
                errorWidget: (context, url, error) => Container(
                  color: categoryColor.withOpacity(0.3),
                  child: const Center(
                    child: Icon(
                      Icons.image_not_supported,
                      size: 48,
                      color: Colors.white70,
                    ),
                  ),
                ),
              ),
            )
          else
            // Placeholder when no image
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
                color: (asset.isAvailable ?? false)
                    ? AppColors.success 
                    : AppColors.warning,
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: Text(
                (asset.isAvailable ?? false) ? 'Available' : 'Rented',
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
                    AssetCategories.icons[asset.category ?? 'other'] ?? Icons.category,
                    size: 14,
                    color: Colors.white,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Text(
                    AssetCategories.getDisplayName(asset.category ?? 'other'),
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
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          asset.title ?? 'Unnamed Asset',
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
          '${asset.currency == "USD" ? "token" : asset.currency}/day',
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
      padding: const EdgeInsets.only(bottom: 2),
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
              asset.locationString,
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
      padding: const EdgeInsets.only(bottom: 2),
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
        
        // Quick action button - Red Rent button
        if (asset.isAvailable ?? false)
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: AppSpacing.xs,
            ),
            decoration: BoxDecoration(
              color: Colors.red,
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Text(
              'Rent',
              style: theme.textTheme.bodySmall?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
      ],
    );
  }
}










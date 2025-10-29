import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../constants/config.dart';
import '../services/models.dart';

class RentalCard extends StatelessWidget {
  final Rental rental;
  final VoidCallback? onTap;
  final bool compact;

  const RentalCard({
    Key? key,
    required this.rental,
    this.onTap,
    this.compact = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return GestureDetector(
      onTap: onTap,
      child: Container(
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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with status and ID
            _buildHeader(theme),
            
            const SizedBox(height: AppSpacing.md),
            
            // Asset information
            if (rental.asset != null) _buildAssetInfo(theme),
            
            // Rental details
            _buildRentalDetails(theme),
            
            if (!compact) ...[
              const SizedBox(height: AppSpacing.sm),
              
              // Timeline or actions
              _buildBottomSection(theme),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(ThemeData theme) {
    final statusColor = RentalStatus.colors[rental.status] ?? AppColors.grey;
    final statusIcon = RentalStatus.icons[rental.status] ?? Icons.help_outline;
    
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(AppSpacing.xs),
          decoration: BoxDecoration(
            color: statusColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
          child: Icon(
            statusIcon,
            size: 20,
            color: statusColor,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Rental #${rental.id}',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                RentalStatus.getDisplayName(rental.status),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: statusColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        Text(
          '${rental.totalPrice} ${rental.currency}',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: AppColors.primary,
          ),
        ),
      ],
    );
  }

  Widget _buildAssetInfo(ThemeData theme) {
    final asset = rental.asset!;
    
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: (AppColors.categoryColors[asset.category] ?? AppColors.primary)
                  .withOpacity(0.1),
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Icon(
              AssetCategories.icons[asset.category] ?? Icons.category,
              color: AppColors.categoryColors[asset.category] ?? AppColors.primary,
              size: 24,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  asset.title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  AssetCategories.getDisplayName(asset.category),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.grey,
                  ),
                ),
                if (asset.location != null && asset.location!.isNotEmpty)
                  Row(
                    children: [
                      Icon(
                        Icons.location_on_outlined,
                        size: 12,
                        color: AppColors.grey,
                      ),
                      const SizedBox(width: 2),
                      Expanded(
                        child: Text(
                          asset.location!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AppColors.grey,
                            fontSize: 11,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          Icon(
            Icons.arrow_forward_ios,
            size: 14,
            color: AppColors.grey,
          ),
        ],
      ),
    );
  }

  Widget _buildRentalDetails(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.md),
      child: Row(
        children: [
          Expanded(
            child: _buildDetailColumn(
              theme,
              'Start Date',
              DateFormat('MMM dd').format(rental.startDate),
              Icons.play_circle_outline,
            ),
          ),
          Expanded(
            child: _buildDetailColumn(
              theme,
              'End Date',
              DateFormat('MMM dd').format(rental.endDate),
              Icons.stop_circle_outlined,
            ),
          ),
          Expanded(
            child: _buildDetailColumn(
              theme,
              'Duration',
              '${rental.endDate.difference(rental.startDate).inDays} days',
              Icons.schedule_outlined,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailColumn(
    ThemeData theme,
    String label,
    String value,
    IconData icon,
  ) {
    return Column(
      children: [
        Icon(
          icon,
          size: 20,
          color: AppColors.grey,
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: AppColors.grey,
          ),
          textAlign: TextAlign.center,
        ),
        Text(
          value,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildBottomSection(ThemeData theme) {
    return Row(
      children: [
        // Progress indicator based on dates
        Expanded(child: _buildProgressIndicator(theme)),
        
        const SizedBox(width: AppSpacing.md),
        
        // Quick action button
        _buildActionButton(theme),
      ],
    );
  }

  Widget _buildProgressIndicator(ThemeData theme) {
    final now = DateTime.now();
    final startTime = rental.startDate;
    final endTime = rental.endDate;
    
    double progress = 0.0;
    String progressText = 'Not started';
    Color progressColor = AppColors.grey;
    
    if (now.isBefore(startTime)) {
      // Before start
      final totalWait = startTime.difference(rental.createdAt);
      final elapsed = now.difference(rental.createdAt);
      progress = elapsed.inMilliseconds / totalWait.inMilliseconds;
      progressText = 'Starting soon';
      progressColor = AppColors.warning;
    } else if (now.isAfter(startTime) && now.isBefore(endTime)) {
      // During rental
      final totalDuration = endTime.difference(startTime);
      final elapsed = now.difference(startTime);
      progress = elapsed.inMilliseconds / totalDuration.inMilliseconds;
      progressText = 'In progress';
      progressColor = AppColors.primary;
    } else if (now.isAfter(endTime)) {
      // After end
      progress = 1.0;
      progressText = 'Completed';
      progressColor = rental.status == 'completed' ? AppColors.success : AppColors.warning;
    }
    
    // Clamp progress between 0 and 1
    progress = progress.clamp(0.0, 1.0);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              progressText,
              style: theme.textTheme.bodySmall?.copyWith(
                color: progressColor,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              '${(progress * 100).toInt()}%',
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.grey,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        LinearProgressIndicator(
          value: progress,
          backgroundColor: progressColor.withOpacity(0.2),
          valueColor: AlwaysStoppedAnimation<Color>(progressColor),
          minHeight: 4,
        ),
      ],
    );
  }

  Widget _buildActionButton(ThemeData theme) {
    String buttonText = 'View';
    IconData buttonIcon = Icons.visibility_outlined;
    VoidCallback? buttonAction = onTap;
    
    switch (rental.status) {
      case 'pending':
        if (DateTime.now().isAfter(rental.startDate)) {
          buttonText = 'Start';
          buttonIcon = Icons.play_arrow;
        }
        break;
      case 'active':
        buttonText = 'Complete';
        buttonIcon = Icons.check;
        break;
      case 'completed':
        buttonText = 'Review';
        buttonIcon = Icons.rate_review_outlined;
        break;
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: InkWell(
        onTap: buttonAction,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              buttonIcon,
              size: 16,
              color: AppColors.primary,
            ),
            const SizedBox(width: AppSpacing.xs),
            Text(
              buttonText,
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}









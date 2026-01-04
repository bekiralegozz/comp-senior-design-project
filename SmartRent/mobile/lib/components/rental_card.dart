import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../constants/config.dart';
import '../services/models.dart';

/// ==========================================================
/// RENTAL CARD - BLOCKCHAIN MIGRATION VERSION
/// ==========================================================
///
/// Displays rental information with blockchain awareness.
/// Handles nullable fields gracefully.

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
            if (rental.startDate != null && rental.endDate != null)
            _buildRentalDetails(theme),
            
            if (!compact) ...[
              const SizedBox(height: AppSpacing.sm),
              
              // Timeline or actions
              if (rental.startDate != null && rental.endDate != null)
              _buildBottomSection(theme),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(ThemeData theme) {
    final status = rental.status ?? 'pending';
    final statusColor = RentalStatus.colors[status] ?? AppColors.grey;
    final statusIcon = RentalStatus.icons[status] ?? Icons.help_outline;
    
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
                'Rental #${rental.id.length > 8 ? rental.id.substring(0, 8) : rental.id}',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              Row(
                children: [
              Text(
                    RentalStatus.getDisplayName(status),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: statusColor,
                  fontWeight: FontWeight.w600,
                ),
                  ),
                  if (rental.txHash != null) ...[
                    const SizedBox(width: AppSpacing.xs),
                    Icon(Icons.check_circle, size: 12, color: AppColors.success),
                    const SizedBox(width: 2),
                    Text(
                      'On-chain',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.success,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
        Text(
          '${rental.totalPrice ?? rental.totalPriceUsd ?? 0} ${rental.currency ?? 'MATIC'}',
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
                  asset.title ?? 'Unnamed Asset',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  AssetCategories.getDisplayName(asset.category ?? 'other'),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.grey,
                  ),
                ),
                if (asset.tokenId != null)
                  Row(
                    children: [
                      Icon(Icons.token, size: 12, color: AppColors.secondary),
                      const SizedBox(width: 2),
                      Text(
                        'Token #${asset.tokenId}',
                          style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.secondary,
                            fontSize: 11,
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
    final startDate = rental.startDate!;
    final endDate = rental.endDate!;
    
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.md),
      child: Row(
        children: [
          Expanded(
            child: _buildDetailColumn(
              theme,
              'Start Date',
              DateFormat('MMM dd').format(startDate),
              Icons.play_circle_outline,
            ),
          ),
          Expanded(
            child: _buildDetailColumn(
              theme,
              'End Date',
              DateFormat('MMM dd').format(endDate),
              Icons.stop_circle_outlined,
            ),
          ),
          Expanded(
            child: _buildDetailColumn(
              theme,
              'Duration',
              '${endDate.difference(startDate).inDays} days',
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
        
        const SizedBox(width: AppSpacing.sm),
        
        // Smart Lock indicator
        _buildLockIndicator(theme),
        
        const SizedBox(width: AppSpacing.sm),
        
        // Quick action button
        _buildActionButton(theme),
      ],
    );
  }
  
  Widget _buildLockIndicator(ThemeData theme) {
    final now = DateTime.now();
    final startDate = rental.startDate;
    final endDate = rental.endDate;
    
    // Determine lock access status
    bool canUnlock = false;
    Color lockColor = AppColors.grey;
    String tooltip = 'Lock Access';
    
    if (startDate != null && endDate != null) {
      if (now.isAfter(endDate)) {
        // Rental ended
        lockColor = Colors.red;
        tooltip = 'Rental ended';
      } else if (now.isAfter(startDate) || now.isAtSameMomentAs(startDate)) {
        // Can unlock normally
        canUnlock = true;
        lockColor = Colors.green;
        tooltip = 'Can unlock';
      } else {
        // Not yet started
        lockColor = Colors.orange;
        tooltip = 'Starts soon';
      }
    }
    
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: lockColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: lockColor.withOpacity(0.3)),
      ),
      child: Tooltip(
        message: tooltip,
        child: Icon(
          canUnlock ? Icons.lock_open_rounded : Icons.lock_rounded,
          size: 18,
          color: lockColor,
        ),
      ),
    );
  }

  Widget _buildProgressIndicator(ThemeData theme) {
    final now = DateTime.now();
    final startTime = rental.startDate!;
    final endTime = rental.endDate!;
    final createdAt = rental.createdAt ?? startTime.subtract(const Duration(days: 1));
    
    double progress = 0.0;
    String progressText = 'Not started';
    Color progressColor = AppColors.grey;
    
    if (now.isBefore(startTime)) {
      // Before start
      final totalWait = startTime.difference(createdAt);
      final elapsed = now.difference(createdAt);
      progress = totalWait.inMilliseconds > 0
          ? elapsed.inMilliseconds / totalWait.inMilliseconds
          : 0;
      progressText = 'Starting soon';
      progressColor = AppColors.warning;
    } else if (now.isAfter(startTime) && now.isBefore(endTime)) {
      // During rental
      final totalDuration = endTime.difference(startTime);
      final elapsed = now.difference(startTime);
      progress = totalDuration.inMilliseconds > 0
          ? elapsed.inMilliseconds / totalDuration.inMilliseconds
          : 0;
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
    final status = rental.status ?? 'pending';
    String buttonText = 'View';
    IconData buttonIcon = Icons.visibility_outlined;
    VoidCallback? buttonAction = onTap;
    
    switch (status) {
      case 'pending':
        if (rental.startDate != null && DateTime.now().isAfter(rental.startDate!)) {
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

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../constants/config.dart';
import '../../services/rental_service.dart';
import '../../services/rental_models.dart' as rm;
import '../smart_lock_screen.dart';
import '../../services/models.dart' as ui_models;

/// Provider for fetching rental details by ID
final rentalDetailByIdProvider = FutureProvider.family<rm.Rental?, int>((ref, rentalId) async {
  final rentalService = RentalService();
  return await rentalService.getRental(rentalId);
});

class RentalDetailsScreen extends ConsumerWidget {
  final int rentalId;

  const RentalDetailsScreen({
    Key? key,
    required this.rentalId,
  }) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rentalAsync = ref.watch(rentalDetailByIdProvider(rentalId));
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/'),
        ),
        title: const Text('Rental Details'),
        actions: [
          // Smart Lock Button
          rentalAsync.when(
            data: (rental) => rental != null
                ? IconButton(
                    icon: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.lock_rounded,
                        color: Colors.blue,
                        size: 20,
                      ),
                    ),
                    tooltip: 'Smart Lock',
                    onPressed: () => _openSmartLock(context, rental),
                  )
                : const SizedBox.shrink(),
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Share feature coming soon!')),
              );
            },
          ),
        ],
      ),
      body: rentalAsync.when(
        data: (rental) => rental != null
            ? _buildRentalDetails(context, theme, rental)
            : _buildNotFound(context),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => _buildError(context, error.toString(), ref),
      ),
    );
  }

  void _openSmartLock(BuildContext context, rm.Rental rental) {
    // Convert to UI model for SmartLockScreen
    final uiRental = ui_models.Rental(
      id: rental.rentalId.toString(),
      assetId: rental.tokenId.toString(),
      renterId: null,
      renterWalletAddress: rental.renter,
      status: rental.status.name,
      startDate: rental.checkInDateTime,
      endDate: rental.checkOutDateTime,
      totalPrice: double.tryParse(rental.totalPrice),
      totalPriceUsd: null,
      securityDeposit: null,
      currency: 'POL',
      paymentTxHash: null,
      transactionHash: null,
      createdAt: DateTime.fromMillisecondsSinceEpoch(rental.createdAt * 1000),
      updatedAt: null,
      asset: null,
    );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SmartLockScreen(rental: uiRental),
      ),
    );
  }

  Widget _buildNotFound(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'Rental not found',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            'Rental ID: $rentalId',
            style: TextStyle(color: Colors.grey[600]),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Go Back'),
          ),
        ],
      ),
    );
  }

  Widget _buildError(BuildContext context, String error, WidgetRef ref) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64, color: Colors.red[400]),
          const SizedBox(height: 16),
          Text(
            'Error loading rental',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              error,
              style: TextStyle(color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => ref.invalidate(rentalDetailByIdProvider(rentalId)),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildRentalDetails(BuildContext context, ThemeData theme, rm.Rental rental) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Status Card
          _buildStatusCard(context, theme, rental),
          const SizedBox(height: 24),

          // Property Info
          _buildPropertyInfo(context, theme, rental),
          const SizedBox(height: 24),

          // Rental Info
          _buildRentalInfo(context, theme, rental),
          const SizedBox(height: 24),

          // Timeline
          _buildTimeline(context, theme, rental),
          const SizedBox(height: 24),

          // Actions
          _buildActions(context, theme, rental),
        ],
      ),
    );
  }

  Widget _buildStatusCard(BuildContext context, ThemeData theme, rm.Rental rental) {
    Color statusColor;
    IconData statusIcon;
    String statusText;

    switch (rental.status) {
      case rm.RentalStatus.active:
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        statusText = 'Active';
        break;
      case rm.RentalStatus.completed:
        statusColor = Colors.blue;
        statusIcon = Icons.done_all;
        statusText = 'Completed';
        break;
      case rm.RentalStatus.cancelled:
        statusColor = Colors.red;
        statusIcon = Icons.cancel;
        statusText = 'Cancelled';
        break;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            statusColor.withOpacity(0.1),
            statusColor.withOpacity(0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: statusColor.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(statusIcon, color: statusColor, size: 56),
          const SizedBox(height: 12),
          Text(
            statusText,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: statusColor,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Rental #$rentalId',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.verified, size: 16, color: Colors.green[700]),
                const SizedBox(width: 6),
                Text(
                  'On Blockchain',
                  style: TextStyle(
                    color: Colors.green[700],
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPropertyInfo(BuildContext context, ThemeData theme, rm.Rental rental) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Property',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.home_rounded,
                  color: Colors.blue,
                  size: 32,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      rental.propertyName ?? 'Property #${rental.tokenId}',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.token, size: 14, color: Colors.grey[600]),
                        const SizedBox(width: 4),
                        Text(
                          'Token ID: ${rental.tokenId}',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey[400]),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRentalInfo(BuildContext context, ThemeData theme, rm.Rental rental) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Rental Information',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: [
              _buildInfoRow(
                context,
                'Check-in',
                DateFormat('MMM dd, yyyy').format(rental.checkInDateTime),
                Icons.login_rounded,
              ),
              const Divider(height: 24),
              _buildInfoRow(
                context,
                'Check-out',
                DateFormat('MMM dd, yyyy').format(rental.checkOutDateTime),
                Icons.logout_rounded,
              ),
              const Divider(height: 24),
              _buildInfoRow(
                context,
                'Duration',
                '${rental.numberOfNights} nights',
                Icons.nights_stay_rounded,
              ),
              const Divider(height: 24),
              _buildInfoRow(
                context,
                'Total Price',
                '${rental.totalPrice} POL',
                Icons.payments_rounded,
                isHighlighted: true,
              ),
              const Divider(height: 24),
              _buildInfoRow(
                context,
                'Listing ID',
                '#${rental.listingId}',
                Icons.list_alt_rounded,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow(
    BuildContext context,
    String label,
    String value,
    IconData icon, {
    bool isHighlighted = false,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: (isHighlighted ? Colors.orange : Colors.grey).withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            size: 20,
            color: isHighlighted ? Colors.orange : Colors.grey[600],
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: Colors.grey[600],
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: isHighlighted ? Colors.orange : null,
            fontSize: isHighlighted ? 16 : 14,
          ),
        ),
      ],
    );
  }

  Widget _buildTimeline(BuildContext context, ThemeData theme, rm.Rental rental) {
    final now = DateTime.now();
    final checkIn = rental.checkInDateTime;
    final checkOut = rental.checkOutDateTime;
    final created = DateTime.fromMillisecondsSinceEpoch(rental.createdAt * 1000);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Timeline',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        _buildTimelineItem(
          'Booked',
          DateFormat('MMM dd, yyyy HH:mm').format(created),
          Icons.receipt_long_rounded,
          true,
        ),
        _buildTimelineItem(
          'Check-in',
          DateFormat('MMM dd, yyyy').format(checkIn),
          Icons.login_rounded,
          now.isAfter(checkIn),
        ),
        _buildTimelineItem(
          'Check-out',
          DateFormat('MMM dd, yyyy').format(checkOut),
          Icons.logout_rounded,
          now.isAfter(checkOut),
          isLast: true,
        ),
      ],
    );
  }

  Widget _buildTimelineItem(
    String title,
    String date,
    IconData icon,
    bool isCompleted, {
    bool isLast = false,
  }) {
    final color = isCompleted ? Colors.green : Colors.grey[400];

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color!.withOpacity(0.1),
                shape: BoxShape.circle,
                border: Border.all(color: color, width: 2),
              ),
              child: Icon(icon, size: 20, color: color),
            ),
            if (!isLast)
              Container(
                width: 2,
                height: 40,
                color: Colors.grey[300],
              ),
          ],
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: isCompleted ? Colors.black : Colors.grey[600],
                  ),
                ),
                Text(
                  date,
                  style: TextStyle(
                    color: Colors.grey[500],
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (isCompleted)
          Icon(Icons.check_circle, color: Colors.green, size: 20),
      ],
    );
  }

  Widget _buildActions(BuildContext context, ThemeData theme, rm.Rental rental) {
    // Convert to UI model for SmartLockScreen
    final uiRental = ui_models.Rental(
      id: rental.rentalId.toString(),
      assetId: rental.tokenId.toString(),
      renterId: null,
      renterWalletAddress: rental.renter,
      status: rental.status.name,
      startDate: rental.checkInDateTime,
      endDate: rental.checkOutDateTime,
      totalPrice: double.tryParse(rental.totalPrice),
      totalPriceUsd: null,
      securityDeposit: null,
      currency: 'POL',
      paymentTxHash: null,
      transactionHash: null,
      createdAt: DateTime.fromMillisecondsSinceEpoch(rental.createdAt * 1000),
      updatedAt: null,
      asset: null,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Actions',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),

        // Smart Lock Button - Primary Action
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => SmartLockScreen(rental: uiRental),
                ),
              );
            },
            icon: const Icon(Icons.lock_open_rounded),
            label: const Text('Unlock Door'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),

        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Support coming soon!')),
                  );
                },
                icon: const Icon(Icons.support_agent),
                label: const Text('Support'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Report issue coming soon!')),
                  );
                },
                icon: const Icon(Icons.report_problem),
                label: const Text('Report'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

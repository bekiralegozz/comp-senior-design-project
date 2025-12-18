import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../constants/config.dart';
import '../services/models.dart';
import '../components/rental_card.dart';
import '../core/providers/auth_provider.dart';
import '../core/providers/rental_provider.dart';
import '../core/providers/wallet_provider.dart';

/// ==========================================================
/// RENTAL SCREEN - BLOCKCHAIN MIGRATION VERSION
/// ==========================================================
///
/// Uses blockchain-based providers for rental data.
/// Rentals will be fetched from smart contracts.

class RentalScreen extends ConsumerStatefulWidget {
  final String? rentalId;

  const RentalScreen({Key? key, this.rentalId}) : super(key: key);

  @override
  ConsumerState<RentalScreen> createState() => _RentalScreenState();
}

class _RentalScreenState extends ConsumerState<RentalScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // If rentalId is provided, show rental details
    if (widget.rentalId != null) {
      return _buildRentalDetails(context, theme);
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Rentals'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'All'),
            Tab(text: 'Active'),
            Tab(text: 'Pending'),
            Tab(text: 'Completed'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildRentalsList(''),
          _buildRentalsList('active'),
          _buildRentalsList('pending'),
          _buildRentalsList('completed'),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Browse assets to create new rental!')),
          );
          context.go('/');
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildRentalDetails(BuildContext context, ThemeData theme) {
    final rentalState = ref.watch(rentalDetailProvider(widget.rentalId!));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Rental Details'),
        actions: [
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
      body: Builder(
        builder: (context) {
          if (rentalState.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          
          if (rentalState.error != null) {
            return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
                  Icon(Icons.error_outline, size: 64, color: AppColors.error),
              const SizedBox(height: AppSpacing.md),
                  Text(rentalState.error!),
              const SizedBox(height: AppSpacing.sm),
              ElevatedButton(
                    onPressed: () => ref.invalidate(rentalDetailProvider(widget.rentalId!)),
                child: const Text('Retry'),
              ),
            ],
          ),
            );
          }
          
          if (rentalState.rental != null) {
            return _buildRentalDetailsContent(context, theme, rentalState.rental!);
          }
          
          return _buildComingSoonPlaceholder(theme);
        },
      ),
    );
  }

  Widget _buildRentalsList(String statusFilter) {
    final rentalsState = ref.watch(myRentalsProvider);

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(myRentalsProvider);
      },
      child: Builder(
        builder: (context) {
          if (rentalsState.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          
          if (rentalsState.error != null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Error: ${rentalsState.error}'),
                  ElevatedButton(
                    onPressed: () => ref.invalidate(myRentalsProvider),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }
          
          final filteredRentals = statusFilter.isEmpty
              ? rentalsState.rentals
              : rentalsState.rentals.where((rental) => rental.status == statusFilter).toList();

          if (filteredRentals.isEmpty) {
            return _buildEmptyRentalsPlaceholder(statusFilter);
          }

          return ListView.builder(
            padding: const EdgeInsets.all(AppSpacing.md),
            itemCount: filteredRentals.length,
            itemBuilder: (context, index) {
              final rental = filteredRentals[index];
              return Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: RentalCard(
                  rental: rental,
                  onTap: () => context.go('/rental/${rental.id}'),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildEmptyRentalsPlaceholder(String statusFilter) {
    return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
          Icon(Icons.receipt_long_outlined, size: 64, color: AppColors.grey),
          const SizedBox(height: AppSpacing.md),
          Text(
            statusFilter.isEmpty ? 'No Rentals Yet' : 'No ${statusFilter} rentals',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: AppColors.grey,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Rentals from blockchain will appear here.\nStart exploring assets to create your first rental!',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppColors.grey,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.lg),
              ElevatedButton(
            onPressed: () => context.go('/'),
            child: const Text('Browse Assets'),
          ),
        ],
      ),
    );
  }

  Widget _buildComingSoonPlaceholder(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.construction, size: 64, color: AppColors.warning),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Blockchain Rentals Coming Soon',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Rental details will be fetched from\nthe RentalManager smart contract.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AppColors.grey,
          ),
        ),
        ],
      ),
    );
  }

  Widget _buildRentalDetailsContent(BuildContext context, ThemeData theme, Rental rental) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Status Card
          _buildStatusCard(theme, rental),
          const SizedBox(height: AppSpacing.lg),

          // Asset Info
          if (rental.asset != null) _buildAssetInfo(theme, rental),

          // Rental Details
          _buildRentalInfo(theme, rental),

          // Timeline
          _buildRentalTimeline(theme, rental),

          // Actions
          _buildRentalActions(context, theme, rental),
        ],
      ),
    );
  }

  Widget _buildStatusCard(ThemeData theme, Rental rental) {
    final statusColor = RentalStatus.colors[rental.status] ?? AppColors.grey;
    final statusIcon = RentalStatus.icons[rental.status] ?? Icons.help_outline;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: statusColor),
      ),
      child: Column(
        children: [
          Icon(statusIcon, color: statusColor, size: 48),
          const SizedBox(height: AppSpacing.sm),
          Text(
            RentalStatus.getDisplayName(rental.status ?? 'unknown'),
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: statusColor,
            ),
          ),
          Text(
            'Rental #${rental.id.substring(0, 8)}',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AppColors.grey,
            ),
          ),
          if (rental.txHash != null)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.sm),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: AppSpacing.xs,
                ),
                decoration: BoxDecoration(
                  color: AppColors.success.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.check_circle, size: 14, color: AppColors.success),
                    const SizedBox(width: AppSpacing.xs),
                    Text(
                      'On Blockchain',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.success,
                        fontWeight: FontWeight.w600,
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

  Widget _buildAssetInfo(ThemeData theme, Rental rental) {
    final asset = rental.asset!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Rented Asset',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        GestureDetector(
          onTap: () => context.go('/asset/${asset.id}'),
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
            child: Row(
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: (AppColors.categoryColors[asset.category] ?? AppColors.primary)
                        .withOpacity(0.1),
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: Icon(
                    AssetCategories.icons[asset.category] ?? Icons.category,
                    color: AppColors.categoryColors[asset.category] ?? AppColors.primary,
                    size: 32,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        asset.title ?? 'Unnamed Asset',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        AssetCategories.getDisplayName(asset.category ?? 'other'),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AppColors.grey,
                          ),
                        ),
                    ],
                  ),
                ),
                Icon(Icons.arrow_forward_ios, size: 16, color: AppColors.grey),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
      ],
    );
  }

  Widget _buildRentalInfo(ThemeData theme, Rental rental) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Rental Information',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Container(
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
              if (rental.startDate != null)
                _buildInfoRow('Start Date', DateFormat('MMM dd, yyyy').format(rental.startDate!)),
              if (rental.endDate != null)
                _buildInfoRow('End Date', DateFormat('MMM dd, yyyy').format(rental.endDate!)),
              if (rental.startDate != null && rental.endDate != null)
                _buildInfoRow('Duration', '${rental.endDate!.difference(rental.startDate!).inDays} days'),
              _buildInfoRow('Total Price', '${rental.totalPrice ?? rental.totalPriceUsd ?? 0} ${rental.currency ?? 'MATIC'}'),
              if (rental.txHash != null)
                _buildInfoRow('Transaction', rental.txHash!, isHash: true),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value, {bool isHash = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.grey,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              isHash ? '${value.substring(0, 10)}...${value.substring(value.length - 8)}' : value,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontFamily: isHash ? 'monospace' : null,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRentalTimeline(ThemeData theme, Rental rental) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Timeline',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        if (rental.createdAt != null)
        _buildTimelineItem(
          theme,
          'Created',
            DateFormat('MMM dd, yyyy HH:mm').format(rental.createdAt!),
          Icons.add_circle,
          true,
        ),
        if (rental.startDate != null)
        _buildTimelineItem(
          theme,
          'Start Date',
            DateFormat('MMM dd, yyyy').format(rental.startDate!),
          Icons.play_circle,
            DateTime.now().isAfter(rental.startDate!),
        ),
        if (rental.endDate != null)
        _buildTimelineItem(
          theme,
          'End Date',
            DateFormat('MMM dd, yyyy').format(rental.endDate!),
          Icons.stop_circle,
            DateTime.now().isAfter(rental.endDate!),
        ),
        const SizedBox(height: AppSpacing.lg),
      ],
    );
  }

  Widget _buildTimelineItem(
    ThemeData theme,
    String title,
    String date,
    IconData icon,
    bool isCompleted,
  ) {
    final color = isCompleted ? AppColors.success : AppColors.grey;
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: isCompleted ? Colors.black : AppColors.grey,
                  ),
                ),
                Text(
                  date,
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

  Widget _buildRentalActions(BuildContext context, ThemeData theme, Rental rental) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Actions',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        
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
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Report issue coming soon!')),
                  );
                },
                icon: const Icon(Icons.report_problem),
                label: const Text('Report'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

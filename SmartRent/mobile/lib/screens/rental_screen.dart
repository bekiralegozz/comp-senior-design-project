import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../constants/config.dart';
import '../services/models.dart';
import '../services/api_service.dart';
import '../components/rental_card.dart';

/// Provider for user rentals
final userRentalsProvider = FutureProvider.family<List<Rental>, int?>((ref, userId) async {
  final apiService = ApiService();
  if (userId != null) {
    return await apiService.getRentalsByUser(userId);
  } else {
    return await apiService.getRentals(limit: 50);
  }
});

/// Provider for rental details
final rentalDetailsProvider = FutureProvider.family<Rental, int>((ref, rentalId) async {
  final apiService = ApiService();
  return await apiService.getRental(rentalId);
});

class RentalScreen extends ConsumerStatefulWidget {
  final int? rentalId;

  const RentalScreen({Key? key, this.rentalId}) : super(key: key);

  @override
  ConsumerState<RentalScreen> createState() => _RentalScreenState();
}

class _RentalScreenState extends ConsumerState<RentalScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _selectedStatus = '';

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

    // If rentalId is provided, show rental details instead of list
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
          // TODO: Navigate to browse assets or create rental
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
    final rentalDetails = ref.watch(rentalDetailsProvider(widget.rentalId!));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Rental Details'),
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () {
              // TODO: Share rental details
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Share feature coming soon!')),
              );
            },
          ),
        ],
      ),
      body: rentalDetails.when(
        data: (rental) => _buildRentalDetailsContent(context, theme, rental),
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
              Text('Failed to load rental details'),
              const SizedBox(height: AppSpacing.sm),
              ElevatedButton(
                onPressed: () => ref.invalidate(rentalDetailsProvider(widget.rentalId!)),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRentalsList(String statusFilter) {
    // TODO: In a real app, you'd get the current user ID from authentication
    const currentUserId = 1; // Placeholder
    
    final rentals = ref.watch(userRentalsProvider(currentUserId));

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(userRentalsProvider(currentUserId));
      },
      child: rentals.when(
        data: (data) {
          final filteredRentals = statusFilter.isEmpty
              ? data
              : data.where((rental) => rental.status == statusFilter).toList();

          if (filteredRentals.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.receipt_long_outlined,
                    size: 64,
                    color: AppColors.grey,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    statusFilter.isEmpty
                        ? 'No rentals yet'
                        : 'No ${statusFilter} rentals',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: AppColors.grey,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'Start exploring assets to create your first rental',
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
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Error loading rentals: $error'),
              ElevatedButton(
                onPressed: () => ref.invalidate(userRentalsProvider(currentUserId)),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
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
            RentalStatus.getDisplayName(rental.status),
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: statusColor,
            ),
          ),
          Text(
            'Rental #${rental.id}',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AppColors.grey,
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
                        asset.title,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        AssetCategories.getDisplayName(asset.category),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.grey,
                        ),
                      ),
                      if (asset.location != null)
                        Text(
                          asset.location!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AppColors.grey,
                          ),
                        ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios,
                  size: 16,
                  color: AppColors.grey,
                ),
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
        _buildInfoCard(
          theme,
          [
            _buildInfoRow('Start Date', DateFormat('MMM dd, yyyy').format(rental.startDate)),
            _buildInfoRow('End Date', DateFormat('MMM dd, yyyy').format(rental.endDate)),
            _buildInfoRow('Duration', '${rental.endDate.difference(rental.startDate).inDays} days'),
            _buildInfoRow('Total Price', '${rental.totalPrice} ${rental.currency}'),
            _buildInfoRow('Security Deposit', '${rental.securityDeposit} ${rental.currency}'),
            if (rental.transactionHash != null)
              _buildInfoRow('Transaction', rental.transactionHash!, isHash: true),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
      ],
    );
  }

  Widget _buildInfoCard(ThemeData theme, List<Widget> children) {
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
      child: Column(children: children),
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
        _buildTimelineItem(
          theme,
          'Created',
          DateFormat('MMM dd, yyyy HH:mm').format(rental.createdAt),
          Icons.add_circle,
          true,
        ),
        _buildTimelineItem(
          theme,
          'Start Date',
          DateFormat('MMM dd, yyyy').format(rental.startDate),
          Icons.play_circle,
          DateTime.now().isAfter(rental.startDate),
        ),
        _buildTimelineItem(
          theme,
          'End Date',
          DateFormat('MMM dd, yyyy').format(rental.endDate),
          Icons.stop_circle,
          DateTime.now().isAfter(rental.endDate),
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
        
        if (rental.status == 'pending') ...[
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                // TODO: Implement rental activation
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Rental activation coming soon!')),
                );
              },
              icon: const Icon(Icons.play_arrow),
              label: const Text('Start Rental'),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () {
                // TODO: Implement rental cancellation
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Rental cancellation coming soon!')),
                );
              },
              icon: const Icon(Icons.cancel),
              label: const Text('Cancel Rental'),
            ),
          ),
        ],
        
        if (rental.status == 'active') ...[
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                // TODO: Implement rental completion
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Rental completion coming soon!')),
                );
              },
              icon: const Icon(Icons.check),
              label: const Text('Complete Rental'),
            ),
          ),
        ],
        
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () {
                  // TODO: Contact support
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
                  // TODO: Report issue
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










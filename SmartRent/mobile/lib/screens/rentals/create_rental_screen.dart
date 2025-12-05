import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../constants/config.dart';
import '../../core/providers/auth_provider.dart';
import '../../services/api_service.dart';
import '../../services/models.dart';

// Provider for API service
final apiServiceProvider = Provider<ApiService>((ref) => ApiService());

// Provider for fetching asset details
final assetProvider = FutureProvider.family<Asset, String>((ref, assetId) async {
  final apiService = ref.watch(apiServiceProvider);
  return await apiService.getAsset(assetId);
});

class CreateRentalScreen extends ConsumerStatefulWidget {
  final String assetId;

  const CreateRentalScreen({
    Key? key,
    required this.assetId,
  }) : super(key: key);

  @override
  ConsumerState<CreateRentalScreen> createState() => _CreateRentalScreenState();
}

class _CreateRentalScreenState extends ConsumerState<CreateRentalScreen> {
  DateTime? _startDate;
  DateTime? _endDate;
  bool _isLoading = false;
  String? _errorMessage;

  Future<void> _selectStartDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    
    if (picked != null) {
      setState(() {
        _startDate = picked;
        // Reset end date if it's before start date
        if (_endDate != null && _endDate!.isBefore(_startDate!)) {
          _endDate = null;
        }
      });
    }
  }

  Future<void> _selectEndDate() async {
    if (_startDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a start date first'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _startDate!.add(const Duration(days: 1)),
      firstDate: _startDate!.add(const Duration(days: 1)),
      lastDate: _startDate!.add(const Duration(days: 365)),
    );
    
    if (picked != null) {
      setState(() {
        _endDate = picked;
      });
    }
  }

  double _calculateTotalPrice(double pricePerDay) {
    if (_startDate == null || _endDate == null) return 0.0;
    
    final days = _endDate!.difference(_startDate!).inDays;
    return days * pricePerDay;
  }

  Future<void> _createRental() async {
    if (_startDate == null || _endDate == null) {
      setState(() {
        _errorMessage = 'Please select both start and end dates';
      });
      return;
    }

    final authState = ref.read(authStateProvider);
    if (authState.profile == null) {
      setState(() {
        _errorMessage = 'You must be logged in to create a rental';
      });
      return;
    }

    final assetAsync = await ref.read(assetProvider(widget.assetId).future);
    final asset = assetAsync;
    
    if (asset == null) {
      setState(() {
        _errorMessage = 'Asset not found';
      });
      return;
    }

    final totalPrice = _calculateTotalPrice(asset.pricePerDay ?? 0.0);

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final apiService = ref.read(apiServiceProvider);
      
      await apiService.createRental(
        assetId: widget.assetId,
        renterId: authState.profile!.id,
        startDate: _startDate!,
        endDate: _endDate!,
        totalPriceUsd: totalPrice,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Rental created successfully!'),
            backgroundColor: AppColors.success,
          ),
        );
        
        // Navigate back to home or rentals screen
        context.go('/');
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to create rental: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final assetAsync = ref.watch(assetProvider(widget.assetId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Rental'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: assetAsync.when(
        data: (asset) {
          final pricePerDay = asset.pricePerDay ?? 0.0;
          final totalPrice = _calculateTotalPrice(pricePerDay);

          return SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Asset Info Card
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    border: Border.all(color: AppColors.lightGrey),
                  ),
                  child: Row(
                    children: [
                      // Asset Image
                      ClipRRect(
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                        child: asset.imageUrl != null
                            ? Image.network(
                                asset.imageUrl!,
                                width: 80,
                                height: 80,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return Container(
                                    width: 80,
                                    height: 80,
                                    color: AppColors.lightGrey,
                                    child: const Icon(Icons.image, size: 40),
                                  );
                                },
                              )
                            : Container(
                                width: 80,
                                height: 80,
                                color: AppColors.lightGrey,
                                child: const Icon(Icons.image, size: 40),
                              ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      // Asset Details
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              asset.title ?? 'Unnamed Asset',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            Text(
                              '${pricePerDay.toStringAsFixed(2)} ${asset.currency ?? 'token'}/day',
                              style: theme.textTheme.bodyLarge?.copyWith(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: AppSpacing.xl),
                
                // Date Selection
                Text(
                  'Rental Period',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                
                // Start Date
                _buildDateSelector(
                  context,
                  label: 'Start Date',
                  date: _startDate,
                  onTap: _selectStartDate,
                ),
                
                const SizedBox(height: AppSpacing.md),
                
                // End Date
                _buildDateSelector(
                  context,
                  label: 'End Date',
                  date: _endDate,
                  onTap: _selectEndDate,
                ),
                
                const SizedBox(height: AppSpacing.xl),
                
                // Price Summary
                if (_startDate != null && _endDate != null) ...[
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      border: Border.all(color: AppColors.primary),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Duration:',
                              style: theme.textTheme.bodyLarge,
                            ),
                            Text(
                              '${_endDate!.difference(_startDate!).inDays} days',
                              style: theme.textTheme.bodyLarge?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Price per day:',
                              style: theme.textTheme.bodyLarge,
                            ),
                            Text(
                              '${pricePerDay.toStringAsFixed(2)} ${asset.currency ?? 'token'}',
                              style: theme.textTheme.bodyLarge?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        const Divider(height: AppSpacing.lg),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Total Price:',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              '${totalPrice.toStringAsFixed(2)} ${asset.currency ?? 'token'}',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                ],
                
                // Error Message
                if (_errorMessage != null) ...[
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: AppColors.error.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      border: Border.all(color: AppColors.error),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline, color: AppColors.error),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: AppColors.error,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],
                
                // Confirm Button
                ElevatedButton(
                  onPressed: _isLoading ? null : _createRental,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text(
                          'Confirm Rental',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: AppColors.error),
              const SizedBox(height: AppSpacing.md),
              Text(
                'Failed to load asset',
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                error.toString(),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColors.grey,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDateSelector(
    BuildContext context, {
    required String label,
    required DateTime? date,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.lightGrey),
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Row(
          children: [
            Icon(
              Icons.calendar_today,
              color: date != null ? AppColors.primary : AppColors.grey,
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.grey,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    date != null
                        ? DateFormat('MMM dd, yyyy').format(date)
                        : 'Select date',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: date != null ? FontWeight.w600 : FontWeight.normal,
                      color: date != null ? AppColors.textPrimary : AppColors.grey,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, size: 16, color: AppColors.grey),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../constants/config.dart';
import '../../services/api_service.dart';
import '../../services/models.dart';
import '../../core/providers/auth_provider.dart';

/// Provider for asset categories
final assetCategoriesProvider = FutureProvider<List<String>>((ref) async {
  final apiService = ApiService();
  await apiService.initialize();
  return await apiService.getAssetCategories();
});

/// Provider for IoT devices
final iotDevicesProvider = FutureProvider<List<IoTDevice>>((ref) async {
  final apiService = ApiService();
  await apiService.initialize();
  return await apiService.getIoTDevices();
});

class CreateAssetScreen extends ConsumerStatefulWidget {
  const CreateAssetScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<CreateAssetScreen> createState() => _CreateAssetScreenState();
}

class _CreateAssetScreenState extends ConsumerState<CreateAssetScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController();
  final _locationController = TextEditingController();
  final _imageUrlController = TextEditingController();
  
  String _selectedCategory = 'other';
  String _selectedCurrency = 'token';
  String? _selectedIoTDeviceId;
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _locationController.dispose();
    _imageUrlController.dispose();
    super.dispose();
  }

  Future<void> _createAsset() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final authState = ref.read(authStateProvider);
    final profile = authState.profile;

    if (profile == null || profile.id.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You must be logged in to create an asset')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final apiService = ApiService();
      await apiService.initialize();

      final asset = await apiService.createAsset(
        name: _nameController.text.trim(),
        ownerId: profile.id,
        pricePerDay: double.parse(_priceController.text),
        description: _descriptionController.text.trim().isEmpty 
            ? null 
            : _descriptionController.text.trim(),
        category: _selectedCategory,
        currency: _selectedCurrency,
        location: _locationController.text.trim().isEmpty 
            ? null 
            : _locationController.text.trim(),
        imageUrl: _imageUrlController.text.trim().isEmpty 
            ? null 
            : _imageUrlController.text.trim(),
        iotDeviceId: _selectedIoTDeviceId,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Asset "${asset.title}" created successfully!'),
            backgroundColor: AppColors.success,
          ),
        );
        context.pop(); // Go back to previous screen
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to create asset: ${e.toString()}'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final categoriesAsync = ref.watch(assetCategoriesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Create New Asset'),
        elevation: 0,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.md),
          children: [
            // Header
            Text(
              'Asset Information',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Fill in the details to list your asset for rent',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppColors.grey,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),

            // Name Field (Required)
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Asset Name *',
                hintText: 'e.g., Mountain Bike, Camera, Apartment',
                prefixIcon: Icon(Icons.inventory_2_outlined),
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter asset name';
                }
                return null;
              },
            ),
            const SizedBox(height: AppSpacing.md),

            // Category Dropdown
            categoriesAsync.when(
              data: (categories) => DropdownButtonFormField<String>(
                value: _selectedCategory,
                decoration: const InputDecoration(
                  labelText: 'Category *',
                  prefixIcon: Icon(Icons.category_outlined),
                  border: OutlineInputBorder(),
                ),
                items: categories.map((category) {
                  return DropdownMenuItem(
                    value: category,
                    child: Text(AssetCategories.getDisplayName(category)),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _selectedCategory = value);
                  }
                },
              ),
              loading: () => const LinearProgressIndicator(),
              error: (_, __) => DropdownButtonFormField<String>(
                value: _selectedCategory,
                decoration: const InputDecoration(
                  labelText: 'Category *',
                  prefixIcon: Icon(Icons.category_outlined),
                  border: OutlineInputBorder(),
                ),
                items: ['other'].map((category) {
                  return DropdownMenuItem(
                    value: category,
                    child: Text(AssetCategories.getDisplayName(category)),
                  );
                }).toList(),
                onChanged: null,
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            // Price Per Day (Required)
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: TextFormField(
                    controller: _priceController,
                    decoration: const InputDecoration(
                      labelText: 'Price per Day *',
                      hintText: '0.00',
                      prefixIcon: Icon(Icons.attach_money),
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                    ],
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter price';
                      }
                      final price = double.tryParse(value);
                      if (price == null || price <= 0) {
                        return 'Enter valid price';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  flex: 2,
                  child: DropdownButtonFormField<String>(
                    value: _selectedCurrency,
                    decoration: const InputDecoration(
                      labelText: 'Currency',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'token', child: Text('Token')),
                      DropdownMenuItem(value: 'ETH', child: Text('ETH')),
                      DropdownMenuItem(value: 'USD', child: Text('USD')),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => _selectedCurrency = value);
                      }
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),

            // Description (Optional)
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Description',
                hintText: 'Describe your asset...',
                prefixIcon: Icon(Icons.description_outlined),
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: AppSpacing.md),

            // Location (Optional)
            TextFormField(
              controller: _locationController,
              decoration: const InputDecoration(
                labelText: 'Location',
                hintText: 'City, Country',
                prefixIcon: Icon(Icons.location_on_outlined),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            // Image URL (Optional)
            TextFormField(
              controller: _imageUrlController,
              decoration: const InputDecoration(
                labelText: 'Image URL',
                hintText: 'https://example.com/image.jpg',
                prefixIcon: Icon(Icons.image_outlined),
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value != null && value.trim().isNotEmpty) {
                  final uri = Uri.tryParse(value);
                  if (uri == null || !uri.hasScheme) {
                    return 'Enter valid URL';
                  }
                }
                return null;
              },
            ),
            const SizedBox(height: AppSpacing.md),

            // IoT Device (Optional Dropdown)
            Consumer(
              builder: (context, ref, child) {
                final iotDevicesAsync = ref.watch(iotDevicesProvider);
                
                return iotDevicesAsync.when(
                  data: (devices) {
                    // Filter devices that are not already linked to an asset
                    final availableDevices = devices.where((d) => d.assetId == null).toList();
                    
                    return DropdownButtonFormField<String>(
                      value: _selectedIoTDeviceId,
                      decoration: const InputDecoration(
                        labelText: 'IoT Device (Optional)',
                        prefixIcon: Icon(Icons.sensors),
                        border: OutlineInputBorder(),
                        helperText: 'Link this asset to a smart lock device',
                      ),
                      hint: const Text('Select a device'),
                      items: [
                        const DropdownMenuItem<String>(
                          value: null,
                          child: Text('None'),
                        ),
                        ...availableDevices.map((device) {
                          return DropdownMenuItem<String>(
                            value: device.deviceId,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  device.isOnline ? Icons.circle : Icons.circle_outlined,
                                  size: 12,
                                  color: device.isOnline ? Colors.green : Colors.grey,
                                ),
                                const SizedBox(width: 8),
                                Flexible(
                                  child: Text(
                                    '${device.name} (${device.deviceId})',
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ],
                      onChanged: (value) {
                        setState(() => _selectedIoTDeviceId = value);
                      },
                    );
                  },
                  loading: () => DropdownButtonFormField<String>(
                    decoration: const InputDecoration(
                      labelText: 'IoT Device (Optional)',
                      prefixIcon: Icon(Icons.sensors),
                      border: OutlineInputBorder(),
                      helperText: 'Loading devices...',
                    ),
                    items: const [],
                    onChanged: null,
                  ),
                  error: (error, stack) => DropdownButtonFormField<String>(
                    decoration: InputDecoration(
                      labelText: 'IoT Device (Optional)',
                      prefixIcon: const Icon(Icons.sensors),
                      border: const OutlineInputBorder(),
                      helperText: 'Failed to load devices',
                      errorText: error.toString(),
                    ),
                    items: const [
                      DropdownMenuItem<String>(
                        value: null,
                        child: Text('None'),
                      ),
                    ],
                    onChanged: (value) {
                      setState(() => _selectedIoTDeviceId = value);
                    },
                  ),
                );
              },
            ),
            const SizedBox(height: AppSpacing.xl),

            // Submit Button
            ElevatedButton(
              onPressed: _isLoading ? null : _createAsset,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                minimumSize: const Size.fromHeight(50),
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
                      'Create Asset',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
            const SizedBox(height: AppSpacing.sm),

            // Cancel Button
            OutlinedButton(
              onPressed: _isLoading ? null : () => context.pop(),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                minimumSize: const Size.fromHeight(50),
              ),
              child: const Text('Cancel'),
            ),
          ],
        ),
      ),
    );
  }
}

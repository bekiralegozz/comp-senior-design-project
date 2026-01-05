import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:web3dart/web3dart.dart';

import '../../core/providers/auth_provider.dart';
import '../../services/api_service.dart';
import '../../services/wallet_service.dart';
import '../../services/iot_service.dart';

class CreateAssetScreen extends ConsumerStatefulWidget {
  const CreateAssetScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<CreateAssetScreen> createState() => _CreateAssetScreenState();
}

class _CreateAssetScreenState extends ConsumerState<CreateAssetScreen> {
  final _formKey = GlobalKey<FormState>();
  final _assetNameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _imageUrlController = TextEditingController();
  final _locationController = TextEditingController();
  final _squareFeetController = TextEditingController();
  final _bedroomsController = TextEditingController();
  
  String _propertyType = 'Apartment';
  bool _isLoading = false;
  String? _statusMessage;
  
  // IoT Device Selection
  List<IoTDeviceInfo> _availableDevices = [];
  IoTDeviceInfo? _selectedDevice;
  bool _isLoadingDevices = false;

  @override
  void initState() {
    super.initState();
    _loadAvailableDevices();
  }

  Future<void> _loadAvailableDevices() async {
    setState(() => _isLoadingDevices = true);
    try {
      final iotService = IoTService();
      final devices = await iotService.getAvailableDevices();
      setState(() {
        _availableDevices = devices;
        _isLoadingDevices = false;
      });
    } catch (e) {
      print('Error loading IoT devices: $e');
      setState(() => _isLoadingDevices = false);
    }
  }

  @override
  void dispose() {
    _assetNameController.dispose();
    _descriptionController.dispose();
    _imageUrlController.dispose();
    _locationController.dispose();
    _squareFeetController.dispose();
    _bedroomsController.dispose();
    super.dispose();
  }

  Future<void> _createAsset() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final authState = ref.read(authStateProvider);
    if (!authState.isAuthenticated || authState.walletAddress == null) {
      _showError('Please connect your wallet first');
      return;
    }

    setState(() {
      _isLoading = true;
      _statusMessage = 'Preparing NFT mint...';
    });

    try {
      final apiService = ApiService();
      final walletService = WalletService();
      await apiService.initialize();
      await walletService.initialize();

      // Generate random token ID
      final tokenId = Random().nextInt(1000000) + 1000;

      setState(() => _statusMessage = 'Uploading to IPFS...');

      // Step 1: Prepare mint (Backend uploads to IPFS)
      final prepareResponse = await apiService.prepareMint(
        tokenId: tokenId,
        ownerAddress: authState.walletAddress!,
        totalShares: 1000,
        assetName: _assetNameController.text,
        description: _descriptionController.text,
        imageUrl: _imageUrlController.text,
        propertyType: _propertyType,
        bedrooms: int.tryParse(_bedroomsController.text),
        location: _locationController.text.isEmpty ? null : _locationController.text,
        squareFeet: int.tryParse(_squareFeetController.text),
      );

      if (prepareResponse['success'] != true) {
        throw Exception('Failed to prepare mint');
      }

      setState(() => _statusMessage = 'Please sign transaction in your wallet...');

      // Step 2: Send transaction (User signs with wallet)
      final contractAddress = prepareResponse['contract_address'] as String;
      final functionData = prepareResponse['function_data'] as String;

      final txHash = await walletService.sendTransaction(
        to: contractAddress,
        value: EtherAmount.zero(),
        data: functionData,
      );

      setState(() => _statusMessage = 'Confirming transaction...');

      // Step 3: Confirm mint (Backend records)
      try {
        final confirmResponse = await apiService.confirmMint(
          tokenId: tokenId,
          transactionHash: txHash,
          ownerAddress: authState.walletAddress!,
        );

        // Step 4: Link IoT device if selected
        String? deviceLinkMessage;
        if (_selectedDevice != null) {
          setState(() => _statusMessage = 'Linking smart lock device...');
          final iotService = IoTService();
          final linkResult = await iotService.linkDeviceToAsset(
            _selectedDevice!.deviceId,
            tokenId,
            authState.walletAddress!,
          );
          if (linkResult.success) {
            deviceLinkMessage = '\n🔐 Smart Lock: ${_selectedDevice!.deviceId} linked';
          } else {
            deviceLinkMessage = '\n⚠️ Device link failed: ${linkResult.message}';
          }
        }

        if (confirmResponse['success'] == true) {
          final openSeaUrl = confirmResponse['opensea_url'] as String?;
          final isPending = confirmResponse['pending'] == true;
          
          _showSuccess(
            'NFT created successfully!\n\n'
            'Token ID: $tokenId\n'
            'Transaction: ${txHash.substring(0, 10)}...\n'
            '${isPending ? "\n⏳ Transaction is being mined..." : "\n✅ Confirmed on blockchain!"}'
            '${deviceLinkMessage ?? ""}\n\n'
            '${openSeaUrl != null ? "View on OpenSea" : ""}',
            openSeaUrl: openSeaUrl,
          );
        }
      } catch (confirmError) {
        // Even if confirm fails, transaction was sent successfully
        print('Confirm error (non-critical): $confirmError');
        _showSuccess(
          'NFT transaction sent!\n\n'
          'Token ID: $tokenId\n'
          'Transaction: ${txHash.substring(0, 10)}...\n\n'
          '⏳ Your NFT is being created on blockchain.\n'
          'It may take a few moments to appear.\n\n'
          'View on OpenSea: https://opensea.io/assets/matic/${prepareResponse['contract_address']}/$tokenId',
          openSeaUrl: 'https://opensea.io/assets/matic/${prepareResponse['contract_address']}/$tokenId',
        );
      }
    } catch (e) {
      _showError('Failed to create asset: ${e.toString()}');
    } finally {
      setState(() {
        _isLoading = false;
        _statusMessage = null;
      });
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 5),
      ),
    );
  }

  void _showSuccess(String message, {String? openSeaUrl}) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green, size: 32),
            SizedBox(width: 12),
            Text('Success!'),
          ],
        ),
        content: Text(message),
        actions: [
          if (openSeaUrl != null)
            TextButton(
              onPressed: () {
                // TODO: Open URL in browser
                Navigator.pop(context);
                Navigator.pop(context);
              },
              child: const Text('View on OpenSea'),
            ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create NFT Asset'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Info Card
              Card(
                color: Colors.blue[50],
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Icon(Icons.info_outline, color: Colors.blue[700]),
                      const SizedBox(height: 8),
                      Text(
                        'Create Fractional NFT',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Colors.blue[900],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'This will create a fractional NFT with 1000 shares. You\'ll need to sign the transaction in your wallet.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.blue[800],
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Asset Name
              TextFormField(
                controller: _assetNameController,
                decoration: const InputDecoration(
                  labelText: 'Asset Name *',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.title),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter asset name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Description
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description *',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.description),
                ),
                maxLines: 3,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter description';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Image URL
              TextFormField(
                controller: _imageUrlController,
                decoration: const InputDecoration(
                  labelText: 'Image URL *',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.image),
                  hintText: 'https://example.com/image.jpg',
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter image URL';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Property Type
              DropdownButtonFormField<String>(
                value: _propertyType,
                decoration: const InputDecoration(
                  labelText: 'Property Type',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.home),
                ),
                items: ['Apartment', 'House', 'Villa', 'Studio', 'Office']
                    .map((type) => DropdownMenuItem(
                          value: type,
                          child: Text(type),
                        ))
                    .toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _propertyType = value);
                  }
                },
              ),
              const SizedBox(height: 16),

              // Location
              TextFormField(
                controller: _locationController,
                decoration: const InputDecoration(
                  labelText: 'Location',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.location_on),
                ),
              ),
              const SizedBox(height: 16),

              // Bedrooms & Square Feet
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _bedroomsController,
                      decoration: const InputDecoration(
                        labelText: 'Bedrooms',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.bed),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _squareFeetController,
                      decoration: const InputDecoration(
                        labelText: 'Square Feet',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.square_foot),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // IoT Smart Lock Device Selection
              Card(
                color: Colors.green[50],
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.lock_outline, color: Colors.green[700]),
                          const SizedBox(width: 8),
                          Text(
                            'Smart Lock Device (Optional)',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: Colors.green[900],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Connect an ESP32 smart lock device to this property for remote access control.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.green[800],
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (_isLoadingDevices)
                        const Center(
                          child: Padding(
                            padding: EdgeInsets.all(8.0),
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      else if (_availableDevices.isEmpty)
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.orange[50],
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.orange[200]!),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.info_outline, color: Colors.orange[700], size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'No devices available. Make sure your ESP32 is powered on and connected.',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.orange[900],
                                  ),
                                ),
                              ),
                              IconButton(
                                icon: Icon(Icons.refresh, color: Colors.orange[700]),
                                onPressed: _loadAvailableDevices,
                                tooltip: 'Refresh devices',
                              ),
                            ],
                          ),
                        )
                      else
                        Row(
                          children: [
                            Expanded(
                              child: DropdownButtonFormField<IoTDeviceInfo>(
                                value: _selectedDevice,
                                decoration: InputDecoration(
                                  border: const OutlineInputBorder(),
                                  prefixIcon: Icon(Icons.router, color: Colors.green[700]),
                                  filled: true,
                                  fillColor: Colors.white,
                                ),
                                hint: const Text('Select a device'),
                                isExpanded: true,
                                items: _availableDevices.map((device) {
                                  return DropdownMenuItem(
                                    value: device,
                                    child: Row(
                                      children: [
                                        Icon(
                                          device.isOnline ? Icons.wifi : Icons.wifi_off,
                                          color: device.isOnline ? Colors.green : Colors.grey,
                                          size: 16,
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            device.deviceId,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: device.isOnline ? Colors.green[100] : Colors.grey[200],
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            device.isOnline ? 'Online' : 'Offline',
                                            style: TextStyle(
                                              fontSize: 10,
                                              color: device.isOnline ? Colors.green[800] : Colors.grey[600],
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }).toList(),
                                onChanged: (value) {
                                  setState(() => _selectedDevice = value);
                                },
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              icon: Icon(Icons.refresh, color: Colors.green[700]),
                              onPressed: _loadAvailableDevices,
                              tooltip: 'Refresh devices',
                            ),
                          ],
                        ),
                      if (_selectedDevice != null) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.green[100],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.check_circle, color: Colors.green[700], size: 18),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Device "${_selectedDevice!.deviceId}" will be linked to this property',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.green[900],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),


              // Status Message
              if (_statusMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue[200]!),
                  ),
                  child: Row(
                    children: [
                      const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _statusMessage!,
                          style: TextStyle(color: Colors.blue[900]),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Create Button
              ElevatedButton(
                onPressed: _isLoading ? null : _createAsset,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Text('Create NFT Asset'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


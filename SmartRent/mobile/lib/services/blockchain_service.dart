import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:web3dart/web3dart.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/blockchain_config.dart';
import 'wallet_service.dart';

/// Blockchain Service
/// Handles interaction with SmartRent smart contracts
class BlockchainService {
  static final BlockchainService _instance = BlockchainService._internal();
  factory BlockchainService() => _instance;
  BlockchainService._internal();

  final WalletService _walletService = WalletService();
  
  // Contract instances
  DeployedContract? _building1122Contract;
  DeployedContract? _rentalManagerContract;
  DeployedContract? _marketplaceContract;

  bool _initialized = false;

  /// Initialize blockchain service
  Future<void> initialize() async {
    if (_initialized) return;

    await _walletService.initialize();
    await _loadContracts();

    _initialized = true;
  }

  /// Load contract ABIs and create contract instances
  Future<void> _loadContracts() async {
    try {
      // Load Building1122 contract
      final building1122Abi = await rootBundle.loadString('lib/contracts/Building1122.json');
      final building1122AbiJson = jsonDecode(building1122Abi) as List<dynamic>;
      _building1122Contract = DeployedContract(
        ContractAbi.fromJson(jsonEncode(building1122AbiJson), 'Building1122'),
        EthereumAddress.fromHex(BlockchainConfig.building1122Address),
      );

      // Load RentalManager contract
      final rentalManagerAbi = await rootBundle.loadString('lib/contracts/RentalManager.json');
      final rentalManagerAbiJson = jsonDecode(rentalManagerAbi) as List<dynamic>;
      _rentalManagerContract = DeployedContract(
        ContractAbi.fromJson(jsonEncode(rentalManagerAbiJson), 'RentalManager'),
        EthereumAddress.fromHex(BlockchainConfig.rentalManagerAddress),
      );

      // Load Marketplace contract
      final marketplaceAbi = await rootBundle.loadString('lib/contracts/Marketplace.json');
      final marketplaceAbiJson = jsonDecode(marketplaceAbi) as List<dynamic>;
      _marketplaceContract = DeployedContract(
        ContractAbi.fromJson(jsonEncode(marketplaceAbiJson), 'Marketplace'),
        EthereumAddress.fromHex(BlockchainConfig.marketplaceAddress),
      );

      if (kDebugMode) {
        print('✅ Contracts loaded successfully');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error loading contracts: $e');
      }
      rethrow;
    }
  }

  /// Get token balance for a specific asset
  Future<BigInt> getTokenBalance({
    required String ownerAddress,
    required int tokenId,
  }) async {
    if (_building1122Contract == null) {
      await initialize();
    }

    try {
      final function = _building1122Contract!.function('balanceOf');
      final result = await _walletService.getWeb3Client().call(
        contract: _building1122Contract!,
        function: function,
        params: [
          EthereumAddress.fromHex(ownerAddress),
          BigInt.from(tokenId),
        ],
      );

      return result.first as BigInt;
    } catch (e) {
      if (kDebugMode) {
        print('Error getting token balance: $e');
      }
      throw BlockchainException('Failed to get token balance: $e');
    }
  }

  /// Get ownership percentage
  Future<int> getOwnershipPercentage({
    required String ownerAddress,
    required int tokenId,
  }) async {
    if (_building1122Contract == null) {
      await initialize();
    }

    try {
      final function = _building1122Contract!.function('getOwnershipPercentage');
      final result = await _walletService.getWeb3Client().call(
        contract: _building1122Contract!,
        function: function,
        params: [
          EthereumAddress.fromHex(ownerAddress),
          BigInt.from(tokenId),
        ],
      );

      return (result.first as BigInt).toInt();
    } catch (e) {
      if (kDebugMode) {
        print('Error getting ownership percentage: $e');
      }
      throw BlockchainException('Failed to get ownership percentage: $e');
    }
  }

  /// Pay rent for an asset
  Future<String> payRent({
    required int assetId,
    required String amount, // ETH amount as string (e.g., "0.1")
    required List<String> owners,
  }) async {
    if (_rentalManagerContract == null) {
      await initialize();
    }

    if (!_walletService.isConnected()) {
      throw BlockchainException('Wallet not connected');
    }

    try {
      final function = _rentalManagerContract!.function('payRent');
      
      // Prepare transaction
      final ethAmount = EtherAmount.fromUnitAndValue(EtherUnit.ether, double.parse(amount));
      
      final transaction = Transaction.callContract(
        contract: _rentalManagerContract!,
        function: function,
        parameters: [
          BigInt.from(assetId),
          owners.map((addr) => EthereumAddress.fromHex(addr)).toList(),
        ],
        value: ethAmount,
        maxGas: BlockchainConfig.defaultGasLimit,
      );

      // Send via WalletConnect
      final txHash = await _sendTransactionViaWallet(transaction);
      return txHash;
    } catch (e) {
      if (kDebugMode) {
        print('Error paying rent: $e');
      }
      throw BlockchainException('Failed to pay rent: $e');
    }
  }

  /// Buy shares from marketplace
  Future<String> buyShare({
    required int tokenId,
    required String seller,
    required int shareAmount,
    required String ethAmount, // ETH amount as string
  }) async {
    if (_marketplaceContract == null) {
      await initialize();
    }

    if (!_walletService.isConnected()) {
      throw BlockchainException('Wallet not connected');
    }

    try {
      final function = _marketplaceContract!.function('buyShare');
      
      final ethValue = EtherAmount.fromUnitAndValue(EtherUnit.ether, double.parse(ethAmount));
      
      final transaction = Transaction.callContract(
        contract: _marketplaceContract!,
        function: function,
        parameters: [
          BigInt.from(tokenId),
          EthereumAddress.fromHex(seller),
          BigInt.from(shareAmount),
        ],
        value: ethValue,
        maxGas: BlockchainConfig.defaultGasLimit,
      );

      final txHash = await _sendTransactionViaWallet(transaction);
      return txHash;
    } catch (e) {
      if (kDebugMode) {
        print('Error buying share: $e');
      }
      throw BlockchainException('Failed to buy share: $e');
    }
  }

  /// Get total rent collected for an asset
  Future<BigInt> getTotalRentCollected(int assetId) async {
    if (_rentalManagerContract == null) {
      await initialize();
    }

    try {
      final function = _rentalManagerContract!.function('getTotalRentCollected');
      final result = await _walletService.getWeb3Client().call(
        contract: _rentalManagerContract!,
        function: function,
        params: [BigInt.from(assetId)],
      );

      return result.first as BigInt;
    } catch (e) {
      if (kDebugMode) {
        print('Error getting total rent collected: $e');
      }
      throw BlockchainException('Failed to get total rent collected: $e');
    }
  }

  /// Check if token exists
  Future<bool> tokenExists(int tokenId) async {
    if (_building1122Contract == null) {
      await initialize();
    }

    try {
      final function = _building1122Contract!.function('exists');
      final result = await _walletService.getWeb3Client().call(
        contract: _building1122Contract!,
        function: function,
        params: [BigInt.from(tokenId)],
      );

      return result.first as bool;
    } catch (e) {
      if (kDebugMode) {
        print('Error checking token existence: $e');
      }
      return false;
    }
  }

  /// Send transaction via WalletConnect
  Future<String> _sendTransactionViaWallet(Transaction transaction) async {
    final address = _walletService.getAddress();
    if (address == null) {
      throw BlockchainException('No wallet address');
    }

    // Encode transaction data
    final data = transaction.data != null 
        ? '0x${transaction.data!.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join()}'
        : '0x';

    final txHash = await _walletService.sendTransaction(
      to: transaction.to!.hex,
      value: transaction.value ?? EtherAmount.zero(),
      data: data,
    );

    return txHash;
  }

  /// Wait for transaction confirmation
  Future<TransactionReceipt?> waitForTransaction(String txHash) async {
    try {
      return await _walletService.getWeb3Client().getTransactionReceipt(txHash);
    } catch (e) {
      if (kDebugMode) {
        print('Error waiting for transaction: $e');
      }
      return null;
    }
  }

  /// Get Building1122 contract instance
  DeployedContract? getBuildingContract() {
    return _building1122Contract;
  }

  /// Get RentalManager contract instance
  DeployedContract? getRentalManagerContract() {
    return _rentalManagerContract;
  }

  /// Get Marketplace contract instance
  DeployedContract? getMarketplaceContract() {
    return _marketplaceContract;
  }
}

/// Blockchain exception
class BlockchainException implements Exception {
  final String message;

  BlockchainException(this.message);

  @override
  String toString() => 'BlockchainException: $message';
}


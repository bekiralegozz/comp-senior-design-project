import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:web3dart/web3dart.dart';
import '../constants/config.dart';
import 'nft_models.dart';

/// NFT Service - Handles NFT and fractional share operations
class NftService {
  final String baseUrl = AppConfig.apiBaseUrl;
  final Web3Client? web3Client;
  final String? userAddress;

  NftService({
    this.web3Client,
    this.userAddress,
  });

  // ============================================
  // API METHODS (Backend Communication)
  // ============================================

  /// Get all available NFT assets
  Future<List<NftAsset>> getAllAssets({String? ownerAddress}) async {
    try {
      final uri = Uri.parse('$baseUrl/nft/assets').replace(
        queryParameters: {
          if (ownerAddress != null) 'owner_address': ownerAddress,
        },
      );
      
      final response = await http.get(
        uri,
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = json.decode(response.body);
        final List<dynamic> assetsData = responseData['assets'] ?? [];
        return assetsData.map((json) => NftAsset.fromJson(json)).toList();
      } else {
        throw Exception('Failed to load assets: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching assets: $e');
      return [];
    }
  }

  /// Get specific NFT asset details
  Future<NftAsset?> getAssetDetails(int tokenId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/nft/asset/$tokenId'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        return NftAsset.fromJson(json.decode(response.body));
      } else if (response.statusCode == 404) {
        return null;
      } else {
        throw Exception('Failed to load asset: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching asset $tokenId: $e');
      return null;
    }
  }

  /// Get user's NFT holdings
  Future<List<UserNftHolding>> getUserHoldings(String walletAddress) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/nft/holdings/$walletAddress'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((json) => UserNftHolding.fromJson(json)).toList();
      } else {
        throw Exception('Failed to load holdings: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching holdings: $e');
      return [];
    }
  }

  /// Get user's ownership percentage for a specific NFT
  Future<double> getOwnershipPercentage(
      int tokenId, String walletAddress) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/nft/ownership/$walletAddress/$tokenId'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return (data['ownership_percentage'] ?? 0.0).toDouble();
      } else {
        return 0.0;
      }
    } catch (e) {
      print('Error fetching ownership: $e');
      return 0.0;
    }
  }

  /// Get marketplace listings for a specific token
  Future<List<ShareListing>> getMarketplaceListings(int tokenId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/marketplace/listings?token_id=$tokenId'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((json) => ShareListing.fromJson(json)).toList();
      } else {
        throw Exception('Failed to load listings: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching listings: $e');
      return [];
    }
  }

  /// Buy fractional shares
  Future<String> buyShares(SharePurchaseRequest request) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/marketplace/buy'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(request.toJson()),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['transaction_hash'] ?? data['txHash'] ?? '';
      } else {
        throw Exception('Failed to buy shares: ${response.statusCode}');
      }
    } catch (e) {
      print('Error buying shares: $e');
      rethrow;
    }
  }

  // ============================================
  // BLOCKCHAIN METHODS (Direct Contract Calls)
  // ============================================

  /// Get NFT balance directly from blockchain
  Future<BigInt> getBalance(String walletAddress, int tokenId) async {
    if (web3Client == null) {
      throw Exception('Web3 client not initialized');
    }

    try {
      // Load Building1122 contract ABI
      final contract = DeployedContract(
        ContractAbi.fromJson(
          '''[{
            "inputs": [{"type": "address"}, {"type": "uint256"}],
            "name": "balanceOf",
            "outputs": [{"type": "uint256"}],
            "stateMutability": "view",
            "type": "function"
          }]''',
          'Building1122',
        ),
        EthereumAddress.fromHex(AppConfig.building1122Contract),
      );

      final balanceFunction = contract.function('balanceOf');
      final result = await web3Client!.call(
        contract: contract,
        function: balanceFunction,
        params: [
          EthereumAddress.fromHex(walletAddress),
          BigInt.from(tokenId),
        ],
      );

      return result.first as BigInt;
    } catch (e) {
      print('Error getting balance: $e');
      return BigInt.zero;
    }
  }

  /// Get total supply of an NFT
  Future<BigInt> getTotalSupply(int tokenId) async {
    if (web3Client == null) {
      throw Exception('Web3 client not initialized');
    }

    try {
      final contract = DeployedContract(
        ContractAbi.fromJson(
          '''[{
            "inputs": [{"type": "uint256"}],
            "name": "totalSupply",
            "outputs": [{"type": "uint256"}],
            "stateMutability": "view",
            "type": "function"
          }]''',
          'Building1122',
        ),
        EthereumAddress.fromHex(AppConfig.building1122Contract),
      );

      final supplyFunction = contract.function('totalSupply');
      final result = await web3Client!.call(
        contract: contract,
        function: supplyFunction,
        params: [BigInt.from(tokenId)],
      );

      return result.first as BigInt;
    } catch (e) {
      print('Error getting total supply: $e');
      return BigInt.zero;
    }
  }

  /// Check if user has approved marketplace
  Future<bool> isMarketplaceApproved(String walletAddress) async {
    if (web3Client == null) {
      throw Exception('Web3 client not initialized');
    }

    try {
      final contract = DeployedContract(
        ContractAbi.fromJson(
          '''[{
            "inputs": [{"type": "address"}, {"type": "address"}],
            "name": "isApprovedForAll",
            "outputs": [{"type": "bool"}],
            "stateMutability": "view",
            "type": "function"
          }]''',
          'Building1122',
        ),
        EthereumAddress.fromHex(AppConfig.building1122Contract),
      );

      final approvalFunction = contract.function('isApprovedForAll');
      final result = await web3Client!.call(
        contract: contract,
        function: approvalFunction,
        params: [
          EthereumAddress.fromHex(walletAddress),
          EthereumAddress.fromHex(AppConfig.marketplaceContract),
        ],
      );

      return result.first as bool;
    } catch (e) {
      print('Error checking approval: $e');
      return false;
    }
  }

  // ============================================
  // UTILITY METHODS
  // ============================================

  /// Format MATIC amount for display
  String formatMatic(dynamic amount) {
    try {
      if (amount is String) {
        final value = double.parse(amount);
        return '${value.toStringAsFixed(4)} MATIC';
      } else if (amount is double) {
        return '${amount.toStringAsFixed(4)} MATIC';
      } else if (amount is int) {
        return '${amount.toStringAsFixed(4)} MATIC';
      }
      return '0.0000 MATIC';
    } catch (e) {
      return '0.0000 MATIC';
    }
  }

  /// Calculate total price for shares
  double calculateTotalPrice(double pricePerShare, int shares) {
    try {
      return pricePerShare * shares;
    } catch (e) {
      return 0.0;
    }
  }

  /// Get OpenSea URL for NFT
  String getOpenSeaUrl(int tokenId) {
    return 'https://opensea.io/assets/matic/${AppConfig.building1122Contract}/$tokenId';
  }

  /// Get PolygonScan URL for transaction
  String getPolygonScanTxUrl(String txHash) {
    return 'https://polygonscan.com/tx/$txHash';
  }

  /// Get PolygonScan URL for address
  String getPolygonScanAddressUrl(String address) {
    return 'https://polygonscan.com/address/$address';
  }
}

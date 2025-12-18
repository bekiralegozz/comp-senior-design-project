import 'package:json_annotation/json_annotation.dart';

part 'models.g.dart';

/// ==========================================================
/// SMARTRENT MODELS - BLOCKCHAIN MIGRATION VERSION
/// ==========================================================
/// 
/// These models are designed to work with both:
/// - Legacy database endpoints (temporary, during migration)
/// - New blockchain-based data structures
/// 
/// User identification is now wallet address based.

// ============================================
// API RESPONSE MODELS
// ============================================

/// Base API response model
@JsonSerializable(genericArgumentFactories: true)
class ApiResponse<T> {
  final bool success;
  final String? message;
  final T? data;
  final Map<String, dynamic>? errors;

  ApiResponse({
    required this.success,
    this.message,
    this.data,
    this.errors,
  });

  factory ApiResponse.fromJson(
    Map<String, dynamic> json,
    T Function(Object?) fromJsonT,
  ) =>
      _$ApiResponseFromJson(json, fromJsonT);

  Map<String, dynamic> toJson(Object Function(T) toJsonT) =>
      _$ApiResponseToJson(this, toJsonT);
}

/// Pagination model
@JsonSerializable(genericArgumentFactories: true)
class PaginatedResponse<T> {
  final List<T> items;
  final int total;
  final int page;
  final int size;
  final int pages;

  PaginatedResponse({
    required this.items,
    required this.total,
    required this.page,
    required this.size,
    required this.pages,
  });

  factory PaginatedResponse.fromJson(
    Map<String, dynamic> json,
    T Function(Object?) fromJsonT,
  ) =>
      _$PaginatedResponseFromJson(json, fromJsonT);

  Map<String, dynamic> toJson(Object Function(T) toJsonT) =>
      _$PaginatedResponseToJson(this, toJsonT);
}

// ============================================
// USER MODEL (Wallet-Based)
// ============================================

/// User model - now wallet address based
/// In blockchain-first architecture, wallet address = user ID
@JsonSerializable()
class User {
  final String id;
  final String? email;
  final String? displayName;
  final String? walletAddress;
  final String? avatarUrl;
  final bool isVerified;
  final DateTime createdAt;
  final DateTime? updatedAt;
  
  // Computed properties
  String get fullName => displayName ?? 'User';
  String get username => walletAddress != null 
      ? '${walletAddress!.substring(0, 6)}...${walletAddress!.substring(38)}'
      : 'Unknown';

  User({
    required this.id,
    this.email,
    this.displayName,
    this.walletAddress,
    this.avatarUrl,
    this.isVerified = false,
    required this.createdAt,
    this.updatedAt,
  });

  factory User.fromJson(Map<String, dynamic> json) => _$UserFromJson(json);
  Map<String, dynamic> toJson() => _$UserToJson(this);
  
  /// Create user from wallet address only
  factory User.fromWallet(String walletAddress) {
    return User(
      id: walletAddress,
      walletAddress: walletAddress,
      displayName: 'User ${walletAddress.substring(0, 6)}',
      isVerified: true,
      createdAt: DateTime.now(),
    );
  }
}

// ============================================
// ASSET MODEL (Blockchain-Ready)
// ============================================

/// Asset model - represents a rental property
/// Can be minted as NFT on blockchain
@JsonSerializable()
class Asset {
  final String id;
  final String? title;
  final String? description;
  final String? category;
  final double? pricePerDay;
  final String? currency;
  final dynamic location;
  final String? imageUrl;
  final String? ownerId;
  final String? ownerWalletAddress;
  final bool? isAvailable;
  final String? iotDeviceId;
  final int? tokenId; // NFT token ID on blockchain
  final String? contractAddress; // Smart contract address
  final String? metadataUri; // IPFS metadata URI
  final DateTime? createdAt;
  final DateTime? updatedAt;
  
  // Owner object for UI compatibility
  User? get owner => ownerWalletAddress != null 
      ? User.fromWallet(ownerWalletAddress!)
      : null;

  Asset({
    required this.id,
    this.title,
    this.description,
    this.category,
    this.pricePerDay,
    this.currency,
    this.location,
    this.imageUrl,
    this.ownerId,
    this.ownerWalletAddress,
    this.isAvailable,
    this.iotDeviceId,
    this.tokenId,
    this.contractAddress,
    this.metadataUri,
    this.createdAt,
    this.updatedAt,
  });

  factory Asset.fromJson(Map<String, dynamic> json) => _$AssetFromJson(json);
  Map<String, dynamic> toJson() => _$AssetToJson(this);
  
  /// Check if asset is tokenized on blockchain
  bool get isTokenized => tokenId != null && contractAddress != null;
  
  /// Get location as string
  String get locationString {
    if (location == null) return 'Unknown';
    if (location is String) return location;
    if (location is Map) {
      return location['address'] ?? location['city'] ?? 'Unknown';
    }
    return location.toString();
  }
}

// ============================================
// RENTAL MODEL (Blockchain-Ready)
// ============================================

/// Rental model - represents a rental agreement
/// Can be recorded on blockchain
@JsonSerializable()
class Rental {
  final String id;
  final String? assetId;
  final String? renterId;
  final String? renterWalletAddress;
  final String? status;
  final DateTime? startDate;
  final DateTime? endDate;
  final double? totalPrice;
  final double? totalPriceUsd;
  final double? securityDeposit;
  final String? currency;
  final String? paymentTxHash;
  final String? transactionHash; // Alias for paymentTxHash
  final DateTime? createdAt;
  final DateTime? updatedAt;
  
  // Asset object for UI compatibility
  Asset? asset;

  Rental({
    required this.id,
    this.assetId,
    this.renterId,
    this.renterWalletAddress,
    this.status,
    this.startDate,
    this.endDate,
    this.totalPrice,
    this.totalPriceUsd,
    this.securityDeposit,
    this.currency,
    this.paymentTxHash,
    this.transactionHash,
    this.createdAt,
    this.updatedAt,
    this.asset,
  });

  factory Rental.fromJson(Map<String, dynamic> json) => _$RentalFromJson(json);
  Map<String, dynamic> toJson() => _$RentalToJson(this);
  
  /// Check if rental is on blockchain
  bool get isOnChain => paymentTxHash != null || transactionHash != null;
  
  /// Get transaction hash (compatible getter)
  String? get txHash => paymentTxHash ?? transactionHash;
}

// ============================================
// IOT DEVICE MODEL (Placeholder)
// ============================================

/// IoT Device model - for smart lock integration
@JsonSerializable()
class IoTDevice {
  final String id;
  final String? deviceId;
  final String? name;
  final String? type;
  final String? status;
  final String? assetId;
  final DateTime? lastSeen;
  final DateTime? createdAt;

  IoTDevice({
    required this.id,
    this.deviceId,
    this.name,
    this.type,
    this.status,
    this.assetId,
    this.lastSeen,
    this.createdAt,
  });

  factory IoTDevice.fromJson(Map<String, dynamic> json) => _$IoTDeviceFromJson(json);
  Map<String, dynamic> toJson() => _$IoTDeviceToJson(this);
}

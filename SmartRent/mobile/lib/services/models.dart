import 'package:json_annotation/json_annotation.dart';

part 'models.g.dart';

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

/// User model
@JsonSerializable()
class User {
  final String id;  // Changed from int to String for UUID support
  final String? email;
  final String? displayName;
  final String? walletAddress;
  final DateTime createdAt;
  final DateTime? updatedAt;
  
  // Computed properties for compatibility
  String get fullName => displayName ?? 'Unknown User';
  String get username => email?.split('@').first ?? 'user_${id.substring(0, 8)}';
  bool get isVerified => walletAddress != null;

  User({
    required this.id,
    this.email,
    this.displayName,
    this.walletAddress,
    required this.createdAt,
    this.updatedAt,
  });

  factory User.fromJson(Map<String, dynamic> json) => _$UserFromJson(json);
  Map<String, dynamic> toJson() => _$UserToJson(this);
}

/// Asset model
@JsonSerializable()
class Asset {
  final String id;
  
  final String? title;  // Backend returns 'title' directly
  
  final String? description;
  
  final String? category;  // Backend returns 'category' directly
  
  final double? pricePerDay;  // Backend returns 'pricePerDay' in camelCase
  
  final String? currency;  // Backend returns 'currency' directly
  
  final dynamic location;  // Backend returns 'location' directly
  
  final String? ownerId;  // Backend returns 'ownerId' in camelCase
  
  final int? tokenId;  // Backend returns 'tokenId' in camelCase
  
  final String? contractAddress;  // Backend returns 'contractAddress' in camelCase
  
  final bool? isAvailable;  // Backend returns 'isAvailable' in camelCase
  
  final String? iotDeviceId;  // Backend returns 'iotDeviceId' in camelCase
  
  final String? imageUrl;  // Backend returns 'imageUrl' in camelCase
  
  final DateTime? createdAt;  // Backend returns 'createdAt' in camelCase
  
  final DateTime? updatedAt;  // Backend returns 'updatedAt' in camelCase
  
  final User? owner;

  Asset({
    required this.id,
    this.title,
    this.description,
    this.category,
    this.pricePerDay,
    this.currency,
    this.location,
    this.ownerId,
    this.tokenId,
    this.contractAddress,
    this.isAvailable,
    this.iotDeviceId,
    this.imageUrl,
    this.createdAt,
    this.updatedAt,
    this.owner,
  });

  factory Asset.fromJson(Map<String, dynamic> json) => _$AssetFromJson(json);
  Map<String, dynamic> toJson() => _$AssetToJson(this);
  
  // Helper method to get location as String
  String? get locationString {
    if (location == null) return null;
    if (location is String) return location as String;
    if (location is Map) {
      final map = location as Map<String, dynamic>;
      return map['address'] as String?;
    }
    return null;
  }
}

/// Rental model
@JsonSerializable()
class Rental {
  final String id;
  
  @JsonKey(name: 'asset_id')
  final String assetId;
  
  @JsonKey(name: 'renter_id')
  final String renterId;
  
  @JsonKey(name: 'start_date')
  final DateTime startDate;
  
  @JsonKey(name: 'end_date')
  final DateTime endDate;
  
  @JsonKey(name: 'total_price_usd')
  final double? totalPrice;
  
  final String status;
  
  @JsonKey(name: 'payment_tx_hash')
  final String? transactionHash;
  
  @JsonKey(name: 'created_at')
  final DateTime createdAt;
  
  @JsonKey(name: 'updated_at')
  final DateTime? updatedAt;
  
  @JsonKey(name: 'assets')
  final Asset? asset;

  Rental({
    required this.id,
    required this.assetId,
    required this.renterId,
    required this.startDate,
    required this.endDate,
    this.totalPrice,
    required this.status,
    this.transactionHash,
    required this.createdAt,
    this.updatedAt,
    this.asset,
  });

  factory Rental.fromJson(Map<String, dynamic> json) => _$RentalFromJson(json);
  Map<String, dynamic> toJson() => _$RentalToJson(this);
  
  // Helper getters for compatibility
  String get currency => 'USD';
  double get securityDeposit => 0.0;
  bool get depositReturned => false;
  User? get renter => null;
}

/// IoT Device model
@JsonSerializable()
class IoTDevice {
  final int id;  // bigint in database
  
  @JsonKey(name: 'device_id')
  final String deviceId;
  
  @JsonKey(name: 'device_type')
  final String deviceType;
  
  @JsonKey(name: 'device_name')
  final String name;
  
  @JsonKey(name: 'is_online')
  final bool isOnline;
  
  @JsonKey(name: 'battery_level')
  final int? batteryLevel;
  
  @JsonKey(name: 'last_seen')
  final DateTime? lastSeen;
  
  @JsonKey(name: 'firmware_version')
  final String? firmwareVersion;
  
  @JsonKey(name: 'hardware_version')
  final String? hardwareVersion;
  
  @JsonKey(name: 'asset_id')
  final String? assetId;  // Changed from int to String for UUID support
  
  @JsonKey(name: 'created_at')
  final DateTime createdAt;
  
  @JsonKey(name: 'updated_at')
  final DateTime? updatedAt;

  IoTDevice({
    required this.id,
    required this.deviceId,
    required this.deviceType,
    required this.name,
    required this.isOnline,
    this.batteryLevel,
    this.lastSeen,
    this.firmwareVersion,
    this.hardwareVersion,
    this.assetId,
    required this.createdAt,
    this.updatedAt,
  });

  factory IoTDevice.fromJson(Map<String, dynamic> json) =>
      _$IoTDeviceFromJson(json);
  Map<String, dynamic> toJson() => _$IoTDeviceToJson(this);
}

/// Create user request model
@JsonSerializable()
class CreateUserRequest {
  final String? email;
  final String displayName;
  final String? walletAddress;

  CreateUserRequest({
    this.email,
    required this.displayName,
    this.walletAddress,
  });

  factory CreateUserRequest.fromJson(Map<String, dynamic> json) =>
      _$CreateUserRequestFromJson(json);
  Map<String, dynamic> toJson() => _$CreateUserRequestToJson(this);
}

/// Create asset request model
@JsonSerializable()
class CreateAssetRequest {
  final String title;
  final String? description;
  final String category;
  final double? pricePerDay;  // Nullable
  final String currency;
  final String? location;
  final String ownerId;  // Changed from int to String for UUID support
  final String? iotDeviceId;

  CreateAssetRequest({
    required this.title,
    this.description,
    required this.category,
    this.pricePerDay,  // Optional
    required this.currency,
    this.location,
    required this.ownerId,
    this.iotDeviceId,
  });

  factory CreateAssetRequest.fromJson(Map<String, dynamic> json) =>
      _$CreateAssetRequestFromJson(json);
  Map<String, dynamic> toJson() => _$CreateAssetRequestToJson(this);
}

/// Create rental request model
@JsonSerializable()
class CreateRentalRequest {
  final String assetId;  // Changed from int to String for UUID support
  final String renterId;  // Changed from int to String for UUID support
  final DateTime startDate;
  final DateTime endDate;
  final double totalPrice;
  final String currency;
  final double securityDeposit;

  CreateRentalRequest({
    required this.assetId,
    required this.renterId,
    required this.startDate,
    required this.endDate,
    required this.totalPrice,
    required this.currency,
    required this.securityDeposit,
  });

  factory CreateRentalRequest.fromJson(Map<String, dynamic> json) =>
      _$CreateRentalRequestFromJson(json);
  Map<String, dynamic> toJson() => _$CreateRentalRequestToJson(this);
}

/// Update asset request model
@JsonSerializable()
class UpdateAssetRequest {
  final String? title;
  final String? description;
  final String? category;
  final double? pricePerDay;
  final String? currency;
  final bool? isAvailable;
  final String? location;

  UpdateAssetRequest({
    this.title,
    this.description,
    this.category,
    this.pricePerDay,
    this.currency,
    this.isAvailable,
    this.location,
  });

  factory UpdateAssetRequest.fromJson(Map<String, dynamic> json) =>
      _$UpdateAssetRequestFromJson(json);
  Map<String, dynamic> toJson() => _$UpdateAssetRequestToJson(this);
}

/// Wallet connection model
@JsonSerializable()
class WalletConnection {
  final String address;
  final String chainId;
  final String? networkName;
  final bool isConnected;
  final DateTime? connectedAt;

  WalletConnection({
    required this.address,
    required this.chainId,
    this.networkName,
    required this.isConnected,
    this.connectedAt,
  });

  factory WalletConnection.fromJson(Map<String, dynamic> json) =>
      _$WalletConnectionFromJson(json);
  Map<String, dynamic> toJson() => _$WalletConnectionToJson(this);
}

/// Blockchain transaction model
@JsonSerializable()
class BlockchainTransaction {
  final String hash;
  final String from;
  final String to;
  final String value;
  final String gasUsed;
  final String gasPrice;
  final String status;
  final DateTime timestamp;

  BlockchainTransaction({
    required this.hash,
    required this.from,
    required this.to,
    required this.value,
    required this.gasUsed,
    required this.gasPrice,
    required this.status,
    required this.timestamp,
  });

  factory BlockchainTransaction.fromJson(Map<String, dynamic> json) =>
      _$BlockchainTransactionFromJson(json);
  Map<String, dynamic> toJson() => _$BlockchainTransactionToJson(this);
}

/// Error response model
@JsonSerializable()
class ErrorResponse {
  final String message;
  final String? code;
  final Map<String, dynamic>? details;

  ErrorResponse({
    required this.message,
    this.code,
    this.details,
  });

  factory ErrorResponse.fromJson(Map<String, dynamic> json) =>
      _$ErrorResponseFromJson(json);
  Map<String, dynamic> toJson() => _$ErrorResponseToJson(this);
}


DateTime? _parseIsoDate(dynamic value) {
  if (value is String) {
    try {
      return DateTime.parse(value).toLocal();
    } catch (_) {
      return null;
    }
  }
  return null;
}

class AuthProfile {
  final String id;
  final String? fullName;
  final String? email;
  final String? walletAddress;
  final String? avatarUrl;
  final bool? isOnboarded;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? lastLoginAt;

  AuthProfile({
    required this.id,
    this.fullName,
    this.email,
    this.walletAddress,
    this.avatarUrl,
    this.isOnboarded,
    this.createdAt,
    this.updatedAt,
    this.lastLoginAt,
  });

  factory AuthProfile.fromJson(Map<String, dynamic> json) {
    return AuthProfile(
      id: json['id']?.toString() ?? '',
      fullName: json['full_name'] as String?,
      email: json['email'] as String?,
      walletAddress: json['wallet_address'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      isOnboarded: json['is_onboarded'] as bool?,
      createdAt: _parseIsoDate(json['created_at']),
      updatedAt: _parseIsoDate(json['updated_at']),
      lastLoginAt: _parseIsoDate(json['last_login_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'full_name': fullName,
      'email': email,
      'wallet_address': walletAddress,
      'avatar_url': avatarUrl,
      'is_onboarded': isOnboarded,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'last_login_at': lastLoginAt?.toIso8601String(),
    };
  }
}

class AuthSession {
  final String accessToken;
  final String refreshToken;
  final String tokenType;
  final int expiresIn;
  final String userId;
  final AuthProfile? profile;

  AuthSession({
    required this.accessToken,
    required this.refreshToken,
    required this.tokenType,
    required this.expiresIn,
    required this.userId,
    this.profile,
  });

  factory AuthSession.fromJson(Map<String, dynamic> json) {
    final profileJson = json['profile'];
    return AuthSession(
      accessToken: json['access_token']?.toString() ?? '',
      refreshToken: json['refresh_token']?.toString() ?? '',
      tokenType: json['token_type']?.toString() ?? 'bearer',
      expiresIn: (json['expires_in'] is int)
          ? json['expires_in'] as int
          : int.tryParse(json['expires_in']?.toString() ?? '0') ?? 0,
      userId: json['user_id']?.toString() ??
          (json['user']?['id']?.toString() ?? ''),
      profile: profileJson is Map<String, dynamic>
          ? AuthProfile.fromJson(profileJson)
          : null,
    );
  }
}

class SignupResponse {
  final String userId;
  final bool requiresEmailVerification;

  SignupResponse({
    required this.userId,
    required this.requiresEmailVerification,
  });

  factory SignupResponse.fromJson(Map<String, dynamic> json) {
    return SignupResponse(
      userId: json['user_id']?.toString() ?? '',
      requiresEmailVerification:
          json['requires_email_verification'] as bool? ?? true,
    );
  }
}









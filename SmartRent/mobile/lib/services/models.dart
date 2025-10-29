import 'package:json_annotation/json_annotation.dart';

part 'models.g.dart';

/// Base API response model
@JsonSerializable()
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
@JsonSerializable()
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
  final int id;
  final String? email;
  final String? displayName;
  final String? walletAddress;
  final DateTime createdAt;
  final DateTime? updatedAt;
  
  // Computed properties for compatibility
  String get fullName => displayName ?? 'Unknown User';
  String get username => email?.split('@').first ?? 'user${id}';
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
  final int id;
  final String title;
  final String? description;
  final String category;
  final double pricePerDay;
  final String currency;
  final String? location;
  final int ownerId;
  final int? tokenId;
  final String? contractAddress;
  final bool isAvailable;
  final String? iotDeviceId;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final User? owner;

  Asset({
    required this.id,
    required this.title,
    this.description,
    required this.category,
    required this.pricePerDay,
    required this.currency,
    this.location,
    required this.ownerId,
    this.tokenId,
    this.contractAddress,
    required this.isAvailable,
    this.iotDeviceId,
    required this.createdAt,
    this.updatedAt,
    this.owner,
  });

  factory Asset.fromJson(Map<String, dynamic> json) => _$AssetFromJson(json);
  Map<String, dynamic> toJson() => _$AssetToJson(this);
}

/// Rental model
@JsonSerializable()
class Rental {
  final int id;
  final int assetId;
  final int renterId;
  final DateTime startDate;
  final DateTime endDate;
  final double totalPrice;
  final String currency;
  final String status;
  final String? smartContractAddress;
  final String? transactionHash;
  final double securityDeposit;
  final bool depositReturned;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final Asset? asset;
  final User? renter;

  Rental({
    required this.id,
    required this.assetId,
    required this.renterId,
    required this.startDate,
    required this.endDate,
    required this.totalPrice,
    required this.currency,
    required this.status,
    this.smartContractAddress,
    this.transactionHash,
    required this.securityDeposit,
    required this.depositReturned,
    required this.createdAt,
    this.updatedAt,
    this.asset,
    this.renter,
  });

  factory Rental.fromJson(Map<String, dynamic> json) => _$RentalFromJson(json);
  Map<String, dynamic> toJson() => _$RentalToJson(this);
}

/// IoT Device model
@JsonSerializable()
class IoTDevice {
  final int id;
  final String deviceId;
  final String deviceType;
  final String name;
  final bool isOnline;
  final int? batteryLevel;
  final DateTime? lastSeen;
  final String? firmwareVersion;
  final String? hardwareVersion;
  final int? assetId;
  final DateTime createdAt;
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
  final double pricePerDay;
  final String currency;
  final String? location;
  final int ownerId;
  final String? iotDeviceId;

  CreateAssetRequest({
    required this.title,
    this.description,
    required this.category,
    required this.pricePerDay,
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
  final int assetId;
  final int renterId;
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









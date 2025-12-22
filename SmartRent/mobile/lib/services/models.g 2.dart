// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ApiResponse<T> _$ApiResponseFromJson<T>(
  Map<String, dynamic> json,
  T Function(Object? json) fromJsonT,
) =>
    ApiResponse<T>(
      success: json['success'] as bool,
      message: json['message'] as String?,
      data: _$nullableGenericFromJson(json['data'], fromJsonT),
      errors: json['errors'] as Map<String, dynamic>?,
    );

Map<String, dynamic> _$ApiResponseToJson<T>(
  ApiResponse<T> instance,
  Object? Function(T value) toJsonT,
) =>
    <String, dynamic>{
      'success': instance.success,
      'message': instance.message,
      'data': _$nullableGenericToJson(instance.data, toJsonT),
      'errors': instance.errors,
    };

T? _$nullableGenericFromJson<T>(
  Object? input,
  T Function(Object? json) fromJson,
) =>
    input == null ? null : fromJson(input);

Object? _$nullableGenericToJson<T>(
  T? input,
  Object? Function(T value) toJson,
) =>
    input == null ? null : toJson(input);

PaginatedResponse<T> _$PaginatedResponseFromJson<T>(
  Map<String, dynamic> json,
  T Function(Object? json) fromJsonT,
) =>
    PaginatedResponse<T>(
      items: (json['items'] as List<dynamic>).map(fromJsonT).toList(),
      total: (json['total'] as num).toInt(),
      page: (json['page'] as num).toInt(),
      size: (json['size'] as num).toInt(),
      pages: (json['pages'] as num).toInt(),
    );

Map<String, dynamic> _$PaginatedResponseToJson<T>(
  PaginatedResponse<T> instance,
  Object? Function(T value) toJsonT,
) =>
    <String, dynamic>{
      'items': instance.items.map(toJsonT).toList(),
      'total': instance.total,
      'page': instance.page,
      'size': instance.size,
      'pages': instance.pages,
    };

User _$UserFromJson(Map<String, dynamic> json) => User(
      id: json['id'] as String,
      email: json['email'] as String?,
      displayName: json['displayName'] as String?,
      walletAddress: json['walletAddress'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: json['updatedAt'] == null
          ? null
          : DateTime.parse(json['updatedAt'] as String),
    );

Map<String, dynamic> _$UserToJson(User instance) => <String, dynamic>{
      'id': instance.id,
      'email': instance.email,
      'displayName': instance.displayName,
      'walletAddress': instance.walletAddress,
      'createdAt': instance.createdAt.toIso8601String(),
      'updatedAt': instance.updatedAt?.toIso8601String(),
    };

Asset _$AssetFromJson(Map<String, dynamic> json) => Asset(
      id: json['id'] as String,
      title: json['title'] as String?,
      description: json['description'] as String?,
      category: json['category'] as String?,
      pricePerDay: (json['pricePerDay'] as num?)?.toDouble(),
      currency: json['currency'] as String?,
      location: json['location'],
      ownerId: json['ownerId'] as String?,
      tokenId: (json['tokenId'] as num?)?.toInt(),
      contractAddress: json['contractAddress'] as String?,
      isAvailable: json['isAvailable'] as bool?,
      iotDeviceId: json['iotDeviceId'] as String?,
      imageUrl: json['imageUrl'] as String?,
      createdAt: json['createdAt'] == null
          ? null
          : DateTime.parse(json['createdAt'] as String),
      updatedAt: json['updatedAt'] == null
          ? null
          : DateTime.parse(json['updatedAt'] as String),
      owner: json['owner'] == null
          ? null
          : User.fromJson(json['owner'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$AssetToJson(Asset instance) => <String, dynamic>{
      'id': instance.id,
      'title': instance.title,
      'description': instance.description,
      'category': instance.category,
      'pricePerDay': instance.pricePerDay,
      'currency': instance.currency,
      'location': instance.location,
      'ownerId': instance.ownerId,
      'tokenId': instance.tokenId,
      'contractAddress': instance.contractAddress,
      'isAvailable': instance.isAvailable,
      'iotDeviceId': instance.iotDeviceId,
      'imageUrl': instance.imageUrl,
      'createdAt': instance.createdAt?.toIso8601String(),
      'updatedAt': instance.updatedAt?.toIso8601String(),
      'owner': instance.owner,
    };

Rental _$RentalFromJson(Map<String, dynamic> json) => Rental(
      id: json['id'] as String,
      assetId: json['asset_id'] as String,
      renterId: json['renter_id'] as String,
      startDate: DateTime.parse(json['start_date'] as String),
      endDate: DateTime.parse(json['end_date'] as String),
      totalPrice: (json['total_price_usd'] as num?)?.toDouble(),
      status: json['status'] as String,
      transactionHash: json['payment_tx_hash'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] == null
          ? null
          : DateTime.parse(json['updated_at'] as String),
      asset: json['assets'] == null
          ? null
          : Asset.fromJson(json['assets'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$RentalToJson(Rental instance) => <String, dynamic>{
      'id': instance.id,
      'asset_id': instance.assetId,
      'renter_id': instance.renterId,
      'start_date': instance.startDate.toIso8601String(),
      'end_date': instance.endDate.toIso8601String(),
      'total_price_usd': instance.totalPrice,
      'status': instance.status,
      'payment_tx_hash': instance.transactionHash,
      'created_at': instance.createdAt.toIso8601String(),
      'updated_at': instance.updatedAt?.toIso8601String(),
      'assets': instance.asset,
    };

IoTDevice _$IoTDeviceFromJson(Map<String, dynamic> json) => IoTDevice(
      id: (json['id'] as num).toInt(),
      deviceId: json['device_id'] as String,
      deviceType: json['device_type'] as String,
      name: json['device_name'] as String,
      isOnline: json['is_online'] as bool,
      batteryLevel: (json['battery_level'] as num?)?.toInt(),
      lastSeen: json['last_seen'] == null
          ? null
          : DateTime.parse(json['last_seen'] as String),
      firmwareVersion: json['firmware_version'] as String?,
      hardwareVersion: json['hardware_version'] as String?,
      assetId: json['asset_id'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] == null
          ? null
          : DateTime.parse(json['updated_at'] as String),
    );

Map<String, dynamic> _$IoTDeviceToJson(IoTDevice instance) => <String, dynamic>{
      'id': instance.id,
      'device_id': instance.deviceId,
      'device_type': instance.deviceType,
      'device_name': instance.name,
      'is_online': instance.isOnline,
      'battery_level': instance.batteryLevel,
      'last_seen': instance.lastSeen?.toIso8601String(),
      'firmware_version': instance.firmwareVersion,
      'hardware_version': instance.hardwareVersion,
      'asset_id': instance.assetId,
      'created_at': instance.createdAt.toIso8601String(),
      'updated_at': instance.updatedAt?.toIso8601String(),
    };

CreateUserRequest _$CreateUserRequestFromJson(Map<String, dynamic> json) =>
    CreateUserRequest(
      email: json['email'] as String?,
      displayName: json['displayName'] as String,
      walletAddress: json['walletAddress'] as String?,
    );

Map<String, dynamic> _$CreateUserRequestToJson(CreateUserRequest instance) =>
    <String, dynamic>{
      'email': instance.email,
      'displayName': instance.displayName,
      'walletAddress': instance.walletAddress,
    };

CreateAssetRequest _$CreateAssetRequestFromJson(Map<String, dynamic> json) =>
    CreateAssetRequest(
      title: json['title'] as String,
      description: json['description'] as String?,
      category: json['category'] as String,
      pricePerDay: (json['pricePerDay'] as num?)?.toDouble(),
      currency: json['currency'] as String,
      location: json['location'] as String?,
      ownerId: json['ownerId'] as String,
      iotDeviceId: json['iotDeviceId'] as String?,
    );

Map<String, dynamic> _$CreateAssetRequestToJson(CreateAssetRequest instance) =>
    <String, dynamic>{
      'title': instance.title,
      'description': instance.description,
      'category': instance.category,
      'pricePerDay': instance.pricePerDay,
      'currency': instance.currency,
      'location': instance.location,
      'ownerId': instance.ownerId,
      'iotDeviceId': instance.iotDeviceId,
    };

CreateRentalRequest _$CreateRentalRequestFromJson(Map<String, dynamic> json) =>
    CreateRentalRequest(
      assetId: json['assetId'] as String,
      renterId: json['renterId'] as String,
      startDate: DateTime.parse(json['startDate'] as String),
      endDate: DateTime.parse(json['endDate'] as String),
      totalPrice: (json['totalPrice'] as num).toDouble(),
      currency: json['currency'] as String,
      securityDeposit: (json['securityDeposit'] as num).toDouble(),
    );

Map<String, dynamic> _$CreateRentalRequestToJson(
        CreateRentalRequest instance) =>
    <String, dynamic>{
      'assetId': instance.assetId,
      'renterId': instance.renterId,
      'startDate': instance.startDate.toIso8601String(),
      'endDate': instance.endDate.toIso8601String(),
      'totalPrice': instance.totalPrice,
      'currency': instance.currency,
      'securityDeposit': instance.securityDeposit,
    };

UpdateAssetRequest _$UpdateAssetRequestFromJson(Map<String, dynamic> json) =>
    UpdateAssetRequest(
      title: json['title'] as String?,
      description: json['description'] as String?,
      category: json['category'] as String?,
      pricePerDay: (json['pricePerDay'] as num?)?.toDouble(),
      currency: json['currency'] as String?,
      isAvailable: json['isAvailable'] as bool?,
      location: json['location'] as String?,
    );

Map<String, dynamic> _$UpdateAssetRequestToJson(UpdateAssetRequest instance) =>
    <String, dynamic>{
      'title': instance.title,
      'description': instance.description,
      'category': instance.category,
      'pricePerDay': instance.pricePerDay,
      'currency': instance.currency,
      'isAvailable': instance.isAvailable,
      'location': instance.location,
    };

WalletConnection _$WalletConnectionFromJson(Map<String, dynamic> json) =>
    WalletConnection(
      address: json['address'] as String,
      chainId: json['chainId'] as String,
      networkName: json['networkName'] as String?,
      isConnected: json['isConnected'] as bool,
      connectedAt: json['connectedAt'] == null
          ? null
          : DateTime.parse(json['connectedAt'] as String),
    );

Map<String, dynamic> _$WalletConnectionToJson(WalletConnection instance) =>
    <String, dynamic>{
      'address': instance.address,
      'chainId': instance.chainId,
      'networkName': instance.networkName,
      'isConnected': instance.isConnected,
      'connectedAt': instance.connectedAt?.toIso8601String(),
    };

BlockchainTransaction _$BlockchainTransactionFromJson(
        Map<String, dynamic> json) =>
    BlockchainTransaction(
      hash: json['hash'] as String,
      from: json['from'] as String,
      to: json['to'] as String,
      value: json['value'] as String,
      gasUsed: json['gasUsed'] as String,
      gasPrice: json['gasPrice'] as String,
      status: json['status'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
    );

Map<String, dynamic> _$BlockchainTransactionToJson(
        BlockchainTransaction instance) =>
    <String, dynamic>{
      'hash': instance.hash,
      'from': instance.from,
      'to': instance.to,
      'value': instance.value,
      'gasUsed': instance.gasUsed,
      'gasPrice': instance.gasPrice,
      'status': instance.status,
      'timestamp': instance.timestamp.toIso8601String(),
    };

ErrorResponse _$ErrorResponseFromJson(Map<String, dynamic> json) =>
    ErrorResponse(
      message: json['message'] as String,
      code: json['code'] as String?,
      details: json['details'] as Map<String, dynamic>?,
    );

Map<String, dynamic> _$ErrorResponseToJson(ErrorResponse instance) =>
    <String, dynamic>{
      'message': instance.message,
      'code': instance.code,
      'details': instance.details,
    };

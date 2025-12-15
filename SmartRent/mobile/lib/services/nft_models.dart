/// NFT and Fractional Share Models for Flutter
library;

class NftAsset {
  final int tokenId;
  final String name;
  final String description;
  final String imageUrl;
  final String metadataUri;
  final int totalShares;
  final int availableShares;
  final double pricePerShare;
  final bool initialized;
  final Map<String, dynamic> attributes;

  NftAsset({
    required this.tokenId,
    required this.name,
    required this.description,
    required this.imageUrl,
    required this.metadataUri,
    required this.totalShares,
    required this.availableShares,
    this.pricePerShare = 0.0,
    required this.initialized,
    this.attributes = const {},
  });

  factory NftAsset.fromJson(Map<String, dynamic> json) {
    return NftAsset(
      tokenId: json['token_id'] ?? json['tokenId'] ?? 0,
      name: json['name'] ?? '',
      description: json['description'] ?? '',
      imageUrl: json['image_url'] ?? json['image'] ?? '',
      metadataUri: json['metadata_uri'] ?? json['metadataUri'] ?? '',
      totalShares: json['total_shares'] ?? json['totalShares'] ?? 0,
      availableShares: json['available_shares'] ?? json['availableShares'] ?? 0,
      pricePerShare: (json['price_per_share'] ?? json['pricePerShare'] ?? 0.0).toDouble(),
      initialized: json['initialized'] ?? false,
      attributes: (json['attributes'] as Map<String, dynamic>?) ?? {},
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'token_id': tokenId,
      'name': name,
      'description': description,
      'image_url': imageUrl,
      'metadata_uri': metadataUri,
      'total_shares': totalShares,
      'available_shares': availableShares,
      'price_per_share': pricePerShare,
      'initialized': initialized,
      'attributes': attributes,
    };
  }

  double get ownershipPercentage =>
      totalShares > 0 ? (availableShares / totalShares) * 100 : 0;
}

class UserNftHolding {
  final int tokenId;
  final String name;
  final String imageUrl;
  final int shares;
  final int totalShares;
  final double ownershipPercentage;
  final String estimatedValue;

  UserNftHolding({
    required this.tokenId,
    required this.name,
    required this.imageUrl,
    required this.shares,
    required this.totalShares,
    required this.ownershipPercentage,
    this.estimatedValue = '0',
  });

  factory UserNftHolding.fromJson(Map<String, dynamic> json) {
    final shares = json['shares'] ?? json['balance'] ?? 0;
    final totalShares = json['total_shares'] ?? json['totalShares'] ?? 1;

    return UserNftHolding(
      tokenId: json['token_id'] ?? 0,
      name: json['name'] ?? '',
      imageUrl: json['image_url'] ?? json['image'] ?? '',
      shares: shares,
      totalShares: totalShares,
      ownershipPercentage: (shares / totalShares) * 100,
      estimatedValue: json['estimated_value'] ?? '0',
    );
  }
}

class ShareListing {
  final String listingId;
  final int tokenId;
  final String seller;
  final int sharesAvailable;
  final double pricePerShare;
  final String totalPrice;
  final bool isActive;
  final DateTime? createdAt;

  ShareListing({
    required this.listingId,
    required this.tokenId,
    required this.seller,
    required this.sharesAvailable,
    required this.pricePerShare,
    required this.totalPrice,
    this.isActive = true,
    this.createdAt,
  });

  factory ShareListing.fromJson(Map<String, dynamic> json) {
    return ShareListing(
      listingId: json['listing_id'] ?? json['id'] ?? '',
      tokenId: json['token_id'] ?? 0,
      seller: json['seller'] ?? '',
      sharesAvailable: json['shares_available'] ?? json['amount'] ?? 0,
      pricePerShare: (json['price_per_share'] ?? 0.0).toDouble(),
      totalPrice: json['total_price'] ?? '0',
      isActive: json['is_active'] ?? json['active'] ?? true,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'listing_id': listingId,
      'token_id': tokenId,
      'seller': seller,
      'shares_available': sharesAvailable,
      'price_per_share': pricePerShare,
      'total_price': totalPrice,
      'is_active': isActive,
      'created_at': createdAt?.toIso8601String(),
    };
  }
}

class SharePurchaseRequest {
  final int tokenId;
  final String sellerAddress;
  final int shareAmount;
  final double pricePerShare;
  final String buyerAddress;

  SharePurchaseRequest({
    required this.tokenId,
    required this.sellerAddress,
    required this.shareAmount,
    required this.pricePerShare,
    required this.buyerAddress,
  });

  Map<String, dynamic> toJson() {
    return {
      'token_id': tokenId,
      'seller_address': sellerAddress,
      'share_amount': shareAmount,
      'price_per_share': pricePerShare,
      'buyer_address': buyerAddress,
    };
  }
}

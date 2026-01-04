/// Rental-related data models
class RentalListing {
  final int listingId;
  final int tokenId;
  final String owner;
  final String pricePerNight; // in POL
  final int createdAt;
  final bool isActive;
  
  // Additional info (fetched from metadata)
  final String? propertyName;
  final String? imageUrl;
  final int? totalShares;
  final int? ownerShares;
  final String? location;
  final String? activeDays;
  final Map<String, dynamic>? attributes;

  RentalListing({
    required this.listingId,
    required this.tokenId,
    required this.owner,
    required this.pricePerNight,
    required this.createdAt,
    required this.isActive,
    this.propertyName,
    this.imageUrl,
    this.totalShares,
    this.ownerShares,
    this.location,
    this.activeDays,
    this.attributes,
  });

  factory RentalListing.fromJson(Map<String, dynamic> json) {
    final attributes = (json['attributes'] as Map<String, dynamic>?) ?? {};
    
    // Extract location and activeDays from attributes
    String? location;
    String? activeDays;
    
    if (attributes.isNotEmpty) {
      location = attributes['location']?.toString() ?? 
                 attributes['Location']?.toString() ?? 
                 attributes['address']?.toString();
      
      activeDays = attributes['active_days']?.toString() ?? 
                   attributes['Active Days']?.toString() ?? 
                   attributes['activeDays']?.toString();
    }
    
    return RentalListing(
      listingId: int.tryParse(json['listing_id']?.toString() ?? '0') ?? 0,
      tokenId: int.tryParse(json['token_id']?.toString() ?? '0') ?? 0,
      owner: (json['owner'] ?? '').toString(),
      pricePerNight: (json['price_per_night'] ?? json['pricePerNight'] ?? json['price_per_night_pol'] ?? 0).toString(),
      createdAt: int.tryParse(json['created_at']?.toString() ?? '0') ?? 0,
      isActive: json['is_active'] == true || json['isActive'] == true,
      propertyName: json['property_name']?.toString() ?? json['name']?.toString(),
      imageUrl: json['image_url']?.toString() ?? json['image']?.toString(),
      totalShares: int.tryParse(json['total_shares']?.toString() ?? json['totalShares']?.toString() ?? '0'),
      ownerShares: int.tryParse(json['owner_shares']?.toString() ?? json['ownerShares']?.toString() ?? '0'),
      location: location,
      activeDays: activeDays,
      attributes: attributes,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'listing_id': listingId,
      'token_id': tokenId,
      'owner': owner,
      'price_per_night': pricePerNight,
      'created_at': createdAt,
      'is_active': isActive,
      'property_name': propertyName,
      'image_url': imageUrl,
      'total_shares': totalShares,
      'owner_shares': ownerShares,
      'location': location,
      'active_days': activeDays,
      'attributes': attributes,
    };
  }
}

enum RentalStatus {
  active,
  completed,
  cancelled,
}

class Rental {
  final int rentalId;
  final int listingId;
  final int tokenId;
  final String renter;
  final int checkInDate;
  final int checkOutDate;
  final String totalPrice; // in POL
  final int createdAt;
  final RentalStatus status;
  
  // Additional info
  final String? propertyName;
  final String? imageUrl;

  Rental({
    required this.rentalId,
    required this.listingId,
    required this.tokenId,
    required this.renter,
    required this.checkInDate,
    required this.checkOutDate,
    required this.totalPrice,
    required this.createdAt,
    required this.status,
    this.propertyName,
    this.imageUrl,
  });

  factory Rental.fromJson(Map<String, dynamic> json) {
    RentalStatus parseStatus(dynamic statusValue) {
      if (statusValue is String) {
        switch (statusValue.toLowerCase()) {
          case 'active':
            return RentalStatus.active;
          case 'completed':
            return RentalStatus.completed;
          case 'cancelled':
            return RentalStatus.cancelled;
          default:
            return RentalStatus.active;
        }
      } else if (statusValue is int) {
        // If it's an enum index from contract
        switch (statusValue) {
          case 0:
            return RentalStatus.active;
          case 1:
            return RentalStatus.completed;
          case 2:
            return RentalStatus.cancelled;
          default:
            return RentalStatus.active;
        }
      }
      return RentalStatus.active;
    }

    return Rental(
      rentalId: json['rental_id'] ?? json['rentalId'] ?? 0,
      listingId: json['listing_id'] ?? json['listingId'] ?? 0,
      tokenId: json['token_id'] ?? json['tokenId'] ?? 0,
      renter: json['renter'] ?? '',
      checkInDate: json['check_in_date'] ?? json['checkInDate'] ?? 0,
      checkOutDate: json['check_out_date'] ?? json['checkOutDate'] ?? 0,
      totalPrice: json['total_price']?.toString() ?? 
                  json['totalPrice']?.toString() ?? '0',
      createdAt: json['created_at'] ?? json['createdAt'] ?? 0,
      status: parseStatus(json['status']),
      propertyName: json['property_name'] ?? json['name'],
      imageUrl: json['image_url'] ?? json['image'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'rental_id': rentalId,
      'listing_id': listingId,
      'token_id': tokenId,
      'renter': renter,
      'check_in_date': checkInDate,
      'check_out_date': checkOutDate,
      'total_price': totalPrice,
      'created_at': createdAt,
      'status': status.name,
      'property_name': propertyName,
      'image_url': imageUrl,
    };
  }
  
  int get numberOfNights {
    return ((checkOutDate - checkInDate) / 86400).floor();
  }
  
  DateTime get checkInDateTime => DateTime.fromMillisecondsSinceEpoch(checkInDate * 1000);
  DateTime get checkOutDateTime => DateTime.fromMillisecondsSinceEpoch(checkOutDate * 1000);
}


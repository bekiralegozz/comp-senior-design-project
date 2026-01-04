import 'dart:convert';
import 'package:http/http.dart' as http;
import '../constants/config.dart';
import 'rental_models.dart';

/// Rental Service - Handles rental listing and booking operations
class RentalService {
  final String baseUrl = AppConfig.apiBaseUrl;

  // ============================================
  // RENTAL LISTINGS
  // ============================================

  /// Get all active rental listings
  Future<List<RentalListing>> getAllRentalListings() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/rental/listings'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((json) => RentalListing.fromJson(json)).toList();
      } else {
        print('Failed to load rental listings: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      print('Error fetching rental listings: $e');
      return [];
    }
  }

  /// Get rental listing by ID
  Future<RentalListing?> getRentalListing(int listingId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/rental/listings/$listingId'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        return RentalListing.fromJson(json.decode(response.body));
      } else if (response.statusCode == 404) {
        return null;
      } else {
        throw Exception('Failed to load rental listing');
      }
    } catch (e) {
      print('Error fetching rental listing $listingId: $e');
      return null;
    }
  }

  /// Get rental listings for a specific asset
  Future<List<RentalListing>> getRentalListingsByAsset(int tokenId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/rental/listings/asset/$tokenId'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((json) => RentalListing.fromJson(json)).toList();
      } else {
        return [];
      }
    } catch (e) {
      print('Error fetching rental listings for asset $tokenId: $e');
      return [];
    }
  }

  // ============================================
  // RENTAL BOOKINGS
  // ============================================

  /// Get all rentals (bookings) for a renter
  Future<List<Rental>> getRentalsByRenter(String renterAddress) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/rental/bookings/renter/$renterAddress'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((json) => Rental.fromJson(json)).toList();
      } else {
        return [];
      }
    } catch (e) {
      print('Error fetching rentals for $renterAddress: $e');
      return [];
    }
  }

  /// Get all rentals for a specific asset
  Future<List<Rental>> getRentalsByAsset(int tokenId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/rental/bookings/asset/$tokenId'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((json) => Rental.fromJson(json)).toList();
      } else {
        return [];
    }
    } catch (e) {
      print('Error fetching rentals for asset $tokenId: $e');
      return [];
    }
  }

  /// Get rental by ID
  Future<Rental?> getRental(int rentalId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/rental/bookings/$rentalId'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        return Rental.fromJson(json.decode(response.body));
      } else if (response.statusCode == 404) {
        return null;
      } else {
        throw Exception('Failed to load rental');
      }
    } catch (e) {
      print('Error fetching rental $rentalId: $e');
      return null;
    }
  }

  // ============================================
  // DATE AVAILABILITY
  // ============================================

  /// Check if dates are available for a listing
  Future<bool> checkDateAvailability({
    required int listingId,
    required int checkInDate,
    required int checkOutDate,
  }) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/rental/listings/$listingId/dates/available?'
            'check_in=$checkInDate&check_out=$checkOutDate'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['available'] ?? false;
      } else {
        return false;
      }
    } catch (e) {
      print('Error checking date availability: $e');
      return false;
    }
  }

  /// Get booked dates for a listing
  Future<List<int>> getBookedDates(int listingId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/rental/listings/$listingId/dates/booked'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = json.decode(response.body);
        final List<dynamic> bookedDates = responseData['booked_dates'] ?? [];
        return bookedDates.map((timestamp) => int.tryParse(timestamp.toString()) ?? 0).toList();
      } else {
        return [];
      }
    } catch (e) {
      print('Error fetching booked dates: $e');
      return [];
    }
  }

  // ============================================
  // TRANSACTION PREPARATION
  // ============================================

  /// Prepare create rental listing transaction
  Future<Map<String, dynamic>> prepareCreateRentalListing({
    required int tokenId,
    required double pricePerNightPol,
    required String ownerAddress,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/rental/listings/prepare'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'token_id': tokenId,
          'price_per_night_pol': pricePerNightPol,
          'owner_address': ownerAddress,
        }),
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Failed to prepare rental listing: ${response.body}');
      }
    } catch (e) {
      print('Error preparing rental listing: $e');
      rethrow;
    }
  }

  /// Prepare rent asset transaction
  Future<Map<String, dynamic>> prepareRentAsset({
    required int listingId,
    required int checkInDate,
    required int checkOutDate,
    required String renterAddress,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/rental/bookings/prepare'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'listing_id': listingId,
          'check_in_date': checkInDate,
          'check_out_date': checkOutDate,
          'renter_address': renterAddress,
        }),
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Failed to prepare rental booking: ${response.body}');
      }
    } catch (e) {
      print('Error preparing rental booking: $e');
      rethrow;
    }
  }

  /// Prepare cancel rental listing transaction
  Future<Map<String, dynamic>> prepareCancelRentalListing(int listingId) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/rental/listings/$listingId/cancel/prepare'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Failed to prepare cancel rental listing: ${response.body}');
      }
    } catch (e) {
      print('Error preparing cancel rental listing: $e');
      rethrow;
    }
  }

  // ============================================
  // HELPER FUNCTIONS
  // ============================================

  /// Check if user is majority shareholder of an asset
  Future<bool> isMajorityShareholder({
    required int tokenId,
    required String address,
  }) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/rental/majority-shareholder/$tokenId'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final majorityHolder = data['majority_shareholder']?.toString().toLowerCase();
        return majorityHolder == address.toLowerCase();
      } else {
        return false;
      }
    } catch (e) {
      print('Error checking majority shareholder: $e');
      return false;
    }
  }
}


import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../constants/config.dart';

/// API Service for communicating with SmartRent backend
/// 
/// MIGRATION NOTE: This service is being refactored for blockchain-first architecture.
/// Database-dependent endpoints have been removed. Only blockchain and SIWE auth remain.
class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  Dio? _dio;
  String? _jwtToken; // JWT token from SIWE authentication
  bool _initialized = false;

  /// Get the Dio instance, initializing if necessary
  Dio get dio {
    if (_dio == null) {
      throw StateError('ApiService must be initialized before use. Call initialize() first.');
    }
    return _dio!;
  }

  /// Initialize the API service
  Future<void> initialize() async {
    // Prevent multiple initializations
    if (_initialized && _dio != null) {
      return;
    }

    _dio = Dio(BaseOptions(
      baseUrl: AppConfig.apiBaseUrl,
      connectTimeout: AppConfig.apiTimeout,
      receiveTimeout: AppConfig.apiTimeout,
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ));

    // Add interceptors
    _dio!.interceptors.add(_AuthInterceptor());
    if (kDebugMode) {
      _dio!.interceptors.add(LogInterceptor(
        requestBody: true,
        responseBody: true,
        requestHeader: false,
        responseHeader: false,
      ));
    }

    // Load stored JWT token
    await _loadJwtToken();
    
    _initialized = true;
  }

  /// Load JWT token from storage
  Future<void> _loadJwtToken() async {
    final prefs = await SharedPreferences.getInstance();
    _jwtToken = prefs.getString('jwt_token');
    if (_jwtToken != null && _dio != null) {
      _dio!.options.headers['Authorization'] = 'Bearer $_jwtToken';
    }
  }

  /// Save JWT token to storage
  Future<void> _saveJwtToken(String token) async {
    _jwtToken = token;
    dio.options.headers['Authorization'] = 'Bearer $token';

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('jwt_token', token);
  }

  /// Clear stored JWT token
  Future<void> clearSession() async {
    _jwtToken = null;
    if (_dio != null) {
      dio.options.headers.remove('Authorization');
    }
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('jwt_token');
    await prefs.remove('wallet_address');
  }

  // ============================================
  // SIWE AUTHENTICATION ENDPOINTS
  // ============================================

  /// Get nonce for SIWE authentication
  Future<Map<String, dynamic>> getNonce(String walletAddress) async {
    try {
      final response = await dio.get(
        '/auth/nonce',
        queryParameters: {'address': walletAddress},
      );
      return response.data as Map<String, dynamic>;
    } catch (e) {
      throw _handleError(e);
    }
  }

  /// Verify SIWE signature and get JWT token
  Future<Map<String, dynamic>> verifySignature({
    required String message,
    required String signature,
    required String address,
  }) async {
    try {
      // Extract nonce from the SIWE message
      final nonceMatch = RegExp(r'Nonce: ([a-f0-9]+)', caseSensitive: false).firstMatch(message);
      if (nonceMatch == null) {
        throw Exception('Could not extract nonce from message');
      }
      final nonce = nonceMatch.group(1)!;
      
      final response = await dio.post(
        '/auth/verify',
        data: {
          'message': message,
          'signature': signature,
          'nonce': nonce, // Add nonce field
        },
      );
      
      final data = response.data as Map<String, dynamic>;
      
      // Save JWT token
      if (data.containsKey('access_token')) {
        await _saveJwtToken(data['access_token'] as String);
      }
      
      return data;
    } catch (e) {
      throw _handleError(e);
    }
  }

  /// Get current authenticated user info
  Future<Map<String, dynamic>> getMe() async {
    try {
      final response = await dio.get('/auth/me');
      return response.data as Map<String, dynamic>;
    } catch (e) {
      throw _handleError(e);
    }
  }

  /// Logout (client-side JWT removal)
  Future<void> logout() async {
    try {
      await dio.post('/auth/logout');
    } catch (e) {
      // Ignore errors, clear session anyway
      if (kDebugMode) {
        print('Logout error (non-critical): $e');
      }
    } finally {
      await clearSession();
    }
  }

  // ============================================
  // NFT MINT ENDPOINTS
  // ============================================

  /// Prepare NFT mint (IPFS upload, transaction data)
  Future<Map<String, dynamic>> prepareMint({
    required int tokenId,
    required String ownerAddress,
    required int totalShares,
    required String assetName,
    required String description,
    required String imageUrl,
    String propertyType = 'Apartment',
    int? bedrooms,
    String? location,
    int? squareFeet,
    String? address,
  }) async {
    try {
      final response = await dio.post(
        '/nft/prepare-mint',
        data: {
          'token_id': tokenId,
          'owner_address': ownerAddress,
          'total_shares': totalShares,
          'asset_name': assetName,
          'description': description,
          'image_url': imageUrl,
          'property_type': propertyType,
          if (bedrooms != null) 'bedrooms': bedrooms,
          if (location != null) 'location': location,
          if (squareFeet != null) 'square_feet': squareFeet,
          if (address != null) 'address': address,
        },
      );

      return response.data as Map<String, dynamic>;
    } catch (e) {
      throw ApiException(
        'Failed to prepare mint: ${e.toString()}',
        type: ApiExceptionType.unknown,
      );
    }
  }

  /// Confirm NFT mint after user signs transaction
  Future<Map<String, dynamic>> confirmMint({
    required int tokenId,
    required String transactionHash,
    required String ownerAddress,
  }) async {
    try {
      final response = await dio.post(
        '/nft/confirm-mint',
        data: {
          'token_id': tokenId,
          'transaction_hash': transactionHash,
          'owner_address': ownerAddress,
        },
      );

      return response.data as Map<String, dynamic>;
    } catch (e) {
      throw ApiException(
        'Failed to confirm mint: ${e.toString()}',
        type: ApiExceptionType.unknown,
      );
    }
  }

  /// Get NFT assets (optionally filtered by owner)
  Future<Map<String, dynamic>> getNftAssets({
    String? ownerAddress,
    int limit = 20,
    int offset = 0,
  }) async {
    try {
      final queryParams = {
        'limit': limit.toString(),
        'offset': offset.toString(),
        if (ownerAddress != null) 'owner_address': ownerAddress,
      };

      final response = await dio.get(
        '/nft/assets',
        queryParameters: queryParams,
      );

      return response.data as Map<String, dynamic>;
    } catch (e) {
      throw ApiException(
        'Failed to get NFT assets: ${e.toString()}',
        type: ApiExceptionType.unknown,
      );
    }
  }

  // ============================================
  // USER HOLDINGS
  // ============================================

  /// Get user's NFT holdings from SmartRentHub
  Future<List<dynamic>> getUserHoldings(String walletAddress) async {
    try {
      final response = await dio.get('/nft/holdings/$walletAddress');
      return response.data as List<dynamic>;
    } catch (e) {
      throw ApiException(
        'Failed to get holdings: ${e.toString()}',
        type: ApiExceptionType.unknown,
      );
    }
  }

  // ============================================
  // MARKETPLACE ENDPOINTS (SmartRentHub)
  // ============================================

  /// Get all active marketplace listings
  Future<Map<String, dynamic>> getListings() async {
    try {
      final response = await dio.get('/nft/listings');
      return response.data as Map<String, dynamic>;
    } catch (e) {
      throw ApiException(
        'Failed to get listings: ${e.toString()}',
        type: ApiExceptionType.unknown,
      );
    }
  }

  /// Get single listing details
  Future<Map<String, dynamic>> getListing(int listingId) async {
    try {
      final response = await dio.get('/nft/listings/$listingId');
      return response.data as Map<String, dynamic>;
    } catch (e) {
      throw ApiException(
        'Failed to get listing: ${e.toString()}',
        type: ApiExceptionType.unknown,
      );
    }
  }

  /// Get listings by seller
  Future<Map<String, dynamic>> getMyListings(String sellerAddress) async {
    try {
      final response = await dio.get('/nft/listings/seller/$sellerAddress');
      return response.data as Map<String, dynamic>;
    } catch (e) {
      throw ApiException(
        'Failed to get my listings: ${e.toString()}',
        type: ApiExceptionType.unknown,
      );
    }
  }

  /// Prepare createListing transaction
  Future<Map<String, dynamic>> prepareCreateListing({
    required int tokenId,
    required int sharesForSale,
    required double pricePerSharePol,
  }) async {
    try {
      final response = await dio.post(
        '/nft/listings/prepare-create',
        data: {
          'token_id': tokenId,
          'shares_for_sale': sharesForSale,
          'price_per_share_pol': pricePerSharePol,
        },
      );
      return response.data as Map<String, dynamic>;
    } catch (e) {
      throw ApiException(
        'Failed to prepare listing: ${e.toString()}',
        type: ApiExceptionType.unknown,
      );
    }
  }

  /// Prepare cancelListing transaction
  Future<Map<String, dynamic>> prepareCancelListing(int listingId) async {
    try {
      final response = await dio.post(
        '/nft/listings/prepare-cancel',
        queryParameters: {'listing_id': listingId},
      );
      return response.data as Map<String, dynamic>;
    } catch (e) {
      throw ApiException(
        'Failed to prepare cancel: ${e.toString()}',
        type: ApiExceptionType.unknown,
      );
    }
  }

  /// Prepare buyFromListing transaction
  Future<Map<String, dynamic>> prepareBuyListing({
    required int listingId,
    required int sharesToBuy,
  }) async {
    try {
      final response = await dio.post(
        '/nft/listings/prepare-buy',
        data: {
          'listing_id': listingId,
          'shares_to_buy': sharesToBuy,
        },
      );
      return response.data as Map<String, dynamic>;
    } catch (e) {
      throw ApiException(
        'Failed to prepare buy: ${e.toString()}',
        type: ApiExceptionType.unknown,
      );
    }
  }

  /// Check if wallet has approved SmartRentHub
  Future<bool> checkApproval(String walletAddress) async {
    try {
      final response = await dio.get('/nft/approval/check/$walletAddress');
      return response.data['is_approved'] ?? false;
    } catch (e) {
      throw ApiException(
        'Failed to check approval: ${e.toString()}',
        type: ApiExceptionType.unknown,
      );
    }
  }

  /// Prepare approval transaction
  Future<Map<String, dynamic>> prepareApproval() async {
    try {
      final response = await dio.post('/nft/approval/prepare');
      return response.data as Map<String, dynamic>;
    } catch (e) {
      throw ApiException(
        'Failed to prepare approval: ${e.toString()}',
        type: ApiExceptionType.unknown,
      );
    }
  }

  /// Check if asset is registered in SmartRentHub
  Future<bool> isAssetRegistered(int tokenId) async {
    try {
      final response = await dio.get('/nft/assets/$tokenId/is-registered');
      return response.data['is_registered'] ?? false;
    } catch (e) {
      throw ApiException(
        'Failed to check asset registration: ${e.toString()}',
        type: ApiExceptionType.unknown,
      );
    }
  }

  /// Prepare asset registration transaction
  Future<Map<String, dynamic>> prepareRegisterAsset({
    required int tokenId,
    required String owner,
  }) async {
    try {
      final response = await dio.post(
        '/nft/assets/prepare-register',
        queryParameters: {
          'token_id': tokenId,
          'owner': owner,
        },
      );
      return response.data as Map<String, dynamic>;
    } catch (e) {
      throw ApiException(
        'Failed to prepare asset registration: ${e.toString()}',
        type: ApiExceptionType.unknown,
      );
    }
  }

  /// Check transaction status
  Future<Map<String, dynamic>> getTransactionStatus(String txHash) async {
    try {
      final response = await dio.get('/nft/transaction/status/$txHash');
      return response.data as Map<String, dynamic>;
    } catch (e) {
      throw ApiException(
        'Failed to get transaction status: ${e.toString()}',
        type: ApiExceptionType.unknown,
      );
    }
  }

  /// Wait for transaction to be mined (polls every 2 seconds, max 60 seconds)
  Future<bool> waitForTransaction(String txHash, {int maxWaitSeconds = 60}) async {
    final maxAttempts = maxWaitSeconds ~/ 2;
    
    for (int i = 0; i < maxAttempts; i++) {
      await Future.delayed(const Duration(seconds: 2));
      
      try {
        final status = await getTransactionStatus(txHash);
        
        if (status['mined'] == true) {
          return status['success'] == true;
        }
      } catch (e) {
        // Continue waiting if there's an error
        continue;
      }
    }
    
    // Timeout
    throw ApiException(
      'Transaction not mined after $maxWaitSeconds seconds',
      type: ApiExceptionType.timeout,
    );
  }

  // ============================================
  // HEALTH CHECK
  // ============================================

  Future<Map<String, dynamic>> ping() async {
    try {
      final response = await dio.get('/ping');
      return response.data;
    } catch (e) {
      throw _handleError(e);
    }
  }

  // ============================================
  // ERROR HANDLING
  // ============================================

  /// Handle API errors
  ApiException _handleError(dynamic error) {
    if (error is DioException) {
      switch (error.type) {
        case DioExceptionType.connectionTimeout:
        case DioExceptionType.receiveTimeout:
        case DioExceptionType.sendTimeout:
          return ApiException(
            'Connection timeout. Please check your internet connection.',
            type: ApiExceptionType.timeout,
          );
        
        case DioExceptionType.connectionError:
          if (error.response != null) {
            final statusCode = error.response?.statusCode;
            final data = error.response?.data;
            
            String message = 'An error occurred';
            
            if (data is Map<String, dynamic>) {
              if (data.containsKey('detail')) {
                final detail = data['detail'];
                if (detail is String) {
                  message = detail;
                } else if (detail is Map<String, dynamic> && detail.containsKey('message')) {
                  message = detail['message'].toString();
                }
              } else if (data.containsKey('message')) {
                message = data['message'].toString();
              } else if (data.containsKey('error')) {
                message = data['error'].toString();
              }
            } else if (data is String) {
              message = data;
            }
            
            return ApiException(
              message,
              statusCode: statusCode,
              type: _getExceptionType(statusCode),
            );
          }
          return ApiException(
            'Network error occurred',
            type: ApiExceptionType.network,
          );
        
        case DioExceptionType.badResponse:
          final statusCode = error.response?.statusCode;
          final data = error.response?.data;
          
          String message = 'An error occurred';
          
          if (data is Map<String, dynamic>) {
            if (data.containsKey('detail')) {
              final detail = data['detail'];
              if (detail is String) {
                message = detail;
              } else if (detail is Map<String, dynamic> && detail.containsKey('message')) {
                message = detail['message'].toString();
              }
            } else if (data.containsKey('message')) {
              message = data['message'].toString();
            } else if (data.containsKey('error')) {
              message = data['error'].toString();
            }
          } else if (data is String) {
            message = data;
          }
          
          return ApiException(
            message,
            statusCode: statusCode,
            type: _getExceptionType(statusCode),
          );
        
        case DioExceptionType.cancel:
          return ApiException(
            'Request was cancelled',
            type: ApiExceptionType.cancelled,
          );
        
        default:
          return ApiException(
            'Network error occurred',
            type: ApiExceptionType.network,
          );
      }
    }
    
    return ApiException(
      error.toString(),
      type: ApiExceptionType.unknown,
    );
  }

  ApiExceptionType _getExceptionType(int? statusCode) {
    switch (statusCode) {
      case 400:
        return ApiExceptionType.badRequest;
      case 401:
        return ApiExceptionType.unauthorized;
      case 403:
        return ApiExceptionType.forbidden;
      case 404:
        return ApiExceptionType.notFound;
      case 500:
        return ApiExceptionType.serverError;
      default:
        return ApiExceptionType.unknown;
    }
  }
}

/// Authentication interceptor
class _AuthInterceptor extends Interceptor {
  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (err.response?.statusCode == 401) {
      // Handle token expiration
      unawaited(ApiService().clearSession());
    }
    super.onError(err, handler);
  }
}

/// API Exception types
enum ApiExceptionType {
  timeout,
  network,
  badRequest,
  unauthorized,
  forbidden,
  notFound,
  serverError,
  cancelled,
  unknown,
}

/// Custom API exception
class ApiException implements Exception {
  final String message;
  final int? statusCode;
  final ApiExceptionType type;

  ApiException(
    this.message, {
    this.statusCode,
    required this.type,
  });

  @override
  String toString() => 'ApiException: $message';
}

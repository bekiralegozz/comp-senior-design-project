import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../constants/config.dart';
import 'models.dart';

/// API Service for communicating with SmartRent backend
class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  late final Dio _dio;
  String? _accessToken;
  String? _refreshToken;

  /// Initialize the API service
  Future<void> initialize() async {
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
    _dio.interceptors.add(_AuthInterceptor());
    if (kDebugMode) {
      _dio.interceptors.add(LogInterceptor(
        requestBody: true,
        responseBody: true,
        requestHeader: false,
        responseHeader: false,
      ));
    }

    // Load stored auth token
    await _loadAuthToken();
  }

  /// Load authentication token from storage
  Future<void> _loadAuthToken() async {
    final prefs = await SharedPreferences.getInstance();
    _accessToken = prefs.getString('auth_token');
    _refreshToken = prefs.getString('refresh_token');
    if (_accessToken != null) {
      _dio.options.headers['Authorization'] = 'Bearer $_accessToken';
    }
  }

  Future<void> _persistSession(AuthSession session) async {
    _accessToken = session.accessToken;
    _refreshToken = session.refreshToken;
    _dio.options.headers['Authorization'] = 'Bearer ${session.accessToken}';

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_token', session.accessToken);
    await prefs.setString('refresh_token', session.refreshToken);
  }

  /// Clear stored authentication session
  Future<void> clearSession() async {
    _accessToken = null;
    _refreshToken = null;
    _dio.options.headers.remove('Authorization');
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
    await prefs.remove('refresh_token');
  }

  /// Attempt to restore session using stored refresh token
  Future<AuthSession?> restoreSession() async {
    if (_refreshToken == null) {
      final prefs = await SharedPreferences.getInstance();
      _refreshToken = prefs.getString('refresh_token');
    }
    if (_refreshToken == null) {
      return null;
    }

    try {
      return await refreshSession();
    } catch (_) {
      await clearSession();
      return null;
    }
  }

  /// Login with email and password
  Future<AuthSession> loginWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _dio.post(
        '/auth/login',
        data: {
          'email': email,
          'password': password,
        },
      );
      final session = AuthSession.fromJson(response.data as Map<String, dynamic>);
      await _persistSession(session);
      return session;
    } catch (e) {
      throw _handleError(e);
    }
  }

  /// Sign up a new user (email/password)
  Future<SignupResponse> signup({
    required String email,
    required String password,
    String? fullName,
    String? walletAddress,
    String? avatarUrl,
  }) async {
    try {
      final response = await _dio.post(
        '/auth/signup',
        data: {
          'email': email,
          'password': password,
          if (fullName != null && fullName.isNotEmpty) 'full_name': fullName,
          if (walletAddress != null && walletAddress.isNotEmpty) 'wallet_address': walletAddress,
          if (avatarUrl != null && avatarUrl.isNotEmpty) 'avatar_url': avatarUrl,
        },
      );
      return SignupResponse.fromJson(response.data as Map<String, dynamic>);
    } catch (e) {
      throw _handleError(e);
    }
  }

  /// Refresh session using stored refresh token
  Future<AuthSession> refreshSession({String? refreshToken}) async {
    final token = refreshToken ?? _refreshToken;
    if (token == null || token.isEmpty) {
      throw ApiException(
        'Refresh token missing',
        type: ApiExceptionType.unauthorized,
      );
    }

    try {
      final response = await _dio.post(
        '/auth/refresh',
        data: {'refresh_token': token},
        options: Options(
          headers: {
            'Authorization': null,
          },
        ),
      );
      final session = AuthSession.fromJson(response.data as Map<String, dynamic>);
      await _persistSession(session);
      return session;
    } catch (e) {
      throw _handleError(e);
    }
  }

  /// Logout and revoke refresh token
  Future<void> logout({String? refreshToken}) async {
    try {
      await _dio.post(
        '/auth/logout',
        data: {
          'refresh_token': refreshToken ?? _refreshToken,
        },
      );
    } catch (e) {
      // Swallow unauthorized errors on logout
      final error = _handleError(e);
      if (error.type != ApiExceptionType.unauthorized) {
        throw error;
      }
    } finally {
      await clearSession();
    }
  }

  /// Request password reset email
  Future<void> requestPasswordReset(String email, {String? redirectTo}) async {
    try {
      await _dio.post(
        '/auth/password/reset',
        data: {
          'email': email,
          if (redirectTo != null && redirectTo.isNotEmpty)
            'redirect_to': redirectTo,
        },
      );
    } catch (e) {
      throw _handleError(e);
    }
  }

  /// Confirm password reset with token
  Future<void> confirmPasswordReset({
    required String accessToken,
    required String newPassword,
  }) async {
    try {
      await _dio.post(
        '/auth/password/reset/confirm',
        data: {
          'access_token': accessToken,
          'new_password': newPassword,
        },
      );
    } catch (e) {
      throw _handleError(e);
    }
  }

  /// Request a magic link / OTP email
  Future<void> sendMagicLink(String email, {String? redirectTo}) async {
    try {
      await _dio.post(
        '/auth/magic-link',
        data: {
          'email': email,
          if (redirectTo != null && redirectTo.isNotEmpty)
            'redirect_to': redirectTo,
        },
      );
    } catch (e) {
      throw _handleError(e);
    }
  }

  // Health Check
  Future<Map<String, dynamic>> ping() async {
    try {
      final response = await _dio.get('/ping');
      return response.data;
    } catch (e) {
      throw _handleError(e);
    }
  }

  // User endpoints
  Future<List<User>> getUsers({int skip = 0, int limit = 20}) async {
    try {
      final response = await _dio.get('/users/', queryParameters: {
        'skip': skip,
        'limit': limit,
      });
      
      return (response.data as List)
          .map((json) => User.fromJson(json))
          .toList();
    } catch (e) {
      throw _handleError(e);
    }
  }

  Future<User> getUser(int userId) async {
    try {
      final response = await _dio.get('/users/$userId');
      return User.fromJson(response.data);
    } catch (e) {
      throw _handleError(e);
    }
  }

  Future<User> getUserByWallet(String walletAddress) async {
    try {
      final response = await _dio.get('/users/wallet/$walletAddress');
      return User.fromJson(response.data);
    } catch (e) {
      throw _handleError(e);
    }
  }

  Future<User> createUser(CreateUserRequest request) async {
    try {
      final response = await _dio.post('/users/', data: request.toJson());
      return User.fromJson(response.data);
    } catch (e) {
      throw _handleError(e);
    }
  }

  Future<User> updateUser(int userId, Map<String, dynamic> updates) async {
    try {
      final response = await _dio.put('/users/$userId', data: updates);
      return User.fromJson(response.data);
    } catch (e) {
      throw _handleError(e);
    }
  }

  // Asset endpoints
  Future<List<Asset>> getAssets({
    int skip = 0,
    int limit = 20,
    String? category,
    bool availableOnly = true,
  }) async {
    try {
      final response = await _dio.get('/assets/', queryParameters: {
        'skip': skip,
        'limit': limit,
        if (category != null) 'category': category,
        'available_only': availableOnly,
      });
      
      return (response.data as List)
          .map((json) => Asset.fromJson(json))
          .toList();
    } catch (e) {
      throw _handleError(e);
    }
  }

  Future<Asset> getAsset(int assetId) async {
    try {
      final response = await _dio.get('/assets/$assetId');
      return Asset.fromJson(response.data);
    } catch (e) {
      throw _handleError(e);
    }
  }

  Future<List<Asset>> getAssetsByOwner(int ownerId) async {
    try {
      final response = await _dio.get('/assets/owner/$ownerId');
      return (response.data as List)
          .map((json) => Asset.fromJson(json))
          .toList();
    } catch (e) {
      throw _handleError(e);
    }
  }

  Future<List<String>> getAssetCategories() async {
    try {
      final response = await _dio.get('/assets/categories/');
      return List<String>.from(response.data);
    } catch (e) {
      throw _handleError(e);
    }
  }

  Future<Asset> createAsset(CreateAssetRequest request) async {
    try {
      final response = await _dio.post('/assets/', data: request.toJson());
      return Asset.fromJson(response.data);
    } catch (e) {
      throw _handleError(e);
    }
  }

  Future<Asset> updateAsset(int assetId, UpdateAssetRequest request) async {
    try {
      final response = await _dio.put('/assets/$assetId', data: request.toJson());
      return Asset.fromJson(response.data);
    } catch (e) {
      throw _handleError(e);
    }
  }

  Future<Asset> toggleAssetAvailability(int assetId) async {
    try {
      final response = await _dio.post('/assets/$assetId/toggle-availability');
      return Asset.fromJson(response.data);
    } catch (e) {
      throw _handleError(e);
    }
  }

  // Rental endpoints
  Future<List<Rental>> getRentals({
    int skip = 0,
    int limit = 20,
    String? status,
    int? renterId,
    int? assetId,
  }) async {
    try {
      final response = await _dio.get('/rentals/', queryParameters: {
        'skip': skip,
        'limit': limit,
        if (status != null) 'status_filter': status,
        if (renterId != null) 'renter_id': renterId,
        if (assetId != null) 'asset_id': assetId,
      });
      
      return (response.data as List)
          .map((json) => Rental.fromJson(json))
          .toList();
    } catch (e) {
      throw _handleError(e);
    }
  }

  Future<Rental> getRental(int rentalId) async {
    try {
      final response = await _dio.get('/rentals/$rentalId');
      return Rental.fromJson(response.data);
    } catch (e) {
      throw _handleError(e);
    }
  }

  Future<List<Rental>> getRentalsByUser(int userId) async {
    try {
      final response = await _dio.get('/rentals/user/$userId');
      return (response.data as List)
          .map((json) => Rental.fromJson(json))
          .toList();
    } catch (e) {
      throw _handleError(e);
    }
  }

  Future<Rental> createRental(CreateRentalRequest request) async {
    try {
      final response = await _dio.post('/rentals/', data: request.toJson());
      return Rental.fromJson(response.data);
    } catch (e) {
      throw _handleError(e);
    }
  }

  Future<Rental> activateRental(int rentalId) async {
    try {
      final response = await _dio.post('/rentals/$rentalId/activate');
      return Rental.fromJson(response.data);
    } catch (e) {
      throw _handleError(e);
    }
  }

  Future<Rental> completeRental(int rentalId) async {
    try {
      final response = await _dio.post('/rentals/$rentalId/complete');
      return Rental.fromJson(response.data);
    } catch (e) {
      throw _handleError(e);
    }
  }

  Future<Rental> cancelRental(int rentalId) async {
    try {
      final response = await _dio.post('/rentals/$rentalId/cancel');
      return Rental.fromJson(response.data);
    } catch (e) {
      throw _handleError(e);
    }
  }

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
        
        case DioExceptionType.badResponse:
          final statusCode = error.response?.statusCode;
          final data = error.response?.data;
          
          String message = 'An error occurred';
          if (data is Map<String, dynamic> && data.containsKey('message')) {
            message = data['message'].toString();
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









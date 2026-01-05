import 'package:flutter/material.dart';

/// Application configuration constants
class AppConfig {
  // API Configuration - Railway Production Backend
  static const String baseUrl = 'https://lucky-beauty-production-e86e.up.railway.app';
  static const String apiVersion = 'v1';
  static const String apiBaseUrl = '$baseUrl/api/$apiVersion';
  
  // Blockchain Configuration - Polygon Mainnet
  static const String chainId = '137'; // Polygon Mainnet
  static const String rpcUrl = 'https://polygon-rpc.com';
  static const String polygonRpcUrl = rpcUrl; // Alias for clarity
  static const String wsUrl = 'wss://polygon-rpc.com';
  static const String web3ProviderUrl = rpcUrl;
  static const String networkName = 'Polygon';
  static const String currencySymbol = 'POL'; // Formerly MATIC, rebranded to POL
  
  // WalletConnect Configuration (Reown Cloud)
  static const String walletConnectProjectId = '64487c9584d97c90e3f9e60387c1a6cb';
  
  // Contract Addresses (FINAL DEPLOYMENT - 2026-01-04 - ALL BUGS FIXED)
  static const String building1122Contract = '0xC1BaB914b2ad7762E9174c7BD76cf48884F48B9c';
  static const String smartRentHubContract = '0x1bd8D0f166A53d6173E549B408a76625404d8CB6';
  static const String rentalHubContract = '0x1240d30b7fBa73F1Ad5C15ecb6f2eF30AD2e9008';
  static const String rentalManagerContract = '0xD10fcf5dC4188C688634865b6A89776b9ED57358';
  
  // Legacy contract names (for backward compatibility)
  static const String assetTokenContract = building1122Contract;
  static const String rentalAgreementContract = rentalManagerContract;
  static const String marketplaceContract = smartRentHubContract; // SmartRentHub handles marketplace
  
  // App Configuration
  static const String appName = 'SmartRent';
  static const String appVersion = '1.0.0';
  static const Duration apiTimeout = Duration(seconds: 60);
  
  // Pagination
  static const int defaultPageSize = 20;
  static const int maxPageSize = 100;
  
  // Image Configuration
  static const int maxImageSizeMB = 10;
  static const List<String> allowedImageTypes = ['jpg', 'jpeg', 'png', 'webp'];
  
  // Currency
  static const String defaultCurrency = 'ETH';
  static const List<String> supportedCurrencies = ['ETH', 'USD', 'EUR'];
  
  // Cache Duration
  static const Duration cacheDuration = Duration(hours: 1);
}

/// Application color scheme
class AppColors {
  static const Color primary = Color(0xFF2196F3);
  static const Color primaryVariant = Color(0xFF1976D2);
  static const Color secondary = Color(0xFF03DAC6);
  static const Color secondaryVariant = Color(0xFF018786);
  
  static const Color surface = Color(0xFFFFFFFF);
  static const Color background = Color(0xFFF5F5F5);
  static const Color error = Color(0xFFB00020);
  
  static const Color onPrimary = Color(0xFFFFFFFF);
  static const Color onSecondary = Color(0xFF000000);
  static const Color onSurface = Color(0xFF000000);
  static const Color onBackground = Color(0xFF000000);
  static const Color onError = Color(0xFFFFFFFF);
  
  // Text colors
  static const Color textPrimary = Color(0xFF000000);
  static const Color textSecondary = Color(0xFF666666);
  
  // Custom colors
  static const Color success = Color(0xFF4CAF50);
  static const Color warning = Color(0xFFFF9800);
  static const Color info = Color(0xFF2196F3);
  static const Color grey = Color(0xFF9E9E9E);
  static const Color darkGrey = Color(0xFF424242);
  static const Color lightGrey = Color(0xFFF5F5F5);
  
  // Status colors
  static const Color activeRental = Color(0xFF4CAF50);
  static const Color pendingRental = Color(0xFFFF9800);
  static const Color completedRental = Color(0xFF9E9E9E);
  static const Color cancelledRental = Color(0xFFB00020);
  
  // Asset category colors
  static const Map<String, Color> categoryColors = {
    'vehicles': Color(0xFF2196F3),
    'electronics': Color(0xFF9C27B0),
    'tools': Color(0xFFFF9800),
    'furniture': Color(0xFF795548),
    'sports': Color(0xFF4CAF50),
    'books': Color(0xFF607D8B),
    'clothing': Color(0xFFE91E63),
    'other': Color(0xFF9E9E9E),
  };
}

/// Application text styles
class AppTextStyles {
  static const TextStyle h1 = TextStyle(
    fontSize: 32,
    fontWeight: FontWeight.bold,
  );
  
  static const TextStyle h2 = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.w600,
  );
  
  static const TextStyle h3 = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w600,
  );
  
  static const TextStyle h4 = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w600,
  );
  
  static const TextStyle h5 = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w500,
  );
  
  static const TextStyle h6 = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w500,
  );
  
  static const TextStyle body1 = TextStyle(
    fontSize: 16,
  );
  
  static const TextStyle body2 = TextStyle(
    fontSize: 14,
  );
  
  static const TextStyle caption = TextStyle(
    fontSize: 12,
    color: AppColors.grey,
  );
  
  static const TextStyle button = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
  );
  
  // Custom text styles
  static const TextStyle price = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.bold,
    color: AppColors.primary,
  );
  
  static const TextStyle assetTitle = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w600,
  );
  
  static const TextStyle assetCategory = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    color: AppColors.grey,
  );
}

/// Application spacing constants
class AppSpacing {
  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 16.0;
  static const double lg = 24.0;
  static const double xl = 32.0;
  static const double xxl = 48.0;
}

/// Application border radius constants
class AppRadius {
  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 12.0;
  static const double lg = 16.0;
  static const double xl = 20.0;
  static const double round = 50.0;
}

/// Application duration constants
class AppDurations {
  static const Duration fast = Duration(milliseconds: 200);
  static const Duration medium = Duration(milliseconds: 300);
  static const Duration slow = Duration(milliseconds: 500);
}

/// Asset categories
class AssetCategories {
  static const List<String> all = [
    'housing',
    'vehicles',
    'electronics',
    'tools',
    'furniture',
    'sports',
    'books',
    'clothing',
    'other',
  ];
  
  static const Map<String, IconData> icons = {
    'housing': Icons.home,
    'vehicles': Icons.directions_car,
    'electronics': Icons.devices,
    'tools': Icons.build,
    'furniture': Icons.chair,
    'sports': Icons.sports_soccer,
    'books': Icons.menu_book,
    'clothing': Icons.checkroom,
    'other': Icons.category,
  };
  
  static String getDisplayName(String category) {
    switch (category.toLowerCase()) {
      case 'housing':
        return 'Housing';
      case 'vehicles':
        return 'Vehicles';
      case 'electronics':
        return 'Electronics';
      case 'tools':
        return 'Tools';
      case 'furniture':
        return 'Furniture';
      case 'sports':
        return 'Sports';
      case 'books':
        return 'Books';
      case 'clothing':
        return 'Clothing';
      case 'other':
        return 'Other';
      default:
        return category;
    }
  }
}

/// Rental status configuration
class RentalStatus {
  static const String pending = 'pending';
  static const String active = 'active';
  static const String completed = 'completed';
  static const String cancelled = 'cancelled';
  static const String disputed = 'disputed';
  
  static const Map<String, Color> colors = {
    pending: AppColors.warning,
    active: AppColors.success,
    completed: AppColors.grey,
    cancelled: AppColors.error,
    disputed: AppColors.error,
  };
  
  static const Map<String, IconData> icons = {
    pending: Icons.schedule,
    active: Icons.play_circle,
    completed: Icons.check_circle,
    cancelled: Icons.cancel,
    disputed: Icons.report_problem,
  };
  
  static String getDisplayName(String status) {
    switch (status.toLowerCase()) {
      case pending:
        return 'Pending';
      case active:
        return 'Active';
      case completed:
        return 'Completed';
      case cancelled:
        return 'Cancelled';
      case disputed:
        return 'Disputed';
      default:
        return status;
    }
  }
}

/// Application environment configuration
enum Environment { development, staging, production }

class EnvironmentConfig {
  static Environment get current {
    const env = String.fromEnvironment('ENV', defaultValue: 'development');
    switch (env) {
      case 'staging':
        return Environment.staging;
      case 'production':
        return Environment.production;
      default:
        return Environment.development;
    }
  }
  
  static bool get isDevelopment => current == Environment.development;
  static bool get isStaging => current == Environment.staging;
  static bool get isProduction => current == Environment.production;
}









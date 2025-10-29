import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Simplified Wallet Service for demo purposes
/// TODO: Integrate actual WalletConnect SDK in production
class WalletService {
  static final WalletService _instance = WalletService._internal();
  factory WalletService() => _instance;
  WalletService._internal();

  WalletSession? _currentSession;

  WalletSession? get currentSession => _currentSession;

  /// Check if wallet is connected
  Future<bool> isConnected() async {
    final prefs = await SharedPreferences.getInstance();
    final address = prefs.getString('wallet_address');
    return address != null && address.isNotEmpty;
  }

  /// Connect to wallet (mock implementation for demo)
  Future<WalletSession?> connect() async {
    try {
      // TODO: Implement actual WalletConnect integration
      // For now, simulate connection
      await Future.delayed(const Duration(seconds: 1));
      
      // Mock wallet address
      const mockAddress = '0x742d35Cc6634C0532925a3b844Bc9e7595f0bEb';
      
      _currentSession = WalletSession(
        accounts: [mockAddress],
        chainId: '11155111', // Sepolia
      );
      
      // Save to preferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('wallet_address', mockAddress);
      
      return _currentSession;
    } catch (e) {
      if (kDebugMode) {
        print('Error connecting wallet: $e');
      }
      return null;
    }
  }

  /// Disconnect wallet
  Future<void> disconnect() async {
    _currentSession = null;
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('wallet_address');
  }

  /// Sign message (mock implementation)
  Future<String?> signMessage(String message) async {
    try {
      // TODO: Implement actual signing
      await Future.delayed(const Duration(milliseconds: 500));
      return '0xmocksignature123456789abcdef...';
    } catch (e) {
      if (kDebugMode) {
        print('Error signing message: $e');
      }
      return null;
    }
  }

  /// Send transaction (mock implementation)
  Future<String?> sendTransaction({
    required String to,
    required String value,
    String? data,
  }) async {
    try {
      // TODO: Implement actual transaction sending
      await Future.delayed(const Duration(seconds: 2));
      return '0xmocktransactionhash123456789...';
    } catch (e) {
      if (kDebugMode) {
        print('Error sending transaction: $e');
      }
      return null;
    }
  }
}

/// Wallet session model
class WalletSession {
  final List<String> accounts;
  final String chainId;

  WalletSession({
    required this.accounts,
    required this.chainId,
  });

  String get address => accounts.first;
}

/// Wallet exception
class WalletException implements Exception {
  final String message;
  
  WalletException(this.message);
  
  @override
  String toString() => 'WalletException: $message';
}

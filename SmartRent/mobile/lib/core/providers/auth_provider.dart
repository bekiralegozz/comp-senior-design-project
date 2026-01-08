import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web3dart/web3dart.dart';

import '../../services/api_service.dart';
import '../../services/wallet_service.dart';

/// Authentication State (SIWE-based)
class AuthState {
  final bool isAuthenticated;
  final String? walletAddress;
  final String? jwtToken;
  final bool isLoading;
  final String? error;
  final String? statusMessage;
  final String? wcUri; // WalletConnect URI for QR code display
  final String? balance; // POL/MATIC balance

  const AuthState({
    this.isAuthenticated = false,
    this.walletAddress,
    this.jwtToken,
    this.isLoading = false,
    this.error,
    this.statusMessage,
    this.wcUri,
    this.balance,
  });

  AuthState copyWith({
    bool? isAuthenticated,
    String? walletAddress,
    bool walletAddressRemoved = false,
    String? jwtToken,
    bool jwtTokenRemoved = false,
    bool? isLoading,
    String? error,
    bool errorRemoved = false,
    String? statusMessage,
    bool statusMessageRemoved = false,
    String? wcUri,
    bool wcUriRemoved = false,
    String? balance,
    bool balanceRemoved = false,
  }) {
    return AuthState(
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      walletAddress: walletAddressRemoved ? null : (walletAddress ?? this.walletAddress),
      jwtToken: jwtTokenRemoved ? null : (jwtToken ?? this.jwtToken),
      isLoading: isLoading ?? this.isLoading,
      error: errorRemoved ? null : (error ?? this.error),
      statusMessage: statusMessageRemoved ? null : (statusMessage ?? this.statusMessage),
      wcUri: wcUriRemoved ? null : (wcUri ?? this.wcUri),
      balance: balanceRemoved ? null : (balance ?? this.balance),
    );
  }
}

/// Auth State Notifier (SIWE-based)
class AuthNotifier extends StateNotifier<AuthState> {
  final ApiService _apiService;
  final WalletService _walletService;
  bool _apiInitialized = false;

  AuthNotifier(this._apiService, this._walletService) : super(const AuthState()) {
    _initializeAuth();
  }

  Future<void> _initializeAuth() async {
    state = state.copyWith(
      isLoading: true,
      errorRemoved: true,
      statusMessageRemoved: true,
    );

    try {
      await _apiService.initialize();
      await _walletService.initialize();
      _apiInitialized = true;

      // Try to restore wallet session (auto-reconnect)
      if (_walletService.isConnected()) {
        final address = _walletService.getAddress();
        if (address != null) {
          // Check if JWT is still valid
          try {
            final userData = await _apiService.getMe();
            final authenticatedAddress = userData['address'] as String?;
            
            // Verify that JWT matches wallet address
            if (authenticatedAddress?.toLowerCase() == address.toLowerCase()) {
              // Valid session - restore auth state
              state = state.copyWith(
                isAuthenticated: true,
                walletAddress: address,
                isLoading: false,
                statusMessage: 'Wallet session restored',
              );
              
              // Fetch balance in the background
              _fetchBalance();
              return;
            }
          } catch (_) {
            // JWT expired or invalid - will need to re-authenticate
            await _apiService.clearSession();
          }
        }
      }

      // No valid session found
      state = state.copyWith(isLoading: false);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  Future<void> _ensureInitialized() async {
    if (_apiInitialized) return;
    await _initializeAuth();
  }

  /// Connect wallet and authenticate via SIWE
  Future<bool> connectWalletAndAuthenticate() async {
    await _ensureInitialized();
    state = state.copyWith(
      isLoading: true,
      errorRemoved: true,
      statusMessageRemoved: true,
      wcUriRemoved: true,
    );

    try {
      // Step 1: Connect wallet via WalletConnect
      state = state.copyWith(statusMessage: 'Connecting to wallet...');
      
      // Start the connection (this generates the wcUri)
      final connectFuture = _walletService.connect();
      
      // Give it a moment to generate the URI - increased delay for real devices
      await Future.delayed(const Duration(milliseconds: 800));
      
      // Get the wcUri for QR code display
      final wcUri = _walletService.getLatestWcUri();
      if (wcUri != null && wcUri.isNotEmpty) {
        state = state.copyWith(
          wcUri: wcUri,
          statusMessage: 'Scan QR code or approve in your wallet...',
        );
      }
      
      // Wait for wallet approval
      final session = await connectFuture;
      if (session == null) {
        throw Exception('Failed to connect wallet');
      }

      final walletAddress = session.accounts.first;

      // Step 2: Get nonce from backend
      state = state.copyWith(statusMessage: 'Requesting authentication challenge...');
      final nonceData = await _apiService.getNonce(walletAddress);
      final message = nonceData['message'] as String;

      // Step 3: Sign message with wallet
      state = state.copyWith(statusMessage: 'Please sign the message in your wallet...');
      final signature = await _walletService.signMessage(message);

      // Step 4: Verify signature and get JWT
      state = state.copyWith(statusMessage: 'Verifying signature...');
      final authData = await _apiService.verifySignature(
        message: message,
        signature: signature,
        address: walletAddress,
      );

      // Step 5: Save wallet address
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('wallet_address', walletAddress);

      state = state.copyWith(
        isAuthenticated: true,
        walletAddress: walletAddress,
        jwtToken: authData['access_token'] as String?,
        isLoading: false,
        statusMessage: 'Authentication successful!',
        wcUriRemoved: true, // Clear QR code after successful auth
      );

      // Fetch balance in the background
      _fetchBalance();

      return true;
    } catch (e) {
      final message = e is ApiException ? e.message : e.toString();
      state = state.copyWith(
        isLoading: false,
        error: message,
        wcUriRemoved: true, // Clear QR code on error
      );
      return false;
    }
  }

  /// Logout (disconnect wallet and clear JWT)
  Future<void> logout() async {
    await _ensureInitialized();
    state = state.copyWith(
      isLoading: true,
      errorRemoved: true,
      statusMessageRemoved: true,
    );
    
    try {
      // Disconnect wallet
      await _walletService.disconnect();
      
      // Clear JWT from backend
      await _apiService.logout();
      
      // Clear local storage
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('wallet_address');
      
      state = const AuthState(
        statusMessage: 'Logged out successfully',
      );
    } catch (e) {
      // Even if something goes wrong, clear the state
      state = const AuthState();
    }
  }

  void clearStatusMessage() {
    state = state.copyWith(statusMessageRemoved: true);
  }

  void clearErrorMessage() {
    state = state.copyWith(errorRemoved: true);
  }

  /// Fetch POL/MATIC balance from blockchain
  Future<void> _fetchBalance() async {
    try {
      if (state.walletAddress == null) return;
      
      // Get balance using WalletService
      final balanceWei = await _walletService.getBalance();
      final balanceEth = balanceWei.getValueInUnit(EtherUnit.ether).toStringAsFixed(4);
      
      state = state.copyWith(balance: balanceEth);
    } catch (e) {
      // Silent fail - balance is optional
      print('Failed to fetch balance: $e');
    }
  }

  /// Refresh balance manually
  Future<void> refreshBalance() async {
    await _fetchBalance();
  }
}

final authStateProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final apiService = ApiService();
  final walletService = WalletService();
  return AuthNotifier(apiService, walletService);
});

final walletAddressProvider = Provider<String?>((ref) {
  return ref.watch(authStateProvider).walletAddress;
});

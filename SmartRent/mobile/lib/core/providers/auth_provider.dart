import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../services/api_service.dart';
import '../../services/wallet_service_simple.dart';
import '../../services/models.dart';

// Auth State Model
class AuthState {
  final bool isAuthenticated;
  final User? user;
  final String? walletAddress;
  final bool isLoading;
  final String? error;

  const AuthState({
    this.isAuthenticated = false,
    this.user,
    this.walletAddress,
    this.isLoading = false,
    this.error,
  });

  AuthState copyWith({
    bool? isAuthenticated,
    User? user,
    String? walletAddress,
    bool? isLoading,
    String? error,
  }) {
    return AuthState(
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      user: user ?? this.user,
      walletAddress: walletAddress ?? this.walletAddress,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
    );
  }
}

// Auth State Notifier
class AuthNotifier extends StateNotifier<AuthState> {
  final ApiService _apiService;
  final WalletService _walletService;

  AuthNotifier(this._apiService, this._walletService) : super(const AuthState()) {
    _initializeAuth();
  }

  Future<void> _initializeAuth() async {
    state = state.copyWith(isLoading: true);
    
    try {
      final prefs = await SharedPreferences.getInstance();
      final walletAddress = prefs.getString('wallet_address');
      
      if (walletAddress != null) {
        // Try to fetch user from backend
        try {
          final user = await _apiService.getUserByWallet(walletAddress);
          state = state.copyWith(
            isAuthenticated: true,
            user: user,
            walletAddress: walletAddress,
            isLoading: false,
          );
        } catch (e) {
          // User not found in backend, just set wallet
          state = state.copyWith(
            isAuthenticated: false,
            walletAddress: walletAddress,
            isLoading: false,
          );
        }
      } else {
        state = state.copyWith(isLoading: false);
      }
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  // Login with email/password (traditional auth)
  Future<bool> loginWithCredentials(String email, String password) async {
    state = state.copyWith(isLoading: true, error: null);
    
    try {
      // TODO: Implement backend login endpoint
      // For now, just simulate login
      await Future.delayed(const Duration(seconds: 1));
      
      // Mock user data
      final user = User(
        id: 1,
        email: email,
        walletAddress: null,
        displayName: email.split('@')[0],
        createdAt: DateTime.now(),
      );
      
      state = state.copyWith(
        isAuthenticated: true,
        user: user,
        isLoading: false,
      );
      
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
      return false;
    }
  }

  // Connect with Web3 wallet
  Future<bool> connectWallet() async {
    state = state.copyWith(isLoading: true, error: null);
    
    try {
      // Connect to wallet
      final session = await _walletService.connect();
      if (session == null) {
        throw Exception('Failed to connect wallet');
      }
      
      final walletAddress = session.accounts.first;
      
      // Save wallet address
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('wallet_address', walletAddress);
      
      // Try to get or create user in backend
      User? user;
      try {
        user = await _apiService.getUserByWallet(walletAddress);
      } catch (e) {
        // User doesn't exist, create new one
        user = await _apiService.createUser(
          CreateUserRequest(
            walletAddress: walletAddress,
            displayName: 'User ${walletAddress.substring(0, 6)}',
          ),
        );
      }
      
      state = state.copyWith(
        isAuthenticated: true,
        user: user,
        walletAddress: walletAddress,
        isLoading: false,
      );
      
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
      return false;
    }
  }

  // Register new user
  Future<bool> register(String email, String password, String displayName) async {
    state = state.copyWith(isLoading: true, error: null);
    
    try {
      // TODO: Implement backend registration endpoint
      await Future.delayed(const Duration(seconds: 1));
      
      final user = User(
        id: 1,
        email: email,
        walletAddress: null,
        displayName: displayName,
        createdAt: DateTime.now(),
      );
      
      state = state.copyWith(
        isAuthenticated: true,
        user: user,
        isLoading: false,
      );
      
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
      return false;
    }
  }

  // Logout
  Future<void> logout() async {
    try {
      // Disconnect wallet if connected
      if (state.walletAddress != null) {
        await _walletService.disconnect();
      }
      
      // Clear stored data
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('wallet_address');
      await _apiService.clearAuthToken();
      
      state = const AuthState();
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  // Update user profile
  Future<bool> updateProfile(Map<String, dynamic> updates) async {
    state = state.copyWith(isLoading: true, error: null);
    
    try {
      if (state.user == null) {
        throw Exception('No user logged in');
      }
      
      final updatedUser = await _apiService.updateUser(state.user!.id, updates);
      
      state = state.copyWith(
        user: updatedUser,
        isLoading: false,
      );
      
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
      return false;
    }
  }
}

// Providers
final authStateProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final apiService = ApiService();
  final walletService = WalletService();
  return AuthNotifier(apiService, walletService);
});

// Helper provider for current user
final currentUserProvider = Provider<User?>((ref) {
  return ref.watch(authStateProvider).user;
});

// Helper provider for wallet address
final walletAddressProvider = Provider<String?>((ref) {
  return ref.watch(authStateProvider).walletAddress;
});

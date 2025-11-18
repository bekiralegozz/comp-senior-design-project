import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../services/api_service.dart';
import '../../services/wallet_service_simple.dart';
import '../../services/models.dart';

class AuthState {
  final bool isAuthenticated;
  final AuthProfile? profile;
  final String? accessToken;
  final String? refreshToken;
  final bool isLoading;
  final String? error;
  final String? statusMessage;
  final bool requiresEmailVerification;

  const AuthState({
    this.isAuthenticated = false,
    this.profile,
    this.accessToken,
    this.refreshToken,
    this.isLoading = false,
    this.error,
    this.statusMessage,
    this.requiresEmailVerification = false,
  });

  String? get walletAddress => profile?.walletAddress;

  AuthState copyWith({
    bool? isAuthenticated,
    AuthProfile? profile,
    bool profileRemoved = false,
    String? accessToken,
    String? refreshToken,
    bool? isLoading,
    String? error,
    bool errorRemoved = false,
    String? statusMessage,
    bool statusMessageRemoved = false,
    bool? requiresEmailVerification,
  }) {
    return AuthState(
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      profile: profileRemoved ? null : (profile ?? this.profile),
      accessToken: accessToken ?? this.accessToken,
      refreshToken: refreshToken ?? this.refreshToken,
      isLoading: isLoading ?? this.isLoading,
      error: errorRemoved ? null : (error ?? this.error),
      statusMessage: statusMessageRemoved ? null : (statusMessage ?? this.statusMessage),
      requiresEmailVerification:
          requiresEmailVerification ?? this.requiresEmailVerification,
    );
  }
}

// Auth State Notifier
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
      _apiInitialized = true;
      final session = await _apiService.restoreSession();
      if (session != null) {
        _setAuthenticatedSession(session);
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

  void _setAuthenticatedSession(AuthSession session) {
    state = state.copyWith(
      isAuthenticated: true,
      profile: session.profile ?? state.profile,
      accessToken: session.accessToken,
      refreshToken: session.refreshToken,
      isLoading: false,
      requiresEmailVerification: false,
      errorRemoved: true,
      statusMessageRemoved: true,
    );
  }

  Future<void> _ensureInitialized() async {
    if (_apiInitialized) return;
    await _initializeAuth();
  }

  Future<bool> loginWithCredentials(String email, String password) async {
    await _ensureInitialized();
    state = state.copyWith(
      isLoading: true,
      errorRemoved: true,
      statusMessageRemoved: true,
    );

    try {
      final session = await _apiService.loginWithEmail(
        email: email,
        password: password,
      );
      _setAuthenticatedSession(session);
      return true;
    } catch (e) {
      final message = e is ApiException ? e.message : e.toString();
      state = state.copyWith(
        isLoading: false,
        error: message,
        isAuthenticated: false,
        accessToken: null,
        refreshToken: null,
      );
      return false;
    }
  }

  Future<bool> connectWallet() async {
    await _ensureInitialized();
    state = state.copyWith(
      isLoading: true,
      errorRemoved: true,
      statusMessageRemoved: true,
    );

    try {
      final session = await _walletService.connect();
      if (session == null) {
        throw Exception('Failed to connect wallet');
      }

      final walletAddress = session.accounts.first;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('wallet_address', walletAddress);

      User? user;
      try {
        user = await _apiService.getUserByWallet(walletAddress);
      } catch (_) {
        user = await _apiService.createUser(
          CreateUserRequest(
            walletAddress: walletAddress,
            displayName: 'User ${walletAddress.substring(0, 6)}',
          ),
        );
      }

      final profile = AuthProfile(
        id: user.id.toString(),
        email: user.email,
        fullName: user.displayName,
        walletAddress: user.walletAddress,
        createdAt: user.createdAt,
        updatedAt: user.updatedAt,
      );

      state = state.copyWith(
        isAuthenticated: true,
        profile: profile,
        isLoading: false,
        statusMessage: 'Wallet connected successfully.',
      );

      return true;
    } catch (e) {
      final message = e is ApiException ? e.message : e.toString();
      state = state.copyWith(
        isLoading: false,
        error: message,
      );
      return false;
    }
  }

  Future<bool> register(
    String email,
    String password,
    String displayName, {
    String? walletAddress,
    String? avatarUrl,
  }) async {
    await _ensureInitialized();
    state = state.copyWith(
      isLoading: true,
      errorRemoved: true,
      statusMessageRemoved: true,
    );

    try {
      final response = await _apiService.signup(
        email: email,
        password: password,
        fullName: displayName,
        walletAddress: walletAddress,
        avatarUrl: avatarUrl,
      );

      state = state.copyWith(
        isLoading: false,
        requiresEmailVerification: response.requiresEmailVerification,
        statusMessage:
            'Account created. Please check your email to verify before signing in.',
      );

      return true;
    } catch (e) {
      final message = e is ApiException ? e.message : e.toString();
      state = state.copyWith(
        isLoading: false,
        error: message,
      );
      return false;
    }
  }

  Future<void> logout() async {
    await _ensureInitialized();
    state = state.copyWith(
      isLoading: true,
      errorRemoved: true,
      statusMessageRemoved: true,
    );
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('wallet_address');
      // Try to logout from backend, but don't fail if it errors
      // Session will be cleared locally regardless
      try {
        await _apiService.logout(refreshToken: state.refreshToken);
      } catch (e) {
        // Log but don't fail - session will be cleared anyway
        // This handles network errors gracefully
      }
      // Always clear state and show success
      state = const AuthState(
        statusMessage: 'Logged out successfully',
      );
    } catch (e) {
      // Even if something goes wrong, clear the state
      state = const AuthState();
    }
  }

  Future<void> refreshSession() async {
    await _ensureInitialized();
    try {
      final session = await _apiService.refreshSession();
      _setAuthenticatedSession(session);
    } catch (e) {
      final message = e is ApiException ? e.message : e.toString();
      state = state.copyWith(
        error: message,
        isAuthenticated: false,
        accessToken: null,
        refreshToken: null,
      );
    }
  }

  Future<void> sendMagicLink(String email) async {
    await _ensureInitialized();
    state = state.copyWith(
      isLoading: true,
      errorRemoved: true,
      statusMessageRemoved: true,
    );

    try {
      await _apiService.sendMagicLink(email);
      state = state.copyWith(
        isLoading: false,
        statusMessage:
            'Magic link sent. Please check your email to continue.',
      );
    } catch (e) {
      final message = e is ApiException ? e.message : e.toString();
      state = state.copyWith(isLoading: false, error: message);
    }
  }

  Future<void> requestPasswordReset(String email) async {
    await _ensureInitialized();
    state = state.copyWith(
      isLoading: true,
      errorRemoved: true,
      statusMessageRemoved: true,
    );

    try {
      await _apiService.requestPasswordReset(email);
      state = state.copyWith(
        isLoading: false,
        statusMessage:
            'Password reset email sent. Follow the instructions in your inbox.',
      );
    } catch (e) {
      final message = e is ApiException ? e.message : e.toString();
      state = state.copyWith(isLoading: false, error: message);
    }
  }

  Future<void> confirmPasswordReset({
    required String accessToken,
    required String newPassword,
  }) async {
    await _ensureInitialized();
    state = state.copyWith(
      isLoading: true,
      errorRemoved: true,
      statusMessageRemoved: true,
    );

    try {
      await _apiService.confirmPasswordReset(
        accessToken: accessToken,
        newPassword: newPassword,
      );
      state = state.copyWith(
        isLoading: false,
        statusMessage: 'Password updated successfully. You can now sign in.',
      );
    } catch (e) {
      final message = e is ApiException ? e.message : e.toString();
      state = state.copyWith(isLoading: false, error: message);
    }
  }

  Future<bool> updateProfile(Map<String, dynamic> updates) async {
    await _ensureInitialized();
    state = state.copyWith(
      isLoading: true,
      errorRemoved: true,
      statusMessageRemoved: true,
    );

    try {
      final profile = state.profile;
      if (profile == null) {
        throw Exception('No user profile available');
      }

      // TODO: Replace with real profile update endpoint
      await Future.delayed(const Duration(milliseconds: 300));

      final updatedProfile = AuthProfile(
        id: profile.id,
        email: updates['email'] as String? ?? profile.email,
        fullName: updates['full_name'] as String? ?? profile.fullName,
        walletAddress: updates['wallet_address'] as String? ?? profile.walletAddress,
        avatarUrl: updates['avatar_url'] as String? ?? profile.avatarUrl,
        isOnboarded: updates['is_onboarded'] as bool? ?? profile.isOnboarded,
        createdAt: profile.createdAt,
        updatedAt: DateTime.now(),
        lastLoginAt: profile.lastLoginAt,
      );

      state = state.copyWith(
        profile: updatedProfile,
        isLoading: false,
        statusMessage: 'Profile updated.',
      );

      return true;
    } catch (e) {
      final message = e is ApiException ? e.message : e.toString();
      state = state.copyWith(
        isLoading: false,
        error: message,
      );
      return false;
    }
  }

  void clearStatusMessage() {
    state = state.copyWith(statusMessageRemoved: true);
  }

  void clearErrorMessage() {
    state = state.copyWith(errorRemoved: true);
  }
}

final authStateProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final apiService = ApiService();
  final walletService = WalletService();
  return AuthNotifier(apiService, walletService);
});

final currentProfileProvider = Provider<AuthProfile?>((ref) {
  return ref.watch(authStateProvider).profile;
});

final walletAddressProvider = Provider<String?>((ref) {
  return ref.watch(authStateProvider).walletAddress;
});

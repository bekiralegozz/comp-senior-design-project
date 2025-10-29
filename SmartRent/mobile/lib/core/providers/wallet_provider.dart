import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/wallet_service_simple.dart';

// Wallet State
class WalletState {
  final bool isConnected;
  final String? address;
  final String? balance;
  final String? chainId;
  final bool isLoading;
  final String? error;

  const WalletState({
    this.isConnected = false,
    this.address,
    this.balance,
    this.chainId,
    this.isLoading = false,
    this.error,
  });

  WalletState copyWith({
    bool? isConnected,
    String? address,
    String? balance,
    String? chainId,
    bool? isLoading,
    String? error,
  }) {
    return WalletState(
      isConnected: isConnected ?? this.isConnected,
      address: address ?? this.address,
      balance: balance ?? this.balance,
      chainId: chainId ?? this.chainId,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

// Wallet Notifier
class WalletNotifier extends StateNotifier<WalletState> {
  final WalletService _walletService;

  WalletNotifier(this._walletService) : super(const WalletState()) {
    _initialize();
  }

  Future<void> _initialize() async {
    // Check if wallet is already connected
    final isConnected = await _walletService.isConnected();
    if (isConnected) {
      await _loadWalletInfo();
    }
  }

  Future<void> _loadWalletInfo() async {
    try {
      final session = _walletService.currentSession;
      if (session != null) {
        final address = session.address;
        // Mock balance for demo
        final balance = '1.5';
        
        state = state.copyWith(
          isConnected: true,
          address: address,
          balance: balance,
          chainId: session.chainId,
        );
      }
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  Future<bool> connect() async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final session = await _walletService.connect();
      if (session != null) {
        await _loadWalletInfo();
        return true;
      }
      
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to connect wallet',
      );
      return false;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
      return false;
    }
  }

  Future<void> disconnect() async {
    try {
      await _walletService.disconnect();
      state = const WalletState();
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  Future<void> refreshBalance() async {
    if (state.address == null) return;

    try {
      // Mock balance refresh
      final balance = '1.5';
      state = state.copyWith(balance: balance);
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }
}

// Transaction State
class TransactionState {
  final String? txHash;
  final TransactionStatus status;
  final String? error;

  const TransactionState({
    this.txHash,
    this.status = TransactionStatus.idle,
    this.error,
  });

  TransactionState copyWith({
    String? txHash,
    TransactionStatus? status,
    String? error,
  }) {
    return TransactionState(
      txHash: txHash ?? this.txHash,
      status: status ?? this.status,
      error: error,
    );
  }
}

enum TransactionStatus {
  idle,
  awaitingSignature,
  pending,
  confirmed,
  failed,
}

// Providers
final walletProvider = StateNotifierProvider<WalletNotifier, WalletState>((ref) {
  final walletService = WalletService();
  return WalletNotifier(walletService);
});

final walletAddressProvider = Provider<String?>((ref) {
  return ref.watch(walletProvider).address;
});

final walletBalanceProvider = Provider<String?>((ref) {
  return ref.watch(walletProvider).balance;
});

final isWalletConnectedProvider = Provider<bool>((ref) {
  return ref.watch(walletProvider).isConnected;
});

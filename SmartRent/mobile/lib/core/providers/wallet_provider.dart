import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:web3dart/web3dart.dart';
import '../../services/wallet_service.dart';
import '../../services/blockchain_service.dart';

// Wallet State
class WalletState {
  final bool isConnected;
  final String? address;
  final String? balance;
  final String? chainId;
  final bool isLoading;
  final String? error;
  final String? wcUri; // WalletConnect URI for QR code

  const WalletState({
    this.isConnected = false,
    this.address,
    this.balance,
    this.chainId,
    this.isLoading = false,
    this.error,
    this.wcUri,
  });

  WalletState copyWith({
    bool? isConnected,
    String? address,
    String? balance,
    String? chainId,
    bool? isLoading,
    String? error,
    String? wcUri,
    bool clearWcUri = false,
  }) {
    return WalletState(
      isConnected: isConnected ?? this.isConnected,
      address: address ?? this.address,
      balance: balance ?? this.balance,
      chainId: chainId ?? this.chainId,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      wcUri: clearWcUri ? null : (wcUri ?? this.wcUri),
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
    await _walletService.initialize();
    
    // Check if wallet is already connected
    if (_walletService.isConnected()) {
      await _loadWalletInfo();
    }
  }

  Future<void> _loadWalletInfo() async {
    try {
      final address = _walletService.getAddress();
      if (address != null) {
        // Get balance from blockchain
        final balanceWei = await _walletService.getBalance();
        final balanceEth = balanceWei.getValueInUnit(EtherUnit.ether).toStringAsFixed(4);
        
        state = state.copyWith(
          isConnected: true,
          address: address,
          balance: balanceEth,
          chainId: '11155111', // Sepolia
        );
      }
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  Future<bool> connect() async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      // Start connection (this will generate wcUri immediately)
      final connectFuture = _walletService.connect();
      
      // Give it a moment to generate URI in WalletService
      await Future.delayed(const Duration(milliseconds: 300));
      
      // Get wcUri from service (set immediately after connect starts)
      final wcUri = _walletService.getLatestWcUri();
      print('🔍 DEBUG: Got wcUri from service: ${wcUri?.substring(0, 20)}...');
      
      if (wcUri != null && wcUri.isNotEmpty) {
        state = state.copyWith(wcUri: wcUri);
        print('✅ DEBUG: Set wcUri to state');
      } else {
        print('❌ DEBUG: wcUri is null or empty');
      }
      
      // Complete the connection (this waits for user approval)
      final session = await connectFuture;
      
      if (session != null) {
        state = state.copyWith(
          isLoading: false,
        );
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
  
  /// Get the current WalletConnect URI for QR code display
  String? getWcUri() {
    return state.wcUri;
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
      final balanceWei = await _walletService.getBalance();
      final balanceEth = balanceWei.getValueInUnit(EtherUnit.ether).toStringAsFixed(4);
      state = state.copyWith(balance: balanceEth);
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
final walletServiceProvider = Provider<WalletService>((ref) {
  return WalletService();
});

final blockchainServiceProvider = Provider<BlockchainService>((ref) {
  return BlockchainService();
});

final walletProvider = StateNotifierProvider<WalletNotifier, WalletState>((ref) {
  final walletService = ref.watch(walletServiceProvider);
  return WalletNotifier(walletService);
});

// Note: walletAddressProvider is defined in auth_provider.dart
// Use authStateProvider.walletAddress or walletAddressProvider from auth_provider

final walletBalanceProvider = Provider<String?>((ref) {
  return ref.watch(walletProvider).balance;
});

final isWalletConnectedProvider = Provider<bool>((ref) {
  return ref.watch(walletProvider).isConnected;
});

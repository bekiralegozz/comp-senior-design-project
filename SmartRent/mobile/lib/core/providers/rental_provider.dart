import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/models.dart';
import '../../services/blockchain_service.dart';
import 'auth_provider.dart'; // For walletAddressProvider
import 'wallet_provider.dart'; // For blockchainServiceProvider

/// ==========================================================
/// RENTAL PROVIDER - BLOCKCHAIN MIGRATION VERSION
/// ==========================================================
///
/// This provider is transitioning from database to blockchain.
/// Rentals will be managed through smart contracts.
/// Currently shows placeholder data.

// Rental List State
class RentalListState {
  final List<Rental> rentals;
  final bool isLoading;
  final String? error;
  final bool hasMore;
  final int currentPage;

  const RentalListState({
    this.rentals = const [],
    this.isLoading = false,
    this.error,
    this.hasMore = false,
    this.currentPage = 0,
  });

  RentalListState copyWith({
    List<Rental>? rentals,
    bool? isLoading,
    String? error,
    bool? hasMore,
    int? currentPage,
  }) {
    return RentalListState(
      rentals: rentals ?? this.rentals,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      hasMore: hasMore ?? this.hasMore,
      currentPage: currentPage ?? this.currentPage,
    );
  }
}

// Rental List Notifier - Blockchain version (placeholder)
class RentalListNotifier extends StateNotifier<RentalListState> {
  final BlockchainService _blockchainService;
  final String? walletAddress;
  final String? statusFilter;
  final String? assetId;

  RentalListNotifier(
    this._blockchainService, {
    this.walletAddress,
    this.statusFilter,
    this.assetId,
  }) : super(const RentalListState()) {
    loadRentals();
  }

  Future<void> loadRentals({bool refresh = false}) async {
    if (state.isLoading && !refresh) return;

    state = state.copyWith(isLoading: true, error: null);

    try {
      // TODO: Fetch rentals from RentalManager smart contract
      // For now, return empty list - blockchain integration pending
      
      await Future.delayed(const Duration(milliseconds: 500)); // Simulate network
      
      state = RentalListState(
        rentals: [],
        isLoading: false,
        hasMore: false,
        currentPage: 1,
        error: null,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to load rentals from blockchain: $e',
      );
    }
  }

  Future<void> refresh() => loadRentals(refresh: true);
}

// Rental Detail State
class RentalDetailState {
  final Rental? rental;
  final bool isLoading;
  final String? error;
  final bool isUpdating;

  const RentalDetailState({
    this.rental,
    this.isLoading = false,
    this.error,
    this.isUpdating = false,
  });

  RentalDetailState copyWith({
    Rental? rental,
    bool? isLoading,
    String? error,
    bool? isUpdating,
  }) {
    return RentalDetailState(
      rental: rental ?? this.rental,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      isUpdating: isUpdating ?? this.isUpdating,
    );
  }
}

// Rental Detail Notifier
class RentalDetailNotifier extends StateNotifier<RentalDetailState> {
  final BlockchainService _blockchainService;
  final String rentalId;

  RentalDetailNotifier(this._blockchainService, this.rentalId) : super(const RentalDetailState()) {
    loadRental();
  }

  Future<void> loadRental() async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      // TODO: Fetch rental from blockchain
      await Future.delayed(const Duration(milliseconds: 500));
      
      state = state.copyWith(
        isLoading: false,
        error: 'Rental details from blockchain coming soon',
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<bool> payRent(String amount, List<String> owners) async {
    if (state.rental == null) return false;

    state = state.copyWith(isUpdating: true, error: null);

    try {
      // Pay rent via blockchain
      final txHash = await _blockchainService.payRent(
        assetId: int.parse(state.rental!.assetId ?? '0'),
        amount: amount,
        owners: owners,
      );

      state = state.copyWith(isUpdating: false);
      return txHash.isNotEmpty;
    } catch (e) {
      state = state.copyWith(isUpdating: false, error: e.toString());
      return false;
    }
  }
}

// Providers
final rentalListProvider = StateNotifierProvider.autoDispose<RentalListNotifier, RentalListState>(
  (ref) {
    final blockchainService = ref.watch(blockchainServiceProvider);
    return RentalListNotifier(blockchainService);
  },
);

final myRentalsProvider = StateNotifierProvider.autoDispose<RentalListNotifier, RentalListState>(
  (ref) {
    final blockchainService = ref.watch(blockchainServiceProvider);
    final walletAddress = ref.watch(walletAddressProvider);
    return RentalListNotifier(blockchainService, walletAddress: walletAddress);
  },
);

final rentalDetailProvider = StateNotifierProvider.family<RentalDetailNotifier, RentalDetailState, String>(
  (ref, rentalId) {
    final blockchainService = ref.watch(blockchainServiceProvider);
    return RentalDetailNotifier(blockchainService, rentalId);
  },
);

final activeRentalsProvider = StateNotifierProvider.autoDispose<RentalListNotifier, RentalListState>(
  (ref) {
    final blockchainService = ref.watch(blockchainServiceProvider);
    return RentalListNotifier(blockchainService, statusFilter: 'active');
  },
);

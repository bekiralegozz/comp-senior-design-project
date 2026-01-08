import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/models.dart';
import '../../services/rental_service.dart';
import '../../services/rental_models.dart' as rm;
import '../../services/blockchain_service.dart';
import 'auth_provider.dart'; // For walletAddressProvider
import 'wallet_provider.dart'; // For blockchainServiceProvider

/// ==========================================================
/// RENTAL PROVIDER - BLOCKCHAIN VERSION
/// ==========================================================
///
/// Fetches rental data from blockchain via RentalHub contract.
/// Uses RentalService to communicate with backend API.

// RentalService provider
final rentalServiceProvider = Provider<RentalService>((ref) {
  return RentalService();
});

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

// Rental List Notifier - Fetches from blockchain via RentalService
class RentalListNotifier extends StateNotifier<RentalListState> {
  final RentalService _rentalService;
  final String? walletAddress;
  final String? statusFilter;
  final String? assetId;

  RentalListNotifier(
    this._rentalService, {
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
      List<rm.Rental> blockchainRentals = [];

      // Fetch rentals from blockchain based on wallet address
      if (walletAddress != null && walletAddress!.isNotEmpty) {
        blockchainRentals =
            await _rentalService.getRentalsByRenter(walletAddress!);
      }

      // Convert blockchain Rental to UI Rental model
      final uiRentals =
          blockchainRentals.map((r) => _convertToUiRental(r)).toList();

      // Apply status filter if provided
      final filteredRentals = statusFilter != null && statusFilter!.isNotEmpty
          ? uiRentals
              .where((rental) =>
                  rental.status?.toLowerCase() == statusFilter!.toLowerCase())
              .toList()
          : uiRentals;

      state = RentalListState(
        rentals: filteredRentals,
        isLoading: false,
        hasMore: false,
        currentPage: 1,
        error: null,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to load rentals: $e',
      );
    }
  }

  /// Convert blockchain Rental model to UI Rental model
  Rental _convertToUiRental(rm.Rental blockchainRental) {
    // Map status
    String statusStr;
    switch (blockchainRental.status) {
      case rm.RentalStatus.active:
        statusStr = 'active';
        break;
      case rm.RentalStatus.completed:
        statusStr = 'completed';
        break;
      case rm.RentalStatus.cancelled:
        statusStr = 'cancelled';
        break;
    }

    return Rental(
      id: blockchainRental.rentalId.toString(),
      assetId: blockchainRental.tokenId.toString(),
      renterId: null,
      renterWalletAddress: blockchainRental.renter,
      status: statusStr,
      startDate: blockchainRental.checkInDateTime,
      endDate: blockchainRental.checkOutDateTime,
      totalPrice: double.tryParse(blockchainRental.totalPrice),
      totalPriceUsd: null,
      securityDeposit: null,
      currency: 'POL',
      paymentTxHash: null,
      transactionHash: null,
      createdAt: DateTime.fromMillisecondsSinceEpoch(
          blockchainRental.createdAt * 1000),
      updatedAt: null,
      asset: null,
    );
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
  final RentalService _rentalService;
  final String rentalId;

  RentalDetailNotifier(this._rentalService, this.rentalId)
      : super(const RentalDetailState()) {
    loadRental();
  }

  Future<void> loadRental() async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final blockchainRental =
          await _rentalService.getRental(int.parse(rentalId));

      if (blockchainRental != null) {
        // Convert to UI model
        String statusStr;
        switch (blockchainRental.status) {
          case rm.RentalStatus.active:
            statusStr = 'active';
            break;
          case rm.RentalStatus.completed:
            statusStr = 'completed';
            break;
          case rm.RentalStatus.cancelled:
            statusStr = 'cancelled';
            break;
        }

        final uiRental = Rental(
          id: blockchainRental.rentalId.toString(),
          assetId: blockchainRental.tokenId.toString(),
          renterWalletAddress: blockchainRental.renter,
          status: statusStr,
          startDate: blockchainRental.checkInDateTime,
          endDate: blockchainRental.checkOutDateTime,
          totalPrice: double.tryParse(blockchainRental.totalPrice),
          currency: 'POL',
          createdAt: DateTime.fromMillisecondsSinceEpoch(
              blockchainRental.createdAt * 1000),
        );

        state = state.copyWith(
          isLoading: false,
          rental: uiRental,
          error: null,
        );
      } else {
        state = state.copyWith(
          isLoading: false,
          error: 'Rental not found',
        );
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<bool> payRent(String amount, List<String> owners) async {
    // This functionality is handled differently now
    // Rent payments are made via blockchain when booking
    state = state.copyWith(
        isUpdating: false, error: 'Payment already completed at booking');
    return false;
  }
}

// Providers
final rentalListProvider =
    StateNotifierProvider.autoDispose<RentalListNotifier, RentalListState>(
  (ref) {
    final rentalService = ref.watch(rentalServiceProvider);
    return RentalListNotifier(rentalService);
  },
);

final myRentalsProvider =
    StateNotifierProvider.autoDispose<RentalListNotifier, RentalListState>(
  (ref) {
    final rentalService = ref.watch(rentalServiceProvider);
    final walletAddress = ref.watch(walletAddressProvider);
    return RentalListNotifier(rentalService, walletAddress: walletAddress);
  },
);

final rentalDetailProvider = StateNotifierProvider.family<RentalDetailNotifier,
    RentalDetailState, String>(
  (ref, rentalId) {
    final rentalService = ref.watch(rentalServiceProvider);
    return RentalDetailNotifier(rentalService, rentalId);
  },
);

final activeRentalsProvider =
    StateNotifierProvider.autoDispose<RentalListNotifier, RentalListState>(
  (ref) {
    final rentalService = ref.watch(rentalServiceProvider);
    return RentalListNotifier(rentalService, statusFilter: 'active');
  },
);

// ============================================
// RENTAL LISTINGS PROVIDER (for Rentplace)
// ============================================

/// Rental Listings State - for displaying available rental listings
class RentalListingsState {
  final List<rm.RentalListing> listings;
  final bool isLoading;
  final String? error;

  const RentalListingsState({
    this.listings = const [],
    this.isLoading = false,
    this.error,
  });

  RentalListingsState copyWith({
    List<rm.RentalListing>? listings,
    bool? isLoading,
    String? error,
  }) {
    return RentalListingsState(
      listings: listings ?? this.listings,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

/// Rental Listings Notifier - Fetches rental listings from API
class RentalListingsNotifier extends StateNotifier<RentalListingsState> {
  final RentalService _rentalService;

  RentalListingsNotifier(this._rentalService)
      : super(const RentalListingsState()) {
    loadListings();
  }

  Future<void> loadListings() async {
    if (state.isLoading) return;

    state = state.copyWith(isLoading: true, error: null);

    try {
      final listings = await _rentalService.getAllRentalListings();

      state = state.copyWith(
        listings: listings,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to load rental listings: $e',
      );
    }
  }

  Future<void> refresh() => loadListings();
}

/// Rental Listings Provider - Active rental listings from RentalHub
final rentalListingsProvider =
    StateNotifierProvider<RentalListingsNotifier, RentalListingsState>((ref) {
  final rentalService = ref.watch(rentalServiceProvider);
  return RentalListingsNotifier(rentalService);
});

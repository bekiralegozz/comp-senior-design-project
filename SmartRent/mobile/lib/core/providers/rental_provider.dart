import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/api_service.dart';
import '../../services/models.dart';

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
    this.hasMore = true,
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

// Rental List Notifier
class RentalListNotifier extends StateNotifier<RentalListState> {
  final ApiService _apiService;
  final String? statusFilter;
  final int? renterId;
  final int? assetId;

  RentalListNotifier(
    this._apiService, {
    this.statusFilter,
    this.renterId,
    this.assetId,
  }) : super(const RentalListState()) {
    loadRentals();
  }

  Future<void> loadRentals({bool refresh = false}) async {
    if (state.isLoading) return;

    if (refresh) {
      state = const RentalListState(isLoading: true);
    } else {
      state = state.copyWith(isLoading: true, error: null);
    }

    try {
      final rentals = await _apiService.getRentals(
        skip: refresh ? 0 : state.currentPage * 20,
        limit: 20,
        status: statusFilter,
        renterId: renterId,
        assetId: assetId,
      );

      if (refresh) {
        state = RentalListState(
          rentals: rentals,
          isLoading: false,
          hasMore: rentals.length >= 20,
          currentPage: 1,
        );
      } else {
        state = state.copyWith(
          rentals: [...state.rentals, ...rentals],
          isLoading: false,
          hasMore: rentals.length >= 20,
          currentPage: state.currentPage + 1,
        );
      }
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
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
  final ApiService _apiService;
  final int rentalId;

  RentalDetailNotifier(this._apiService, this.rentalId) : super(const RentalDetailState()) {
    loadRental();
  }

  Future<void> loadRental() async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final rental = await _apiService.getRental(rentalId);
      state = state.copyWith(rental: rental, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<bool> activateRental() async {
    if (state.rental == null) return false;

    state = state.copyWith(isUpdating: true, error: null);

    try {
      final updatedRental = await _apiService.activateRental(rentalId);
      state = state.copyWith(rental: updatedRental, isUpdating: false);
      return true;
    } catch (e) {
      state = state.copyWith(isUpdating: false, error: e.toString());
      return false;
    }
  }

  Future<bool> completeRental() async {
    if (state.rental == null) return false;

    state = state.copyWith(isUpdating: true, error: null);

    try {
      final updatedRental = await _apiService.completeRental(rentalId);
      state = state.copyWith(rental: updatedRental, isUpdating: false);
      return true;
    } catch (e) {
      state = state.copyWith(isUpdating: false, error: e.toString());
      return false;
    }
  }

  Future<bool> cancelRental() async {
    if (state.rental == null) return false;

    state = state.copyWith(isUpdating: true, error: null);

    try {
      final updatedRental = await _apiService.cancelRental(rentalId);
      state = state.copyWith(rental: updatedRental, isUpdating: false);
      return true;
    } catch (e) {
      state = state.copyWith(isUpdating: false, error: e.toString());
      return false;
    }
  }
}

// Providers
final rentalListProvider = StateNotifierProvider.autoDispose<RentalListNotifier, RentalListState>(
  (ref) {
    final apiService = ApiService();
    return RentalListNotifier(apiService);
  },
);

final myRentalsProvider = StateNotifierProvider.autoDispose<RentalListNotifier, RentalListState>(
  (ref) {
    final apiService = ApiService();
    // TODO: Get current user ID from auth provider
    return RentalListNotifier(apiService, renterId: 1);
  },
);

final rentalDetailProvider = StateNotifierProvider.family<RentalDetailNotifier, RentalDetailState, int>(
  (ref, rentalId) {
    final apiService = ApiService();
    return RentalDetailNotifier(apiService, rentalId);
  },
);

final activeRentalsProvider = StateNotifierProvider.autoDispose<RentalListNotifier, RentalListState>(
  (ref) {
    final apiService = ApiService();
    return RentalListNotifier(apiService, statusFilter: 'active');
  },
);

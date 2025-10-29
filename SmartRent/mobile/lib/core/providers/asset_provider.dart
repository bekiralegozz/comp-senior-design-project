import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/api_service.dart';
import '../../services/models.dart';

// Asset List State
class AssetListState {
  final List<Asset> assets;
  final bool isLoading;
  final String? error;
  final bool hasMore;
  final int currentPage;

  const AssetListState({
    this.assets = const [],
    this.isLoading = false,
    this.error,
    this.hasMore = true,
    this.currentPage = 0,
  });

  AssetListState copyWith({
    List<Asset>? assets,
    bool? isLoading,
    String? error,
    bool? hasMore,
    int? currentPage,
  }) {
    return AssetListState(
      assets: assets ?? this.assets,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      hasMore: hasMore ?? this.hasMore,
      currentPage: currentPage ?? this.currentPage,
    );
  }
}

// Asset List Notifier
class AssetListNotifier extends StateNotifier<AssetListState> {
  final ApiService _apiService;
  final String? category;
  final bool availableOnly;

  AssetListNotifier(
    this._apiService, {
    this.category,
    this.availableOnly = true,
  }) : super(const AssetListState()) {
    loadAssets();
  }

  Future<void> loadAssets({bool refresh = false}) async {
    if (state.isLoading) return;
    
    if (refresh) {
      state = const AssetListState(isLoading: true);
    } else {
      state = state.copyWith(isLoading: true, error: null);
    }

    try {
      final assets = await _apiService.getAssets(
        skip: refresh ? 0 : state.currentPage * 20,
        limit: 20,
        category: category,
        availableOnly: availableOnly,
      );

      if (refresh) {
        state = AssetListState(
          assets: assets,
          isLoading: false,
          hasMore: assets.length >= 20,
          currentPage: 1,
        );
      } else {
        state = state.copyWith(
          assets: [...state.assets, ...assets],
          isLoading: false,
          hasMore: assets.length >= 20,
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

  Future<void> refresh() => loadAssets(refresh: true);
}

// Asset Detail State
class AssetDetailState {
  final Asset? asset;
  final bool isLoading;
  final String? error;

  const AssetDetailState({
    this.asset,
    this.isLoading = false,
    this.error,
  });

  AssetDetailState copyWith({
    Asset? asset,
    bool? isLoading,
    String? error,
  }) {
    return AssetDetailState(
      asset: asset ?? this.asset,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

// Asset Detail Notifier
class AssetDetailNotifier extends StateNotifier<AssetDetailState> {
  final ApiService _apiService;
  final int assetId;

  AssetDetailNotifier(this._apiService, this.assetId) : super(const AssetDetailState()) {
    loadAsset();
  }

  Future<void> loadAsset() async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final asset = await _apiService.getAsset(assetId);
      state = state.copyWith(asset: asset, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<bool> toggleAvailability() async {
    if (state.asset == null) return false;

    try {
      final updatedAsset = await _apiService.toggleAssetAvailability(assetId);
      state = state.copyWith(asset: updatedAsset);
      return true;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }
}

// Providers
final assetListProvider = StateNotifierProvider.family<AssetListNotifier, AssetListState, String?>(
  (ref, category) {
    final apiService = ApiService();
    return AssetListNotifier(apiService, category: category);
  },
);

final assetDetailProvider = StateNotifierProvider.family<AssetDetailNotifier, AssetDetailState, int>(
  (ref, assetId) {
    final apiService = ApiService();
    return AssetDetailNotifier(apiService, assetId);
  },
);

// My Assets Provider
final myAssetsProvider = StateNotifierProvider<AssetListNotifier, AssetListState>((ref) {
  final apiService = ApiService();
  return AssetListNotifier(apiService, availableOnly: false);
});

// Asset Categories Provider
final assetCategoriesProvider = FutureProvider<List<String>>((ref) async {
  final apiService = ApiService();
  return await apiService.getAssetCategories();
});

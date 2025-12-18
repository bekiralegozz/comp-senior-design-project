import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/models.dart';
import '../../services/nft_service.dart';
import '../../services/nft_models.dart';
import '../../services/api_service.dart';
import 'auth_provider.dart';

/// ==========================================================
/// ASSET PROVIDER - BLOCKCHAIN MIGRATION VERSION
/// ==========================================================
///
/// This provider is transitioning from database to blockchain.
/// Currently uses NFT service to fetch blockchain assets.

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
    this.hasMore = false,
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

// Asset List Notifier - Now fetches from blockchain
class AssetListNotifier extends StateNotifier<AssetListState> {
  final NftService _nftService;
  final ApiService _apiService;
  final String? ownerAddress;
  final String? category;
  final bool availableOnly;

  AssetListNotifier(
    this._nftService,
    this._apiService, {
    this.ownerAddress,
    this.category,
    this.availableOnly = true,
  }) : super(const AssetListState()) {
    loadAssets();
  }

  Future<void> loadAssets({bool refresh = false}) async {
    if (state.isLoading && !refresh) return;

    state = state.copyWith(isLoading: true, error: null);

    try {
      // Fetch NFT assets from backend (blockchain-based)
      final response = await _apiService.getNftAssets(
        ownerAddress: ownerAddress,
        limit: 20,
      );
      
      final nftAssetsData = response['assets'] as List<dynamic>;
      
      // Convert to Asset model
      final assets = nftAssetsData.map((data) {
        final nftData = data as Map<String, dynamic>;
        return Asset(
          id: nftData['token_id'].toString(),
          title: 'NFT #${nftData['token_id']}',
          description: 'Fractional Real Estate NFT',
          category: 'housing',
          pricePerDay: 0.0,
          currency: 'POL',
          imageUrl: null,
          ownerWalletAddress: nftData['contract_address'],
          isAvailable: true,
          tokenId: nftData['token_id'],
          createdAt: DateTime.now(),
        );
      }).toList();

      state = state.copyWith(
        assets: assets,
        isLoading: false,
        hasMore: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to load blockchain assets: $e',
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
  final NftService _nftService;
  final int tokenId;

  AssetDetailNotifier(this._nftService, this.tokenId) : super(const AssetDetailState()) {
    loadAsset();
  }

  Future<void> loadAsset() async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final nftAsset = await _nftService.getAssetDetails(tokenId);
      
      if (nftAsset != null) {
        final asset = Asset(
          id: nftAsset.tokenId.toString(),
          title: nftAsset.name,
          description: nftAsset.description,
          category: 'housing',
          pricePerDay: nftAsset.pricePerShare,
          currency: 'MATIC',
          imageUrl: nftAsset.imageUrl,
          ownerWalletAddress: nftAsset.contractAddress,
          isAvailable: true,
          tokenId: nftAsset.tokenId,
          contractAddress: nftAsset.contractAddress,
          metadataUri: nftAsset.metadataUri,
          createdAt: DateTime.now(),
        );
        state = state.copyWith(asset: asset, isLoading: false);
      } else {
        state = state.copyWith(
          isLoading: false,
          error: 'Asset not found on blockchain',
        );
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }
}

// Providers
final nftServiceProvider = Provider<NftService>((ref) {
  return NftService();
});

final assetListProvider = StateNotifierProvider.family<AssetListNotifier, AssetListState, String?>(
  (ref, category) {
    final nftService = ref.watch(nftServiceProvider);
    final apiService = ApiService();
    final walletAddress = ref.watch(walletAddressProvider);
    return AssetListNotifier(
      nftService,
      apiService,
      ownerAddress: walletAddress,
      category: category,
    );
  },
);

final assetDetailProvider = StateNotifierProvider.family<AssetDetailNotifier, AssetDetailState, int>(
  (ref, tokenId) {
    final nftService = ref.watch(nftServiceProvider);
    return AssetDetailNotifier(nftService, tokenId);
  },
);

// My Assets Provider - Assets owned by connected wallet
final myAssetsProvider = StateNotifierProvider<AssetListNotifier, AssetListState>((ref) {
  final nftService = ref.watch(nftServiceProvider);
  final apiService = ApiService();
  final walletAddress = ref.watch(walletAddressProvider);
  return AssetListNotifier(
    nftService,
    apiService,
    ownerAddress: walletAddress,
    availableOnly: false,
  );
});

// All Assets Provider - Shows ALL minted NFTs in the collection (no owner filter)
final allAssetsProvider = StateNotifierProvider<AssetListNotifier, AssetListState>((ref) {
  final nftService = ref.watch(nftServiceProvider);
  final apiService = ApiService();
  return AssetListNotifier(
    nftService,
    apiService,
    ownerAddress: null,  // No filter - show all assets in collection
    availableOnly: false,
  );
});

// Asset Categories Provider - Static list for now
final assetCategoriesProvider = Provider<List<String>>((ref) {
  return ['housing', 'vehicles', 'electronics', 'tools', 'furniture', 'sports', 'books', 'clothing', 'other'];
});

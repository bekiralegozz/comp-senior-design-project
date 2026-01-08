import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/models.dart';
import '../../services/nft_service.dart';
import '../../services/nft_models.dart';
import '../../services/api_service.dart';
import '../../services/rental_service.dart';
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

  AssetDetailNotifier(this._nftService, this.tokenId)
      : super(const AssetDetailState()) {
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

final assetListProvider =
    StateNotifierProvider.family<AssetListNotifier, AssetListState, String?>(
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

final assetDetailProvider =
    StateNotifierProvider.family<AssetDetailNotifier, AssetDetailState, int>(
  (ref, tokenId) {
    final nftService = ref.watch(nftServiceProvider);
    return AssetDetailNotifier(nftService, tokenId);
  },
);

// My Assets Provider - Assets owned by connected wallet
final myAssetsProvider =
    StateNotifierProvider<AssetListNotifier, AssetListState>((ref) {
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
final allAssetsProvider =
    StateNotifierProvider<AssetListNotifier, AssetListState>((ref) {
  final nftService = ref.watch(nftServiceProvider);
  final apiService = ApiService();
  return AssetListNotifier(
    nftService,
    apiService,
    ownerAddress: null, // No filter - show all assets in collection
    availableOnly: false,
  );
});

// Asset Categories Provider - Static list for now
final assetCategoriesProvider = Provider<List<String>>((ref) {
  return [
    'housing',
    'vehicles',
    'electronics',
    'tools',
    'furniture',
    'sports',
    'books',
    'clothing',
    'other'
  ];
});

// ============================================
// MARKETPLACE LISTINGS (SmartRentHub)
// ============================================

/// Listing model from SmartRentHub
class MarketplaceListing {
  final int listingId;
  final int tokenId;
  final String seller;
  final int sharesForSale;
  final int sharesRemaining;
  final double pricePerSharePol;
  final bool isActive;
  final int createdAt;
  final String assetName;
  final String assetImage;
  final int totalShares;

  MarketplaceListing({
    required this.listingId,
    required this.tokenId,
    required this.seller,
    required this.sharesForSale,
    required this.sharesRemaining,
    required this.pricePerSharePol,
    required this.isActive,
    required this.createdAt,
    required this.assetName,
    required this.assetImage,
    required this.totalShares,
  });

  factory MarketplaceListing.fromJson(Map<String, dynamic> json) {
    return MarketplaceListing(
      listingId: int.tryParse(json['listing_id']?.toString() ?? '0') ?? 0,
      tokenId: int.tryParse(json['token_id']?.toString() ?? '0') ?? 0,
      seller: (json['seller'] ?? '').toString(),
      sharesForSale:
          int.tryParse(json['shares_for_sale']?.toString() ?? '0') ?? 0,
      sharesRemaining:
          int.tryParse(json['shares_remaining']?.toString() ?? '0') ?? 0,
      pricePerSharePol:
          double.tryParse(json['price_per_share_pol']?.toString() ?? '0') ??
              0.0,
      isActive: json['is_active'] == true || json['is_active'] == 'true',
      createdAt: int.tryParse(json['created_at']?.toString() ?? '0') ?? 0,
      assetName:
          (json['asset_name'] ?? 'Asset #${json['token_id']}').toString(),
      assetImage: (json['asset_image'] ?? '').toString(),
      totalShares:
          int.tryParse(json['total_shares']?.toString() ?? '1000') ?? 1000,
    );
  }

  double get totalPrice => sharesRemaining * pricePerSharePol;
  double get percentageForSale => (sharesRemaining / totalShares) * 100;
}

/// Listings State
class ListingsState {
  final List<MarketplaceListing> listings;
  final bool isLoading;
  final String? error;

  const ListingsState({
    this.listings = const [],
    this.isLoading = false,
    this.error,
  });

  ListingsState copyWith({
    List<MarketplaceListing>? listings,
    bool? isLoading,
    String? error,
  }) {
    return ListingsState(
      listings: listings ?? this.listings,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

/// Listings Notifier
class ListingsNotifier extends StateNotifier<ListingsState> {
  final ApiService _apiService;

  ListingsNotifier(this._apiService) : super(const ListingsState()) {
    loadListings();
  }

  Future<void> loadListings() async {
    if (state.isLoading) return;

    state = state.copyWith(isLoading: true, error: null);

    try {
      final response = await _apiService.getListings();
      final listingsData = response['listings'] as List<dynamic>;

      final listings = listingsData
          .map((data) =>
              MarketplaceListing.fromJson(data as Map<String, dynamic>))
          .where((listing) => listing.isActive)
          .toList();

      state = state.copyWith(
        listings: listings,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to load listings: $e',
      );
    }
  }

  Future<void> refresh() => loadListings();
}

/// Listings Provider - Active marketplace listings from SmartRentHub
final listingsProvider =
    StateNotifierProvider<ListingsNotifier, ListingsState>((ref) {
  final apiService = ApiService();
  return ListingsNotifier(apiService);
});

/// My Listings Provider - Listings by connected wallet
final myListingsProvider =
    FutureProvider<List<MarketplaceListing>>((ref) async {
  final walletAddress = ref.watch(walletAddressProvider);
  if (walletAddress == null) return [];

  final apiService = ApiService();
  await apiService.initialize();

  try {
    final response = await apiService.getMyListings(walletAddress);
    final listingsData = response['listings'] as List<dynamic>;
    return listingsData
        .map(
            (data) => MarketplaceListing.fromJson(data as Map<String, dynamic>))
        .toList();
  } catch (e) {
    return [];
  }
});

// ============================================
// NFT PORTFOLIO HOLDINGS
// ============================================

/// NFT Holdings State - for displaying user's NFT portfolio
class NftHoldingsState {
  final List<UserNftHolding> holdings;
  final Set<int> tokensWithRentalListings;
  final bool isLoading;
  final String? error;

  const NftHoldingsState({
    this.holdings = const [],
    this.tokensWithRentalListings = const {},
    this.isLoading = false,
    this.error,
  });

  NftHoldingsState copyWith({
    List<UserNftHolding>? holdings,
    Set<int>? tokensWithRentalListings,
    bool? isLoading,
    String? error,
  }) {
    return NftHoldingsState(
      holdings: holdings ?? this.holdings,
      tokensWithRentalListings:
          tokensWithRentalListings ?? this.tokensWithRentalListings,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

/// NFT Holdings Notifier - Fetches user's NFT holdings from API
class NftHoldingsNotifier extends StateNotifier<NftHoldingsState> {
  final NftService _nftService;
  final String? walletAddress;

  NftHoldingsNotifier(this._nftService, this.walletAddress)
      : super(const NftHoldingsState()) {
    if (walletAddress != null && walletAddress!.isNotEmpty) {
      loadHoldings();
    }
  }

  Future<void> loadHoldings() async {
    if (walletAddress == null || walletAddress!.isEmpty) {
      state = state.copyWith(
        error: 'Wallet not connected',
        isLoading: false,
      );
      return;
    }

    if (state.isLoading) return;

    state = state.copyWith(isLoading: true, error: null);

    try {
      // Load holdings and rental listings in parallel for better performance
      final holdingsFuture = _nftService.getUserHoldings(walletAddress!);
      final rentalListingsFuture = _loadRentalListings();

      final results = await Future.wait([holdingsFuture, rentalListingsFuture]);

      final holdings = results[0] as List<UserNftHolding>;
      final tokensWithListings = results[1] as Set<int>;

      state = state.copyWith(
        holdings: holdings,
        tokensWithRentalListings: tokensWithListings,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to load NFT holdings: $e',
      );
    }
  }

  Future<Set<int>> _loadRentalListings() async {
    try {
      final rentalService = RentalService();
      final allListings = await rentalService.getAllRentalListings();
      final tokensWithListings = <int>{};

      for (final listing in allListings) {
        if (listing.isActive &&
            listing.owner.toLowerCase() == walletAddress!.toLowerCase()) {
          tokensWithListings.add(listing.tokenId);
        }
      }

      return tokensWithListings;
    } catch (e) {
      print('Error checking rental listings: $e');
      return {};
    }
  }

  Future<void> refresh() => loadHoldings();
}

/// NFT Holdings Provider - User's NFT portfolio with rental listing status
final nftHoldingsProvider = StateNotifierProvider.family<NftHoldingsNotifier,
    NftHoldingsState, String?>((ref, walletAddress) {
  final nftService = ref.watch(nftServiceProvider);
  return NftHoldingsNotifier(nftService, walletAddress);
});

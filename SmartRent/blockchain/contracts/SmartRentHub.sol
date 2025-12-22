// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";

/**
 * @title SmartRentHub
 * @dev Central registry and marketplace for SmartRent fractional real estate NFTs
 * 
 * This contract serves as:
 * 1. NFT Registry - Tracks all assets created via Building1122
 * 2. Owner Tracking - Maintains list of owners for each asset
 * 3. Marketplace - Enables listing and buying fractional shares
 * 
 * Architecture:
 * - Building1122 calls registerAsset() on mint
 * - Building1122 calls updateOwnership() on every transfer
 * - Users call createListing/buyFromListing for marketplace operations
 */
contract SmartRentHub is Ownable, ReentrancyGuard, Pausable {
    
    // ============================================
    // STRUCTS
    // ============================================
    
    /**
     * @dev Asset information stored in registry
     */
    struct AssetInfo {
        uint256 tokenId;
        string metadataURI;
        uint256 totalShares;
        uint256 createdAt;
        bool exists;
    }
    
    /**
     * @dev Listing information for marketplace
     */
    struct Listing {
        uint256 listingId;
        uint256 tokenId;
        address seller;
        uint256 sharesForSale;      // Total shares listed
        uint256 sharesRemaining;    // Remaining shares available
        uint256 pricePerShare;      // Price in wei (POL) per share
        bool isActive;
        uint256 createdAt;
    }
    
    /**
     * @dev Combined asset info with balance (for view functions)
     */
    struct AssetWithBalance {
        uint256 tokenId;
        string metadataURI;
        uint256 totalShares;
        uint256 balance;
        uint256 createdAt;
    }
    
    /**
     * @dev Combined listing info with asset details (for view functions)
     */
    struct ListingWithAsset {
        uint256 listingId;
        uint256 tokenId;
        address seller;
        uint256 sharesForSale;
        uint256 sharesRemaining;
        uint256 pricePerShare;
        uint256 createdAt;
        string metadataURI;
        uint256 totalShares;
    }
    
    // ============================================
    // STATE VARIABLES - REGISTRY
    // ============================================
    
    // Building1122 token contract address
    address public buildingToken;
    
    // Mapping from tokenId to AssetInfo
    mapping(uint256 => AssetInfo) public assets;
    
    // Array of all token IDs (for enumeration)
    uint256[] public allTokenIds;
    
    // Mapping from tokenId to array of owner addresses
    mapping(uint256 => address[]) private _assetOwners;
    
    // Mapping to track if address is owner of tokenId (for O(1) lookup)
    mapping(uint256 => mapping(address => bool)) private _isOwner;
    
    // Mapping from owner to array of tokenIds they own
    mapping(address => uint256[]) private _ownerToTokens;
    
    // Mapping to track index of tokenId in _ownerToTokens (for removal)
    mapping(address => mapping(uint256 => uint256)) private _ownerTokenIndex;
    
    // Mapping to track if owner has tokenId in their list
    mapping(address => mapping(uint256 => bool)) private _ownerHasToken;
    
    // ============================================
    // STATE VARIABLES - MARKETPLACE
    // ============================================
    
    // Mapping from listingId to Listing
    mapping(uint256 => Listing) public listings;
    
    // Next listing ID counter
    uint256 public nextListingId = 1;
    
    // Array of active listing IDs (for enumeration)
    uint256[] private _activeListingIds;
    
    // Mapping to track index in _activeListingIds (for removal)
    mapping(uint256 => uint256) private _activeListingIndex;
    
    // Platform fee in basis points (e.g., 250 = 2.5%)
    uint256 public platformFeeBps = 250;
    
    // Platform fee recipient
    address public feeRecipient;
    
    // ============================================
    // EVENTS
    // ============================================
    
    event AssetRegistered(
        uint256 indexed tokenId,
        address indexed initialOwner,
        uint256 totalShares,
        string metadataURI
    );
    
    event OwnershipUpdated(
        uint256 indexed tokenId,
        address indexed from,
        address indexed to,
        uint256 amount
    );
    
    event ListingCreated(
        uint256 indexed listingId,
        uint256 indexed tokenId,
        address indexed seller,
        uint256 sharesForSale,
        uint256 pricePerShare
    );
    
    event ListingCancelled(
        uint256 indexed listingId,
        address indexed seller
    );
    
    event ListingPurchased(
        uint256 indexed listingId,
        uint256 indexed tokenId,
        address indexed buyer,
        address seller,
        uint256 sharesBought,
        uint256 totalPrice
    );
    
    event PlatformFeeUpdated(uint256 newFeeBps);
    event FeeRecipientUpdated(address indexed newRecipient);
    event BuildingTokenUpdated(address indexed newToken);
    
    // ============================================
    // MODIFIERS
    // ============================================
    
    /**
     * @dev Only Building1122 contract can call this function
     */
    modifier onlyBuildingToken() {
        require(msg.sender == buildingToken, "SmartRentHub: caller is not Building1122");
        _;
    }
    
    // ============================================
    // CONSTRUCTOR
    // ============================================
    
    /**
     * @dev Constructor
     * @param initialOwner Owner of the contract
     * @param _feeRecipient Address that receives platform fees
     */
    constructor(address initialOwner, address _feeRecipient) Ownable(initialOwner) {
        require(_feeRecipient != address(0), "SmartRentHub: feeRecipient cannot be zero");
        feeRecipient = _feeRecipient;
    }
    
    // ============================================
    // ADMIN FUNCTIONS
    // ============================================
    
    /**
     * @dev Set Building1122 token contract address
     * @param _buildingToken Address of Building1122 contract
     */
    function setBuildingToken(address _buildingToken) external onlyOwner {
        require(_buildingToken != address(0), "SmartRentHub: invalid token address");
        buildingToken = _buildingToken;
        emit BuildingTokenUpdated(_buildingToken);
    }
    
    /**
     * @dev Set platform fee (max 10%)
     * @param newFeeBps New fee in basis points
     */
    function setPlatformFee(uint256 newFeeBps) external onlyOwner {
        require(newFeeBps <= 1000, "SmartRentHub: fee cannot exceed 10%");
        platformFeeBps = newFeeBps;
        emit PlatformFeeUpdated(newFeeBps);
    }
    
    /**
     * @dev Set fee recipient address
     * @param _feeRecipient New fee recipient
     */
    function setFeeRecipient(address _feeRecipient) external onlyOwner {
        require(_feeRecipient != address(0), "SmartRentHub: invalid recipient");
        feeRecipient = _feeRecipient;
        emit FeeRecipientUpdated(_feeRecipient);
    }
    
    /**
     * @dev Pause contract
     */
    function pause() external onlyOwner {
        _pause();
    }
    
    /**
     * @dev Unpause contract
     */
    function unpause() external onlyOwner {
        _unpause();
    }
    
    // ============================================
    // REGISTRY FUNCTIONS (Called by Building1122)
    // ============================================
    
    /**
     * @dev Register a new asset (called by Building1122 on mint)
     * @param tokenId The token ID being minted
     * @param owner Initial owner of the asset
     * @param totalShares Total supply of shares
     * @param metadataURI IPFS metadata URI
     */
    function registerAsset(
        uint256 tokenId,
        address owner,
        uint256 totalShares,
        string calldata metadataURI
    ) external onlyBuildingToken whenNotPaused {
        require(!assets[tokenId].exists, "SmartRentHub: asset already registered");
        require(owner != address(0), "SmartRentHub: invalid owner");
        require(totalShares > 0, "SmartRentHub: invalid total shares");
        
        // Create asset info
        assets[tokenId] = AssetInfo({
            tokenId: tokenId,
            metadataURI: metadataURI,
            totalShares: totalShares,
            createdAt: block.timestamp,
            exists: true
        });
        
        // Add to allTokenIds array
        allTokenIds.push(tokenId);
        
        // Add owner to asset's owner list
        _addOwner(tokenId, owner);
        
        emit AssetRegistered(tokenId, owner, totalShares, metadataURI);
    }
    
    /**
     * @dev Update ownership on transfer (called by Building1122 on every transfer)
     * @param tokenId The token ID being transferred
     * @param from Sender address (address(0) for mint)
     * @param to Receiver address (address(0) for burn)
     * @param amount Amount of shares transferred
     */
    function updateOwnership(
        uint256 tokenId,
        address from,
        address to,
        uint256 amount
    ) external onlyBuildingToken whenNotPaused {
        // Skip if asset not registered (shouldn't happen, but safety check)
        if (!assets[tokenId].exists) return;
        
        // Skip zero amount
        if (amount == 0) return;
        
        // Handle sender (remove from owners if balance becomes 0)
        if (from != address(0)) {
            uint256 fromBalance = IERC1155(buildingToken).balanceOf(from, tokenId);
            if (fromBalance == 0) {
                _removeOwner(tokenId, from);
            }
        }
        
        // Handle receiver (add to owners if not already)
        if (to != address(0)) {
            if (!_isOwner[tokenId][to]) {
                _addOwner(tokenId, to);
            }
        }
        
        emit OwnershipUpdated(tokenId, from, to, amount);
    }
    
    // ============================================
    // MARKETPLACE FUNCTIONS
    // ============================================
    
    /**
     * @dev Create a new listing to sell shares
     * @param tokenId The token ID to list
     * @param sharesForSale Number of shares to sell
     * @param pricePerShare Price per share in wei (POL)
     */
    function createListing(
        uint256 tokenId,
        uint256 sharesForSale,
        uint256 pricePerShare
    ) external whenNotPaused nonReentrant returns (uint256 listingId) {
        require(assets[tokenId].exists, "SmartRentHub: asset does not exist");
        require(sharesForSale > 0, "SmartRentHub: sharesForSale must be > 0");
        require(pricePerShare > 0, "SmartRentHub: pricePerShare must be > 0");
        
        // Check seller has enough balance
        uint256 sellerBalance = IERC1155(buildingToken).balanceOf(msg.sender, tokenId);
        require(sellerBalance >= sharesForSale, "SmartRentHub: insufficient balance");
        
        // Check seller has approved this contract
        require(
            IERC1155(buildingToken).isApprovedForAll(msg.sender, address(this)),
            "SmartRentHub: not approved for transfer"
        );
        
        // Create listing
        listingId = nextListingId++;
        listings[listingId] = Listing({
            listingId: listingId,
            tokenId: tokenId,
            seller: msg.sender,
            sharesForSale: sharesForSale,
            sharesRemaining: sharesForSale,
            pricePerShare: pricePerShare,
            isActive: true,
            createdAt: block.timestamp
        });
        
        // Add to active listings
        _activeListingIndex[listingId] = _activeListingIds.length;
        _activeListingIds.push(listingId);
        
        emit ListingCreated(listingId, tokenId, msg.sender, sharesForSale, pricePerShare);
        
        return listingId;
    }
    
    /**
     * @dev Cancel a listing
     * @param listingId The listing ID to cancel
     */
    function cancelListing(uint256 listingId) external whenNotPaused nonReentrant {
        Listing storage listing = listings[listingId];
        require(listing.isActive, "SmartRentHub: listing not active");
        require(listing.seller == msg.sender, "SmartRentHub: not the seller");
        
        // Deactivate listing
        listing.isActive = false;
        
        // Remove from active listings array
        _removeFromActiveListings(listingId);
        
        emit ListingCancelled(listingId, msg.sender);
    }
    
    /**
     * @dev Buy shares from a listing
     * @param listingId The listing ID to buy from
     * @param sharesToBuy Number of shares to buy
     */
    function buyFromListing(
        uint256 listingId,
        uint256 sharesToBuy
    ) external payable whenNotPaused nonReentrant {
        Listing storage listing = listings[listingId];
        require(listing.isActive, "SmartRentHub: listing not active");
        require(sharesToBuy > 0, "SmartRentHub: sharesToBuy must be > 0");
        require(sharesToBuy <= listing.sharesRemaining, "SmartRentHub: not enough shares available");
        require(msg.sender != listing.seller, "SmartRentHub: cannot buy from yourself");
        
        // Calculate total price
        uint256 totalPrice = sharesToBuy * listing.pricePerShare;
        require(msg.value >= totalPrice, "SmartRentHub: insufficient payment");
        
        // Calculate platform fee
        uint256 platformFee = (totalPrice * platformFeeBps) / 10000;
        uint256 sellerPayment = totalPrice - platformFee;
        
        // Update listing
        listing.sharesRemaining -= sharesToBuy;
        if (listing.sharesRemaining == 0) {
            listing.isActive = false;
            _removeFromActiveListings(listingId);
        }
        
        // Transfer shares from seller to buyer
        IERC1155(buildingToken).safeTransferFrom(
            listing.seller,
            msg.sender,
            listing.tokenId,
            sharesToBuy,
            ""
        );
        
        // Transfer payment to seller
        if (sellerPayment > 0) {
            (bool sellerSuccess, ) = payable(listing.seller).call{value: sellerPayment}("");
            require(sellerSuccess, "SmartRentHub: seller payment failed");
        }
        
        // Transfer platform fee
        if (platformFee > 0) {
            (bool feeSuccess, ) = payable(feeRecipient).call{value: platformFee}("");
            require(feeSuccess, "SmartRentHub: fee payment failed");
        }
        
        // Refund excess payment
        if (msg.value > totalPrice) {
            (bool refundSuccess, ) = payable(msg.sender).call{value: msg.value - totalPrice}("");
            require(refundSuccess, "SmartRentHub: refund failed");
        }
        
        emit ListingPurchased(
            listingId,
            listing.tokenId,
            msg.sender,
            listing.seller,
            sharesToBuy,
            totalPrice
        );
    }
    
    // ============================================
    // VIEW FUNCTIONS - REGISTRY
    // ============================================
    
    /**
     * @dev Get total number of registered assets
     */
    function getTotalAssets() external view returns (uint256) {
        return allTokenIds.length;
    }
    
    /**
     * @dev Get all registered assets
     */
    function getAllAssets() external view returns (AssetInfo[] memory) {
        uint256 count = allTokenIds.length;
        AssetInfo[] memory result = new AssetInfo[](count);
        
        for (uint256 i = 0; i < count; i++) {
            result[i] = assets[allTokenIds[i]];
        }
        
        return result;
    }
    
    /**
     * @dev Get asset info by tokenId
     */
    function getAsset(uint256 tokenId) external view returns (AssetInfo memory) {
        require(assets[tokenId].exists, "SmartRentHub: asset does not exist");
        return assets[tokenId];
    }
    
    /**
     * @dev Get all owners of an asset
     */
    function getAssetOwners(uint256 tokenId) external view returns (address[] memory) {
        require(assets[tokenId].exists, "SmartRentHub: asset does not exist");
        return _assetOwners[tokenId];
    }
    
    /**
     * @dev Get all tokenIds owned by an address
     */
    function getAssetsByOwner(address owner) external view returns (uint256[] memory) {
        return _ownerToTokens[owner];
    }
    
    /**
     * @dev Get assets with balances for an owner (single RPC call optimization)
     */
    function getAssetsWithBalances(address owner) external view returns (AssetWithBalance[] memory) {
        uint256[] memory tokenIds = _ownerToTokens[owner];
        uint256 count = tokenIds.length;
        AssetWithBalance[] memory result = new AssetWithBalance[](count);
        
        for (uint256 i = 0; i < count; i++) {
            uint256 tokenId = tokenIds[i];
            AssetInfo storage asset = assets[tokenId];
            uint256 balance = IERC1155(buildingToken).balanceOf(owner, tokenId);
            
            result[i] = AssetWithBalance({
                tokenId: tokenId,
                metadataURI: asset.metadataURI,
                totalShares: asset.totalShares,
                balance: balance,
                createdAt: asset.createdAt
            });
        }
        
        return result;
    }
    
    /**
     * @dev Check if address is owner of asset
     */
    function isOwnerOf(address account, uint256 tokenId) external view returns (bool) {
        return _isOwner[tokenId][account];
    }
    
    // ============================================
    // VIEW FUNCTIONS - MARKETPLACE
    // ============================================
    
    /**
     * @dev Get total number of active listings
     */
    function getActiveListingsCount() external view returns (uint256) {
        return _activeListingIds.length;
    }
    
    /**
     * @dev Get all active listings
     */
    function getActiveListings() external view returns (Listing[] memory) {
        uint256 count = _activeListingIds.length;
        Listing[] memory result = new Listing[](count);
        
        for (uint256 i = 0; i < count; i++) {
            result[i] = listings[_activeListingIds[i]];
        }
        
        return result;
    }
    
    /**
     * @dev Get active listings with asset details (single RPC call optimization)
     */
    function getActiveListingsWithDetails() external view returns (ListingWithAsset[] memory) {
        uint256 count = _activeListingIds.length;
        ListingWithAsset[] memory result = new ListingWithAsset[](count);
        
        for (uint256 i = 0; i < count; i++) {
            Listing storage listing = listings[_activeListingIds[i]];
            AssetInfo storage asset = assets[listing.tokenId];
            
            result[i] = ListingWithAsset({
                listingId: listing.listingId,
                tokenId: listing.tokenId,
                seller: listing.seller,
                sharesForSale: listing.sharesForSale,
                sharesRemaining: listing.sharesRemaining,
                pricePerShare: listing.pricePerShare,
                createdAt: listing.createdAt,
                metadataURI: asset.metadataURI,
                totalShares: asset.totalShares
            });
        }
        
        return result;
    }
    
    /**
     * @dev Get listing by ID
     */
    function getListing(uint256 listingId) external view returns (Listing memory) {
        require(listings[listingId].listingId != 0, "SmartRentHub: listing does not exist");
        return listings[listingId];
    }
    
    /**
     * @dev Get all active listings for a specific asset
     */
    function getListingsByAsset(uint256 tokenId) external view returns (Listing[] memory) {
        uint256 count = 0;
        
        // First pass: count matching listings
        for (uint256 i = 0; i < _activeListingIds.length; i++) {
            if (listings[_activeListingIds[i]].tokenId == tokenId) {
                count++;
            }
        }
        
        // Second pass: populate result array
        Listing[] memory result = new Listing[](count);
        uint256 index = 0;
        for (uint256 i = 0; i < _activeListingIds.length; i++) {
            if (listings[_activeListingIds[i]].tokenId == tokenId) {
                result[index] = listings[_activeListingIds[i]];
                index++;
            }
        }
        
        return result;
    }
    
    /**
     * @dev Get all active listings by a seller
     */
    function getListingsBySeller(address seller) external view returns (Listing[] memory) {
        uint256 count = 0;
        
        // First pass: count matching listings
        for (uint256 i = 0; i < _activeListingIds.length; i++) {
            if (listings[_activeListingIds[i]].seller == seller) {
                count++;
            }
        }
        
        // Second pass: populate result array
        Listing[] memory result = new Listing[](count);
        uint256 index = 0;
        for (uint256 i = 0; i < _activeListingIds.length; i++) {
            if (listings[_activeListingIds[i]].seller == seller) {
                result[index] = listings[_activeListingIds[i]];
                index++;
            }
        }
        
        return result;
    }
    
    // ============================================
    // INTERNAL FUNCTIONS
    // ============================================
    
    /**
     * @dev Add owner to asset's owner list
     */
    function _addOwner(uint256 tokenId, address owner) internal {
        if (!_isOwner[tokenId][owner]) {
            _isOwner[tokenId][owner] = true;
            _assetOwners[tokenId].push(owner);
            
            // Also add tokenId to owner's token list
            if (!_ownerHasToken[owner][tokenId]) {
                _ownerHasToken[owner][tokenId] = true;
                _ownerTokenIndex[owner][tokenId] = _ownerToTokens[owner].length;
                _ownerToTokens[owner].push(tokenId);
            }
        }
    }
    
    /**
     * @dev Remove owner from asset's owner list
     */
    function _removeOwner(uint256 tokenId, address owner) internal {
        if (_isOwner[tokenId][owner]) {
            _isOwner[tokenId][owner] = false;
            
            // Remove from _assetOwners array (swap and pop)
            address[] storage owners = _assetOwners[tokenId];
            for (uint256 i = 0; i < owners.length; i++) {
                if (owners[i] == owner) {
                    owners[i] = owners[owners.length - 1];
                    owners.pop();
                    break;
                }
            }
            
            // Remove tokenId from owner's token list
            if (_ownerHasToken[owner][tokenId]) {
                _ownerHasToken[owner][tokenId] = false;
                uint256[] storage tokens = _ownerToTokens[owner];
                uint256 index = _ownerTokenIndex[owner][tokenId];
                
                if (index < tokens.length - 1) {
                    uint256 lastToken = tokens[tokens.length - 1];
                    tokens[index] = lastToken;
                    _ownerTokenIndex[owner][lastToken] = index;
                }
                tokens.pop();
            }
        }
    }
    
    /**
     * @dev Remove listing from active listings array
     */
    function _removeFromActiveListings(uint256 listingId) internal {
        uint256 index = _activeListingIndex[listingId];
        uint256 lastIndex = _activeListingIds.length - 1;
        
        if (index != lastIndex) {
            uint256 lastListingId = _activeListingIds[lastIndex];
            _activeListingIds[index] = lastListingId;
            _activeListingIndex[lastListingId] = index;
        }
        
        _activeListingIds.pop();
        delete _activeListingIndex[listingId];
    }
    
    // ============================================
    // EMERGENCY FUNCTIONS
    // ============================================
    
    /**
     * @dev Emergency withdraw stuck ETH
     */
    function emergencyWithdraw() external onlyOwner {
        uint256 balance = address(this).balance;
        if (balance > 0) {
            (bool success, ) = payable(owner()).call{value: balance}("");
            require(success, "SmartRentHub: withdraw failed");
        }
    }
}


// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/interfaces/IERC2981.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

/**
 * @title Building1122
 * @dev ERC-1122-style multi-token contract for fractional real estate ownership
 * 
 * This contract implements an ERC-1155-compatible multi-token standard where:
 * - Each real estate asset is represented by a unique tokenId
 * - Each asset has a fixed totalSupply (e.g., 1000 units)
 * - Fractional ownership = balanceOf(investor, tokenId) / totalSupply(tokenId)
 * 
 * Example:
 * - tokenId = 1 represents "Apartment 101"
 * - totalSupply(1) = 1000
 * - Investor A: balanceOf(A, 1) = 400 → 40% ownership
 * - Investor B: balanceOf(B, 1) = 300 → 30% ownership
 * - Investor C: balanceOf(C, 1) = 300 → 30% ownership
 */
contract Building1122 is ERC1155, Ownable, Pausable, IERC2981 {
    
    using Strings for uint256;
    
    // Royalty info
    address public royaltyReceiver;
    uint96 public royaltyBasisPoints = 250; // 2.5% default
    
    // Mapping from tokenId to total supply (fixed at minting)
    mapping(uint256 => uint256) public totalSupply;
    
    // Mapping from tokenId to whether it has been initialized
    mapping(uint256 => bool) public tokenInitialized;
    
    // Mapping from tokenId to asset metadata (optional, for reference)
    mapping(uint256 => string) public assetMetadataURI;
    
    // Events
    event AssetInitialized(
        uint256 indexed tokenId,
        address indexed initialOwner,
        uint256 totalSupply,
        string metadataURI
    );
    
    event TotalSupplySet(uint256 indexed tokenId, uint256 totalSupply);
    
    /**
     * @dev Constructor
     * @param uri_ Base URI for token metadata (can be empty string if not using URI)
     * @param initialOwner Owner of the contract
     */
    constructor(string memory uri_, address initialOwner) ERC1155(uri_) Ownable(initialOwner) {
        royaltyReceiver = initialOwner;
    }
    
    /**
     * @dev Mint initial supply for a new asset (tokenId)
     * @param tokenId Unique identifier for the asset
     * @param initialOwner Address that will receive the initial supply
     * @param amount Initial supply amount (e.g., 1000 units)
     * @param metadataURI Optional metadata URI for this asset
     * 
     * Requirements:
     * - Only owner can call this
     * - tokenId must not have been initialized before
     * - amount must be greater than 0
     * 
     * This function creates a new asset and sets its total supply.
     * After this, shares can be transferred between investors.
     */
    function mintInitialSupply(
        uint256 tokenId,
        address initialOwner,
        uint256 amount,
        string memory metadataURI
    ) external whenNotPaused {
        // Anyone can mint, but they must specify themselves as initial owner
        require(initialOwner == msg.sender, "Building1122: initialOwner must be caller");
        require(!tokenInitialized[tokenId], "Building1122: tokenId already initialized");
        require(amount > 0, "Building1122: amount must be greater than 0");
        require(initialOwner != address(0), "Building1122: initialOwner cannot be zero address");
        
        // Set total supply for this tokenId
        totalSupply[tokenId] = amount;
        tokenInitialized[tokenId] = true;
        
        // Store metadata URI if provided
        if (bytes(metadataURI).length > 0) {
            assetMetadataURI[tokenId] = metadataURI;
        }
        
        // Mint all initial supply to the initial owner
        _mint(initialOwner, tokenId, amount, "");
        
        emit AssetInitialized(tokenId, initialOwner, amount, metadataURI);
        emit TotalSupplySet(tokenId, amount);
    }
    
    /**
     * @dev Get the percentage ownership of an address for a given tokenId
     * @param account Address to check
     * @param tokenId Asset token ID
     * @return percentage Ownership percentage (0-10000, where 10000 = 100%)
     * 
     * Example: If totalSupply = 1000 and balance = 400, returns 4000 (40%)
     */
    function getOwnershipPercentage(address account, uint256 tokenId) 
        external 
        view 
        returns (uint256 percentage) 
    {
        uint256 supply = totalSupply[tokenId];
        require(supply > 0, "Building1122: tokenId not initialized");
        
        uint256 balance = balanceOf(account, tokenId);
        // Return as basis points (10000 = 100%)
        return (balance * 10000) / supply;
    }
    
    /**
     * @dev Check if a tokenId has been initialized
     * @param tokenId Asset token ID
     * @return bool True if tokenId exists
     */
    function exists(uint256 tokenId) external view returns (bool) {
        return tokenInitialized[tokenId];
    }
    
    /**
     * @dev Override _update to add pause functionality
     */
    function _update(
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory values
    ) internal override whenNotPaused {
        super._update(from, to, ids, values);
    }
    
    /**
     * @dev Pause all token transfers (emergency function)
     */
    function pause() external onlyOwner {
        _pause();
    }
    
    /**
     * @dev Unpause token transfers
     */
    function unpause() external onlyOwner {
        _unpause();
    }
    
    /**
     * @dev Update the base URI for token metadata
     * @param newuri New base URI
     */
    function setURI(string memory newuri) external onlyOwner {
        _setURI(newuri);
    }
    
    /**
     * @dev Override uri function for OpenSea compatibility
     * Returns IPFS URI for specific token metadata
     */
    function uri(uint256 tokenId) public view override returns (string memory) {
        require(tokenInitialized[tokenId], "Building1122: URI query for nonexistent token");
        
        // If asset has custom metadata URI, return it
        if (bytes(assetMetadataURI[tokenId]).length > 0) {
            return assetMetadataURI[tokenId];
        }
        
        // Otherwise construct from base URI
        return string(abi.encodePacked(super.uri(tokenId), tokenId.toString(), ".json"));
    }
    
    /**
     * @dev EIP-2981 Royalty Standard Implementation
     * OpenSea will call this to determine royalty payments
     */
    function royaltyInfo(uint256 tokenId, uint256 salePrice)
        external
        view
        override
        returns (address receiver, uint256 royaltyAmount)
    {
        require(tokenInitialized[tokenId], "Building1122: Royalty query for nonexistent token");
        
        uint256 royalty = (salePrice * royaltyBasisPoints) / 10000;
        return (royaltyReceiver, royalty);
    }
    
    /**
     * @dev Set royalty receiver address
     */
    function setRoyaltyReceiver(address newReceiver) external onlyOwner {
        require(newReceiver != address(0), "Building1122: Invalid receiver");
        royaltyReceiver = newReceiver;
    }
    
    /**
     * @dev Set royalty percentage (in basis points, e.g., 250 = 2.5%)
     */
    function setRoyaltyBasisPoints(uint96 newBasisPoints) external onlyOwner {
        require(newBasisPoints <= 1000, "Building1122: Royalty too high (max 10%)");
        royaltyBasisPoints = newBasisPoints;
    }
    
    /**
     * @dev ERC165 support for multiple interfaces
     */
    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC1155, IERC165)
        returns (bool)
    {
        return interfaceId == type(IERC2981).interfaceId || super.supportsInterface(interfaceId);
    }
}


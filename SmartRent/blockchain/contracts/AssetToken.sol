// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

/**
 * @title AssetToken
 * @dev NFT contract for representing physical assets in SmartRent platform
 * Each token represents a unique rentable asset (car, tool, electronics, etc.)
 */
contract AssetToken is ERC721, ERC721URIStorage, Ownable {
    using Counters for Counters.Counter;

    // Token ID counter
    Counters.Counter private _tokenIdCounter;

    // Mapping from token ID to asset details
    mapping(uint256 => AssetInfo) public assets;
    
    // Mapping to track asset availability for rental
    mapping(uint256 => bool) public isAvailableForRental;
    
    // Mapping from owner to operator approvals for rental management
    mapping(address => mapping(address => bool)) private _rentalOperators;

    struct AssetInfo {
        string name;
        string description;
        string category;
        string location;
        uint256 pricePerDay; // Price in wei (ETH)
        address currentOwner;
        bool exists;
    }

    // Events
    event AssetMinted(
        uint256 indexed tokenId, 
        address indexed owner, 
        string name, 
        string category,
        uint256 pricePerDay
    );
    
    event AssetUpdated(
        uint256 indexed tokenId, 
        string name, 
        string description,
        uint256 pricePerDay
    );
    
    event RentalStatusChanged(uint256 indexed tokenId, bool available);
    event RentalOperatorSet(address indexed owner, address indexed operator, bool approved);

    constructor() ERC721("SmartRent Asset Token", "SRAT") {}

    /**
     * @dev Mint a new asset NFT
     * @param to Address that will own the token
     * @param name Asset name
     * @param description Asset description
     * @param category Asset category (e.g., "electronics", "vehicles", "tools")
     * @param location Asset location
     * @param pricePerDay Daily rental price in wei
     * @param tokenURI Token metadata URI
     */
    function mintAsset(
        address to,
        string memory name,
        string memory description,
        string memory category,
        string memory location,
        uint256 pricePerDay,
        string memory tokenURI
    ) public returns (uint256) {
        require(bytes(name).length > 0, "Asset name cannot be empty");
        require(bytes(category).length > 0, "Asset category cannot be empty");
        require(pricePerDay > 0, "Price per day must be greater than 0");
        
        uint256 tokenId = _tokenIdCounter.current();
        _tokenIdCounter.increment();
        
        _safeMint(to, tokenId);
        _setTokenURI(tokenId, tokenURI);
        
        // Store asset information
        assets[tokenId] = AssetInfo({
            name: name,
            description: description,
            category: category,
            location: location,
            pricePerDay: pricePerDay,
            currentOwner: to,
            exists: true
        });
        
        // Set as available for rental by default
        isAvailableForRental[tokenId] = true;
        
        emit AssetMinted(tokenId, to, name, category, pricePerDay);
        
        return tokenId;
    }

    /**
     * @dev Update asset information (only owner or approved operator)
     */
    function updateAsset(
        uint256 tokenId,
        string memory name,
        string memory description,
        uint256 pricePerDay
    ) public {
        require(_exists(tokenId), "Asset does not exist");
        require(
            ownerOf(tokenId) == msg.sender || isApprovedForAll(ownerOf(tokenId), msg.sender),
            "Not authorized to update this asset"
        );
        
        AssetInfo storage asset = assets[tokenId];
        
        if (bytes(name).length > 0) {
            asset.name = name;
        }
        
        asset.description = description;
        
        if (pricePerDay > 0) {
            asset.pricePerDay = pricePerDay;
        }
        
        emit AssetUpdated(tokenId, name, description, pricePerDay);
    }

    /**
     * @dev Set rental availability status
     */
    function setRentalAvailability(uint256 tokenId, bool available) public {
        require(_exists(tokenId), "Asset does not exist");
        require(
            ownerOf(tokenId) == msg.sender || 
            isApprovedForAll(ownerOf(tokenId), msg.sender) ||
            _rentalOperators[ownerOf(tokenId)][msg.sender],
            "Not authorized to change rental status"
        );
        
        isAvailableForRental[tokenId] = available;
        emit RentalStatusChanged(tokenId, available);
    }

    /**
     * @dev Set or unset approval for rental operator
     * @param operator Address to be approved/unapproved for rental management
     * @param approved True to approve, false to revoke approval
     */
    function setRentalOperator(address operator, bool approved) public {
        require(operator != msg.sender, "Cannot set yourself as operator");
        _rentalOperators[msg.sender][operator] = approved;
        emit RentalOperatorSet(msg.sender, operator, approved);
    }

    /**
     * @dev Check if an address is approved as rental operator
     */
    function isRentalOperator(address owner, address operator) public view returns (bool) {
        return _rentalOperators[owner][operator];
    }

    /**
     * @dev Get asset information
     */
    function getAsset(uint256 tokenId) public view returns (AssetInfo memory) {
        require(_exists(tokenId), "Asset does not exist");
        return assets[tokenId];
    }

    /**
     * @dev Get all assets owned by an address
     */
    function getAssetsByOwner(address owner) public view returns (uint256[] memory) {
        uint256 balance = balanceOf(owner);
        uint256[] memory result = new uint256[](balance);
        
        uint256 counter = 0;
        for (uint256 i = 0; i < _tokenIdCounter.current(); i++) {
            if (_exists(i) && ownerOf(i) == owner) {
                result[counter] = i;
                counter++;
            }
        }
        
        return result;
    }

    /**
     * @dev Get total number of minted tokens
     */
    function totalSupply() public view returns (uint256) {
        return _tokenIdCounter.current();
    }

    /**
     * @dev Override transfer to update asset owner
     */
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId,
        uint256 batchSize
    ) internal override {
        super._beforeTokenTransfer(from, to, tokenId, batchSize);
        
        if (from != address(0) && to != address(0)) {
            assets[tokenId].currentOwner = to;
        }
    }

    // Override required by Solidity for multiple inheritance
    function _burn(uint256 tokenId) internal override(ERC721, ERC721URIStorage) {
        super._burn(tokenId);
        
        // Clean up asset data
        delete assets[tokenId];
        delete isAvailableForRental[tokenId];
    }

    function tokenURI(uint256 tokenId)
        public
        view
        override(ERC721, ERC721URIStorage)
        returns (string memory)
    {
        return super.tokenURI(tokenId);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721, ERC721URIStorage)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}









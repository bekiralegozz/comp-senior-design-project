// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title BuildingToken
 * @dev ERC20 token representing ownership shares in a building
 * Each token represents a percentage of ownership in the building
 * Example: If total supply is 10000 tokens, owning 1000 tokens = 10% ownership
 */
contract BuildingToken is ERC20, Ownable {
    // Building information
    uint256 public buildingId;
    string public buildingName;
    uint256 public totalShares; // Total shares available (e.g., 10000 = 100%)
    
    // Events
    event BuildingTokenCreated(
        uint256 indexed buildingId,
        string buildingName,
        uint256 totalShares
    );
    
    event InvestmentReceived(
        address indexed investor,
        uint256 amount,
        uint256 tokensReceived
    );
    
    /**
     * @dev Constructor creates a new BuildingToken
     * @param _buildingId Unique identifier for the building
     * @param _buildingName Name of the building
     * @param _totalShares Total number of shares (tokens) available
     * @param _owner Address that will own this token contract
     */
    constructor(
        uint256 _buildingId,
        string memory _buildingName,
        uint256 _totalShares,
        address _owner
    ) ERC20(string(abi.encodePacked(_buildingName, " Share")), string(abi.encodePacked(_buildingName, "SHARE"))) {
        require(_totalShares > 0, "Total shares must be greater than 0");
        require(_owner != address(0), "Owner cannot be zero address");
        
        buildingId = _buildingId;
        buildingName = _buildingName;
        totalShares = _totalShares;
        
        // Transfer ownership to the specified owner
        _transferOwnership(_owner);
        
        emit BuildingTokenCreated(_buildingId, _buildingName, _totalShares);
    }
    
    /**
     * @dev Mint tokens to an investor
     * @param to Address to receive the tokens
     * @param amount Amount of ETH invested
     * @param tokensToMint Number of tokens to mint
     */
    function mint(address to, uint256 amount, uint256 tokensToMint) external onlyOwner {
        require(to != address(0), "Cannot mint to zero address");
        require(tokensToMint > 0, "Tokens to mint must be greater than 0");
        require(totalSupply() + tokensToMint <= totalShares, "Cannot exceed total shares");
        
        _mint(to, tokensToMint);
        
        emit InvestmentReceived(to, amount, tokensToMint);
    }
    
    /**
     * @dev Get the ownership percentage of an address
     * @param account Address to check
     * @return Percentage of ownership (e.g., 1000 = 10% if total shares is 10000)
     */
    function getOwnershipPercentage(address account) external view returns (uint256) {
        if (totalShares == 0) return 0;
        return (balanceOf(account) * 10000) / totalShares; // Returns in basis points (10000 = 100%)
    }
    
    /**
     * @dev Get the ownership percentage as a decimal (0-100)
     * @param account Address to check
     * @return Percentage as a number from 0 to 100
     */
    function getOwnershipPercentageDecimal(address account) external view returns (uint256) {
        if (totalShares == 0) return 0;
        return (balanceOf(account) * 100) / totalShares;
    }
    
    /**
     * @dev Check if all shares have been sold
     * @return True if all shares are distributed
     */
    function isFullyInvested() external view returns (bool) {
        return totalSupply() >= totalShares;
    }
    
    /**
     * @dev Get remaining shares available for investment
     * @return Number of shares still available
     */
    function getRemainingShares() external view returns (uint256) {
        if (totalSupply() >= totalShares) return 0;
        return totalShares - totalSupply();
    }
}


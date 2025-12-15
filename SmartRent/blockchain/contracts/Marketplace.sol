// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "./Building1122.sol";

/**
 * @title Marketplace
 * @dev Marketplace for trading fractional ownership shares
 * 
 * Allows investors to buy and sell shares of real estate assets.
 * Supports payments in ETH (native currency) only.
 * 
 * Example scenario:
 * - tokenId = 1, totalSupply = 1000
 * - Investor A: 400 shares (40%), Investor B: 300 (30%), Investor C: 300 (30%)
 * - A wants to buy C's 300 shares
 * - A calls buyShare(1, C, 300) with ETH payment
 * - 300 shares transfer from C to A
 * - New state: A: 700 (70%), B: 300 (30%), C: 0 (0%)
 */
contract Marketplace is Ownable, ReentrancyGuard, Pausable {
    
    Building1122 public immutable buildingToken;
    
    // Platform fee (in basis points, e.g., 250 = 2.5%)
    uint256 public platformFeeBps = 250; // 2.5% default
    address public feeRecipient;
    
    // Events
    event ShareTraded(
        uint256 indexed tokenId,
        address indexed buyer,
        address indexed seller,
        uint256 shareAmount,
        uint256 ethAmount,
        uint256 timestamp
    );
    
    event PlatformFeeUpdated(uint256 newFeeBps);
    event FeeRecipientUpdated(address indexed oldRecipient, address indexed newRecipient);
    
    /**
     * @dev Constructor
     * @param _buildingToken Address of the Building1122 contract
     * @param _feeRecipient Address that receives platform fees
     */
    constructor(
        address _buildingToken,
        address _feeRecipient,
        address initialOwner
    ) Ownable(initialOwner) {
        require(_buildingToken != address(0), "Marketplace: buildingToken cannot be zero");
        require(_feeRecipient != address(0), "Marketplace: feeRecipient cannot be zero");
        
        buildingToken = Building1122(_buildingToken);
        feeRecipient = _feeRecipient;
    }
    
    /**
     * @dev Buy shares from a seller using ETH
     * @param tokenId The asset tokenId
     * @param seller Address selling the shares
     * @param shareAmount Amount of shares to buy (must match seller's balance or less)
     * 
     * Requirements:
     * - Asset must exist
     * - Seller must have sufficient balance
     * - msg.value must cover the purchase price (price is determined by the transaction)
     * 
     * Process:
     * 1. Buyer sends ETH with transaction
     * 2. Contract calculates platform fee
     * 3. Transfers shareAmount of tokenId from seller to buyer
     * 4. Sends ETH to seller (minus platform fee)
     * 5. Sends platform fee to feeRecipient
     */
    function buyShare(
        uint256 tokenId,
        address seller,
        uint256 shareAmount
    ) 
        external 
        payable 
        nonReentrant 
        whenNotPaused 
    {
        require(buildingToken.exists(tokenId), "Marketplace: asset does not exist");
        require(seller != address(0), "Marketplace: seller cannot be zero address");
        require(seller != msg.sender, "Marketplace: cannot buy from yourself");
        require(shareAmount > 0, "Marketplace: shareAmount must be greater than 0");
        require(msg.value > 0, "Marketplace: payment amount must be greater than 0");
        
        // Check seller has enough shares
        uint256 sellerBalance = buildingToken.balanceOf(seller, tokenId);
        require(sellerBalance >= shareAmount, "Marketplace: seller has insufficient shares");
        
        // Calculate platform fee
        uint256 platformFee = (msg.value * platformFeeBps) / 10000;
        uint256 sellerPayment = msg.value - platformFee;
        
        // Transfer shares from seller to buyer
        buildingToken.safeTransferFrom(seller, msg.sender, tokenId, shareAmount, "");
        
        // Transfer ETH to seller (minus fee)
        if (sellerPayment > 0) {
            (bool success, ) = payable(seller).call{value: sellerPayment}("");
            require(success, "Marketplace: ETH transfer to seller failed");
        }
        
        // Transfer platform fee to fee recipient
        if (platformFee > 0) {
            (bool success, ) = payable(feeRecipient).call{value: platformFee}("");
            require(success, "Marketplace: ETH transfer to fee recipient failed");
        }
        
        emit ShareTraded(
            tokenId,
            msg.sender,
            seller,
            shareAmount,
            msg.value,
            block.timestamp
        );
    }
    
    // Admin functions
    
    /**
     * @dev Set platform fee (in basis points, max 1000 = 10%)
     * @param newFeeBps New fee in basis points (e.g., 250 = 2.5%)
     */
    function setPlatformFee(uint256 newFeeBps) external onlyOwner {
        require(newFeeBps <= 1000, "Marketplace: fee cannot exceed 10%");
        platformFeeBps = newFeeBps;
        emit PlatformFeeUpdated(newFeeBps);
    }
    
    /**
     * @dev Update fee recipient address
     * @param _feeRecipient New fee recipient address
     */
    function setFeeRecipient(address _feeRecipient) external onlyOwner {
        require(_feeRecipient != address(0), "Marketplace: feeRecipient cannot be zero");
        address oldRecipient = feeRecipient;
        feeRecipient = _feeRecipient;
        emit FeeRecipientUpdated(oldRecipient, _feeRecipient);
    }
    
    /**
     * @dev Pause all marketplace operations (emergency function)
     */
    function pause() external onlyOwner {
        _pause();
    }
    
    /**
     * @dev Unpause marketplace operations
     */
    function unpause() external onlyOwner {
        _unpause();
    }
    
    /**
     * @dev Emergency withdraw function (only ETH)
     */
    function emergencyWithdraw() external onlyOwner {
        uint256 balance = address(this).balance;
        if (balance > 0) {
            (bool success, ) = payable(owner()).call{value: balance}("");
            require(success, "Marketplace: emergency withdraw failed");
        }
    }
}

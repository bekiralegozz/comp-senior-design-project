// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v4.9.3/contracts/access/Ownable.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v4.9.3/contracts/security/ReentrancyGuard.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v4.9.3/contracts/security/Pausable.sol";
import "./Building1122.sol";

/**
 * @title RentalManager
 * @dev Manages rental payments for real estate assets
 * 
 * Supports payments in ETH (native currency) only.
 * 
 * Rent payments are automatically distributed to fractional owners
 * based on their ownership percentage.
 * 
 * Example:
 * - tokenId = 1, totalSupply = 1000
 * - Owner A: 400 shares (40%), Owner B: 300 (30%), Owner C: 300 (30%)
 * - Rent payment: 1 ETH
 * - Distribution: A gets 0.4 ETH, B gets 0.3 ETH, C gets 0.3 ETH
 */
contract RentalManager is Ownable, ReentrancyGuard, Pausable {
    
    Building1122 public immutable buildingToken;
    
    // Mapping from assetId (tokenId) to total rent collected
    mapping(uint256 => uint256) public totalRentCollected;
    
    // Mapping from assetId to rent payment history (optional, for tracking)
    mapping(uint256 => RentPayment[]) public rentPayments;
    
    struct RentPayment {
        address payer;
        uint256 amount;
        uint256 timestamp;
    }
    
    // Events
    event RentPaid(
        uint256 indexed assetId,
        address indexed payer,
        uint256 amount,
        uint256 timestamp
    );
    
    event RentDistributed(
        uint256 indexed assetId,
        address indexed owner,
        uint256 amount,
        uint256 timestamp
    );
    
    /**
     * @dev Constructor
     * @param _buildingToken Address of the Building1122 contract
     */
    constructor(
        address _buildingToken
    ) Ownable() {
        require(_buildingToken != address(0), "RentalManager: buildingToken cannot be zero");
        
        buildingToken = Building1122(_buildingToken);
    }
    
    /**
     * @dev Pay rent for an asset using ETH and distribute to owners
     * @param assetId The tokenId of the asset in Building1122 contract
     * @param owners Array of owner addresses who should receive rent
     * 
     * Requirements:
     * - Asset must exist (tokenId must be initialized in Building1122)
     * - msg.value must be greater than 0
     * - Owners array must not be empty
     * 
     * Process:
     * 1. User sends ETH with transaction
     * 2. Contract calculates each owner's share based on their balance
     * 3. Distributes ETH to each owner proportionally
     * 4. Records the payment
     * 
     * Note: Backend/Blockchain Server should call this with the list of current owners
     * (can be obtained from Transfer events or database)
     */
    function payRent(
        uint256 assetId,
        address[] calldata owners
    ) 
        external 
        payable 
        nonReentrant 
        whenNotPaused 
    {
        require(buildingToken.exists(assetId), "RentalManager: asset does not exist");
        require(msg.value > 0, "RentalManager: payment amount must be greater than 0");
        require(owners.length > 0, "RentalManager: owners array cannot be empty");
        
        uint256 totalSupply = buildingToken.totalSupply(assetId);
        require(totalSupply > 0, "RentalManager: asset has no supply");
        
        uint256 totalDistributed = 0;
        uint256 rentAmount = msg.value;
        
        // Distribute rent to each owner based on their balance
        for (uint256 i = 0; i < owners.length; i++) {
            address owner = owners[i];
            if (owner == address(0)) continue; // Skip zero address
            
            uint256 ownerBalance = buildingToken.balanceOf(owner, assetId);
            if (ownerBalance == 0) continue; // Skip owners with no balance
            
            // Calculate owner's share: (ownerBalance / totalSupply) * rentAmount
            uint256 ownerShare = (rentAmount * ownerBalance) / totalSupply;
            
            if (ownerShare > 0) {
                // Transfer ETH to owner
                (bool success, ) = payable(owner).call{value: ownerShare}("");
                require(success, "RentalManager: ETH transfer to owner failed");
                
                totalDistributed += ownerShare;
                
                emit RentDistributed(assetId, owner, ownerShare, block.timestamp);
            }
        }
        
        // Safety check: ensure we didn't distribute more than received
        require(totalDistributed <= rentAmount, "RentalManager: distribution overflow");
        
        // If there's any remainder due to rounding, it stays in contract
        // (can be withdrawn by owner via emergencyWithdraw if needed)
        
        // Record the payment
        totalRentCollected[assetId] += rentAmount;
        rentPayments[assetId].push(RentPayment({
            payer: msg.sender,
            amount: rentAmount,
            timestamp: block.timestamp
        }));
        
        emit RentPaid(assetId, msg.sender, rentAmount, block.timestamp);
    }
    
    /**
     * @dev Get total rent collected for an asset
     * @param assetId The tokenId of the asset
     * @return Total rent collected (in wei)
     */
    function getTotalRentCollected(uint256 assetId) external view returns (uint256) {
        return totalRentCollected[assetId];
    }
    
    /**
     * @dev Get number of rent payments made for an asset
     * @param assetId The tokenId of the asset
     * @return Number of payments
     */
    function getRentPaymentCount(uint256 assetId) external view returns (uint256) {
        return rentPayments[assetId].length;
    }
    
    /**
     * @dev Get a specific rent payment by index
     * @param assetId The tokenId of the asset
     * @param index Index of the payment
     * @return RentPayment struct
     */
    function getRentPayment(uint256 assetId, uint256 index) 
        external 
        view 
        returns (RentPayment memory) 
    {
        require(index < rentPayments[assetId].length, "RentalManager: index out of bounds");
        return rentPayments[assetId][index];
    }
    
    /**
     * @dev Calculate how much rent an owner would receive for a given asset
     * @param assetId The tokenId of the asset
     * @param owner The owner address
     * @param rentAmount The total rent amount
     * @return The amount this owner would receive
     */
    function calculateOwnerShare(
        uint256 assetId,
        address owner,
        uint256 rentAmount
    ) external view returns (uint256) {
        uint256 totalSupply = buildingToken.totalSupply(assetId);
        if (totalSupply == 0) return 0;
        
        uint256 ownerBalance = buildingToken.balanceOf(owner, assetId);
        return (rentAmount * ownerBalance) / totalSupply;
    }
    
    // Admin functions
    
    /**
     * @dev Pause all rental payments (emergency function)
     */
    function pause() external onlyOwner {
        _pause();
    }
    
    /**
     * @dev Unpause rental payments
     */
    function unpause() external onlyOwner {
        _unpause();
    }
    
    /**
     * @dev Emergency withdraw function (only ETH)
     * Can be used to withdraw any remaining ETH due to rounding
     */
    function emergencyWithdraw() external onlyOwner {
        uint256 balance = address(this).balance;
        if (balance > 0) {
            (bool success, ) = payable(owner()).call{value: balance}("");
            require(success, "RentalManager: emergency withdraw failed");
        }
    }
}

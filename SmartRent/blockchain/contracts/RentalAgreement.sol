// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./AssetToken.sol";

/**
 * @title RentalAgreement
 * @dev Smart contract for managing rental agreements in SmartRent platform
 * Handles escrow, deposits, and automated rental lifecycle
 */
contract RentalAgreement is ReentrancyGuard, Pausable, Ownable {
    
    AssetToken public immutable assetToken;
    
    // Rental status enum
    enum RentalStatus { 
        Created,     // Rental created but not started
        Active,      // Rental is currently active
        Completed,   // Rental completed successfully
        Cancelled,   // Rental cancelled
        Disputed     // Rental is in dispute
    }

    struct Rental {
        uint256 assetTokenId;        // Asset NFT token ID
        address renter;              // Address of the renter
        address assetOwner;          // Address of the asset owner
        uint256 startTime;           // Rental start timestamp
        uint256 endTime;             // Rental end timestamp
        uint256 pricePerDay;         // Daily rental price in wei
        uint256 totalPrice;          // Total rental price
        uint256 securityDeposit;     // Security deposit amount
        RentalStatus status;         // Current rental status
        bool depositReturned;        // Whether deposit has been returned
        uint256 createdAt;           // Contract creation timestamp
    }

    // Storage
    mapping(uint256 => Rental) public rentals;
    mapping(address => uint256[]) public renterRentals;
    mapping(address => uint256[]) public ownerRentals;
    mapping(uint256 => uint256[]) public assetRentals; // Asset to rental IDs
    
    uint256 private _rentalIdCounter;
    uint256 public platformFeePercentage = 250; // 2.5% (250 basis points)
    address public feeRecipient;
    
    // Events
    event RentalCreated(
        uint256 indexed rentalId,
        uint256 indexed assetTokenId,
        address indexed renter,
        address assetOwner,
        uint256 startTime,
        uint256 endTime,
        uint256 totalPrice
    );
    
    event RentalStarted(uint256 indexed rentalId, uint256 startTime);
    event RentalCompleted(uint256 indexed rentalId, uint256 completionTime);
    event RentalCancelled(uint256 indexed rentalId, address cancelledBy);
    event DepositReturned(uint256 indexed rentalId, address renter, uint256 amount);
    event DisputeRaised(uint256 indexed rentalId, address raisedBy);
    event PlatformFeeUpdated(uint256 newFeePercentage);

    constructor(address _assetTokenAddress) {
        assetToken = AssetToken(_assetTokenAddress);
        feeRecipient = msg.sender;
    }

    modifier validRental(uint256 rentalId) {
        require(rentalId < _rentalIdCounter, "Invalid rental ID");
        _;
    }

    modifier onlyRenter(uint256 rentalId) {
        require(rentals[rentalId].renter == msg.sender, "Only renter can call this");
        _;
    }

    modifier onlyAssetOwner(uint256 rentalId) {
        require(rentals[rentalId].assetOwner == msg.sender, "Only asset owner can call this");
        _;
    }

    modifier onlyRenterOrOwner(uint256 rentalId) {
        require(
            rentals[rentalId].renter == msg.sender || 
            rentals[rentalId].assetOwner == msg.sender,
            "Only renter or asset owner can call this"
        );
        _;
    }

    /**
     * @dev Create a new rental agreement
     * @param assetTokenId The NFT token ID of the asset
     * @param startTime Rental start timestamp
     * @param endTime Rental end timestamp
     * @param securityDeposit Security deposit amount in wei
     */
    function createRental(
        uint256 assetTokenId,
        uint256 startTime,
        uint256 endTime,
        uint256 securityDeposit
    ) external payable nonReentrant whenNotPaused returns (uint256) {
        // Validate inputs
        require(assetToken.exists(assetTokenId), "Asset does not exist");
        require(startTime > block.timestamp, "Start time must be in the future");
        require(endTime > startTime, "End time must be after start time");
        require(assetToken.isAvailableForRental(assetTokenId), "Asset not available for rental");
        
        address assetOwner = assetToken.ownerOf(assetTokenId);
        require(assetOwner != msg.sender, "Cannot rent your own asset");
        
        // Calculate rental details
        AssetToken.AssetInfo memory asset = assetToken.getAsset(assetTokenId);
        uint256 durationDays = ((endTime - startTime) / 1 days) + 1; // Include partial days
        uint256 totalPrice = asset.pricePerDay * durationDays;
        
        // Validate payment
        require(msg.value >= totalPrice + securityDeposit, "Insufficient payment");
        
        // Create rental
        uint256 rentalId = _rentalIdCounter++;
        
        rentals[rentalId] = Rental({
            assetTokenId: assetTokenId,
            renter: msg.sender,
            assetOwner: assetOwner,
            startTime: startTime,
            endTime: endTime,
            pricePerDay: asset.pricePerDay,
            totalPrice: totalPrice,
            securityDeposit: securityDeposit,
            status: RentalStatus.Created,
            depositReturned: false,
            createdAt: block.timestamp
        });
        
        // Update mappings
        renterRentals[msg.sender].push(rentalId);
        ownerRentals[assetOwner].push(rentalId);
        assetRentals[assetTokenId].push(rentalId);
        
        // Mark asset as unavailable during rental period
        assetToken.setRentalAvailability(assetTokenId, false);
        
        emit RentalCreated(
            rentalId,
            assetTokenId,
            msg.sender,
            assetOwner,
            startTime,
            endTime,
            totalPrice
        );
        
        return rentalId;
    }

    /**
     * @dev Start an active rental (can be called by renter when start time is reached)
     */
    function startRental(uint256 rentalId) 
        external 
        validRental(rentalId) 
        onlyRenter(rentalId) 
        nonReentrant 
    {
        Rental storage rental = rentals[rentalId];
        require(rental.status == RentalStatus.Created, "Rental not in created state");
        require(block.timestamp >= rental.startTime, "Rental start time not reached");
        require(block.timestamp <= rental.endTime, "Rental period has expired");
        
        rental.status = RentalStatus.Active;
        
        emit RentalStarted(rentalId, block.timestamp);
    }

    /**
     * @dev Complete a rental (can be called by renter or owner)
     */
    function completeRental(uint256 rentalId) 
        external 
        validRental(rentalId) 
        onlyRenterOrOwner(rentalId) 
        nonReentrant 
    {
        Rental storage rental = rentals[rentalId];
        require(
            rental.status == RentalStatus.Active || 
            rental.status == RentalStatus.Created, 
            "Invalid rental status"
        );
        
        rental.status = RentalStatus.Completed;
        
        // Calculate platform fee
        uint256 platformFee = (rental.totalPrice * platformFeePercentage) / 10000;
        uint256 ownerAmount = rental.totalPrice - platformFee;
        
        // Transfer payments
        payable(rental.assetOwner).transfer(ownerAmount);
        if (platformFee > 0) {
            payable(feeRecipient).transfer(platformFee);
        }
        
        // Return security deposit to renter
        if (rental.securityDeposit > 0 && !rental.depositReturned) {
            rental.depositReturned = true;
            payable(rental.renter).transfer(rental.securityDeposit);
            emit DepositReturned(rentalId, rental.renter, rental.securityDeposit);
        }
        
        // Make asset available again
        assetToken.setRentalAvailability(rental.assetTokenId, true);
        
        emit RentalCompleted(rentalId, block.timestamp);
    }

    /**
     * @dev Cancel a rental before it starts (only if not yet active)
     */
    function cancelRental(uint256 rentalId) 
        external 
        validRental(rentalId) 
        onlyRenterOrOwner(rentalId) 
        nonReentrant 
    {
        Rental storage rental = rentals[rentalId];
        require(rental.status == RentalStatus.Created, "Can only cancel created rentals");
        
        rental.status = RentalStatus.Cancelled;
        
        // Refund full amount to renter
        uint256 refundAmount = rental.totalPrice + rental.securityDeposit;
        payable(rental.renter).transfer(refundAmount);
        
        // Make asset available again
        assetToken.setRentalAvailability(rental.assetTokenId, true);
        
        emit RentalCancelled(rentalId, msg.sender);
    }

    /**
     * @dev Raise a dispute (can be called by renter or owner)
     */
    function raiseDispute(uint256 rentalId) 
        external 
        validRental(rentalId) 
        onlyRenterOrOwner(rentalId) 
    {
        Rental storage rental = rentals[rentalId];
        require(
            rental.status == RentalStatus.Active || 
            rental.status == RentalStatus.Completed, 
            "Cannot dispute this rental"
        );
        
        rental.status = RentalStatus.Disputed;
        
        emit DisputeRaised(rentalId, msg.sender);
    }

    /**
     * @dev Resolve dispute (only owner/admin)
     */
    function resolveDispute(
        uint256 rentalId, 
        uint256 renterRefund, 
        uint256 ownerPayment
    ) 
        external 
        validRental(rentalId) 
        onlyOwner 
        nonReentrant 
    {
        Rental storage rental = rentals[rentalId];
        require(rental.status == RentalStatus.Disputed, "Rental not in dispute");
        
        require(
            renterRefund + ownerPayment <= rental.totalPrice + rental.securityDeposit,
            "Invalid refund/payment amounts"
        );
        
        rental.status = RentalStatus.Completed;
        
        // Transfer resolved amounts
        if (renterRefund > 0) {
            payable(rental.renter).transfer(renterRefund);
        }
        if (ownerPayment > 0) {
            payable(rental.assetOwner).transfer(ownerPayment);
        }
        
        // Mark deposit as returned
        rental.depositReturned = true;
        
        // Make asset available again
        assetToken.setRentalAvailability(rental.assetTokenId, true);
    }

    // View functions
    function getRental(uint256 rentalId) external view validRental(rentalId) returns (Rental memory) {
        return rentals[rentalId];
    }

    function getRenterRentals(address renter) external view returns (uint256[] memory) {
        return renterRentals[renter];
    }

    function getOwnerRentals(address owner) external view returns (uint256[] memory) {
        return ownerRentals[owner];
    }

    function getAssetRentals(uint256 assetTokenId) external view returns (uint256[] memory) {
        return assetRentals[assetTokenId];
    }

    function getTotalRentals() external view returns (uint256) {
        return _rentalIdCounter;
    }

    // Admin functions
    function setPlatformFee(uint256 newFeePercentage) external onlyOwner {
        require(newFeePercentage <= 1000, "Fee cannot exceed 10%"); // Max 10%
        platformFeePercentage = newFeePercentage;
        emit PlatformFeeUpdated(newFeePercentage);
    }

    function setFeeRecipient(address newFeeRecipient) external onlyOwner {
        require(newFeeRecipient != address(0), "Invalid fee recipient");
        feeRecipient = newFeeRecipient;
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    // Emergency functions
    function emergencyWithdraw() external onlyOwner {
        payable(owner()).transfer(address(this).balance);
    }
}










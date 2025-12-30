// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "./interfaces/ISmartRentHub.sol";

/**
 * @title RentalHub
 * @dev Central registry and management system for rental listings and bookings
 * 
 * This contract serves as:
 * 1. Rental Listing Registry - NFT holders can list their properties for rent
 * 2. Booking Management - Users can rent properties for specific date ranges
 * 3. Date Conflict Prevention - Prevents double-booking
 * 
 * Key Rules:
 * - Only the MAJORITY SHAREHOLDER (owner with most shares) can create rental listings
 * - Each listing tracks booked dates to prevent conflicts
 * - Renters pay upfront for their entire stay
 * - Platform takes a small fee, rest goes to majority shareholder
 * 
 * Architecture:
 * - Building1122 holds the NFT ownership data
 * - RentalHub manages rental listings and bookings
 * - Integration with SmartRentHub for asset registry
 */
contract RentalHub is Ownable, ReentrancyGuard, Pausable {
    
    // ============================================
    // STRUCTS
    // ============================================
    
    /**
     * @dev Rental Listing - Posted by majority shareholder
     */
    struct RentalListing {
        uint256 listingId;
        uint256 tokenId;              // Asset token ID from Building1122
        address owner;                // Majority shareholder (lister)
        uint256 pricePerNight;        // Price per night in wei (POL)
        uint256 createdAt;
        bool isActive;
    }
    
    /**
     * @dev Rental Booking - Made by renters
     */
    struct Rental {
        uint256 rentalId;
        uint256 listingId;
        uint256 tokenId;
        address renter;               // Person renting the property
        uint256 checkInDate;          // Unix timestamp (start of day)
        uint256 checkOutDate;         // Unix timestamp (start of day)
        uint256 totalPrice;           // Total payment made
        uint256 createdAt;
        RentalStatus status;
    }
    
    /**
     * @dev Rental status enum
     */
    enum RentalStatus {
        Active,      // Currently booked
        Completed,   // Check-out date passed
        Cancelled    // Cancelled by renter or owner
    }
    
    /**
     * @dev Combined rental listing with asset details (for view functions)
     */
    struct RentalListingWithDetails {
        uint256 listingId;
        uint256 tokenId;
        address owner;
        uint256 pricePerNight;
        uint256 createdAt;
        string metadataURI;
        uint256 totalShares;
        uint256 ownerShares;
    }
    
    // ============================================
    // STATE VARIABLES
    // ============================================
    
    // Building1122 token contract address
    address public buildingToken;
    
    // SmartRentHub contract (for asset info and ownership queries)
    ISmartRentHub public smartRentHub;
    
    // Mapping from listingId to RentalListing
    mapping(uint256 => RentalListing) public rentalListings;
    
    // Next listing ID counter
    uint256 public nextListingId = 1;
    
    // Array of active rental listing IDs (for enumeration)
    uint256[] private _activeRentalListingIds;
    
    // Mapping to track index in _activeRentalListingIds
    mapping(uint256 => uint256) private _activeRentalListingIndex;
    
    // Mapping from listingId to booked dates (timestamp => isBooked)
    // Date is normalized to start of day (00:00:00 UTC)
    mapping(uint256 => mapping(uint256 => bool)) private _bookedDates;
    
    // Mapping from listingId to array of date timestamps that are booked
    mapping(uint256 => uint256[]) private _bookedDatesList;
    
    // Mapping from rentalId to Rental
    mapping(uint256 => Rental) public rentals;
    
    // Next rental ID counter
    uint256 public nextRentalId = 1;
    
    // Mapping from renter address to array of rental IDs
    mapping(address => uint256[]) private _renterToRentals;
    
    // Mapping from tokenId to array of rental IDs
    mapping(uint256 => uint256[]) private _assetToRentals;
    
    // Platform fee in basis points (e.g., 250 = 2.5%)
    uint256 public platformFeeBps = 250;
    
    // Platform fee recipient
    address public feeRecipient;
    
    // ============================================
    // EVENTS
    // ============================================
    
    event RentalListingCreated(
        uint256 indexed listingId,
        uint256 indexed tokenId,
        address indexed owner,
        uint256 pricePerNight
    );
    
    event RentalListingCancelled(
        uint256 indexed listingId,
        address indexed owner
    );
    
    event RentalBooked(
        uint256 indexed rentalId,
        uint256 indexed listingId,
        uint256 indexed tokenId,
        address renter,
        uint256 checkInDate,
        uint256 checkOutDate,
        uint256 totalPrice
    );
    
    event RentalCancelled(
        uint256 indexed rentalId,
        address indexed cancelledBy
    );
    
    event PlatformFeeUpdated(uint256 newFeeBps);
    event FeeRecipientUpdated(address indexed newRecipient);
    event BuildingTokenUpdated(address indexed newToken);
    event SmartRentHubUpdated(address indexed newHub);
    
    // ============================================
    // CONSTRUCTOR
    // ============================================
    
    /**
     * @dev Constructor
     * @param initialOwner Owner of the contract
     * @param _feeRecipient Address that receives platform fees
     */
    constructor(address initialOwner, address _feeRecipient) Ownable(initialOwner) {
        require(_feeRecipient != address(0), "RentalHub: feeRecipient cannot be zero");
        feeRecipient = _feeRecipient;
    }
    
    // ============================================
    // ADMIN FUNCTIONS
    // ============================================
    
    /**
     * @dev Set Building1122 token contract address
     */
    function setBuildingToken(address _buildingToken) external onlyOwner {
        require(_buildingToken != address(0), "RentalHub: invalid token address");
        buildingToken = _buildingToken;
        emit BuildingTokenUpdated(_buildingToken);
    }
    
    /**
     * @dev Set SmartRentHub contract address
     */
    function setSmartRentHub(address _smartRentHub) external onlyOwner {
        require(_smartRentHub != address(0), "RentalHub: invalid hub address");
        smartRentHub = ISmartRentHub(_smartRentHub);
        emit SmartRentHubUpdated(_smartRentHub);
    }
    
    /**
     * @dev Set platform fee (max 10%)
     */
    function setPlatformFee(uint256 newFeeBps) external onlyOwner {
        require(newFeeBps <= 1000, "RentalHub: fee cannot exceed 10%");
        platformFeeBps = newFeeBps;
        emit PlatformFeeUpdated(newFeeBps);
    }
    
    /**
     * @dev Set fee recipient address
     */
    function setFeeRecipient(address _feeRecipient) external onlyOwner {
        require(_feeRecipient != address(0), "RentalHub: invalid recipient");
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
    // RENTAL LISTING FUNCTIONS
    // ============================================
    
    /**
     * @dev Create a rental listing (only majority shareholder can call)
     * @param tokenId The token ID of the asset to list
     * @param pricePerNight Price per night in wei (POL)
     */
    function createRentalListing(
        uint256 tokenId,
        uint256 pricePerNight
    ) external whenNotPaused nonReentrant returns (uint256 listingId) {
        require(pricePerNight > 0, "RentalHub: pricePerNight must be > 0");
        
        // Check if caller is the majority shareholder
        require(
            isMajorityShareholder(msg.sender, tokenId),
            "RentalHub: only majority shareholder can create rental listing"
        );
        
        // Create rental listing
        listingId = nextListingId++;
        rentalListings[listingId] = RentalListing({
            listingId: listingId,
            tokenId: tokenId,
            owner: msg.sender,
            pricePerNight: pricePerNight,
            createdAt: block.timestamp,
            isActive: true
        });
        
        // Add to active rental listings
        _activeRentalListingIndex[listingId] = _activeRentalListingIds.length;
        _activeRentalListingIds.push(listingId);
        
        emit RentalListingCreated(listingId, tokenId, msg.sender, pricePerNight);
        
        return listingId;
    }
    
    /**
     * @dev Cancel a rental listing
     * @param listingId The listing ID to cancel
     */
    function cancelRentalListing(uint256 listingId) external whenNotPaused nonReentrant {
        RentalListing storage listing = rentalListings[listingId];
        require(listing.isActive, "RentalHub: listing not active");
        require(listing.owner == msg.sender, "RentalHub: not the owner");
        
        // Deactivate listing
        listing.isActive = false;
        
        // Remove from active listings array
        _removeFromActiveRentalListings(listingId);
        
        emit RentalListingCancelled(listingId, msg.sender);
    }
    
    // ============================================
    // RENTAL BOOKING FUNCTIONS
    // ============================================
    
    /**
     * @dev Book a rental for specific dates
     * @param listingId The listing ID to rent
     * @param checkInDate Check-in date (Unix timestamp, start of day)
     * @param checkOutDate Check-out date (Unix timestamp, start of day)
     */
    function rentAsset(
        uint256 listingId,
        uint256 checkInDate,
        uint256 checkOutDate
    ) external payable whenNotPaused nonReentrant returns (uint256 rentalId) {
        RentalListing storage listing = rentalListings[listingId];
        require(listing.isActive, "RentalHub: listing not active");
        require(checkInDate < checkOutDate, "RentalHub: invalid dates");
        require(checkInDate >= block.timestamp, "RentalHub: cannot book past dates");
        require(msg.sender != listing.owner, "RentalHub: owner cannot rent own property");
        
        // Normalize dates to start of day
        uint256 normalizedCheckIn = _normalizeDate(checkInDate);
        uint256 normalizedCheckOut = _normalizeDate(checkOutDate);
        
        // Check for date conflicts
        require(
            !_hasDateConflict(listingId, normalizedCheckIn, normalizedCheckOut),
            "RentalHub: dates already booked"
        );
        
        // Calculate number of nights
        uint256 nights = (normalizedCheckOut - normalizedCheckIn) / 1 days;
        require(nights > 0, "RentalHub: must book at least 1 night");
        
        // Calculate total price
        uint256 totalPrice = nights * listing.pricePerNight;
        require(msg.value >= totalPrice, "RentalHub: insufficient payment");
        
        // Calculate platform fee
        uint256 platformFee = (totalPrice * platformFeeBps) / 10000;
        uint256 ownerPayment = totalPrice - platformFee;
        
        // Mark dates as booked
        _bookDates(listingId, normalizedCheckIn, normalizedCheckOut);
        
        // Create rental record
        rentalId = nextRentalId++;
        rentals[rentalId] = Rental({
            rentalId: rentalId,
            listingId: listingId,
            tokenId: listing.tokenId,
            renter: msg.sender,
            checkInDate: normalizedCheckIn,
            checkOutDate: normalizedCheckOut,
            totalPrice: totalPrice,
            createdAt: block.timestamp,
            status: RentalStatus.Active
        });
        
        // Track rental for renter and asset
        _renterToRentals[msg.sender].push(rentalId);
        _assetToRentals[listing.tokenId].push(rentalId);
        
        // Transfer payment to owner
        if (ownerPayment > 0) {
            (bool ownerSuccess, ) = payable(listing.owner).call{value: ownerPayment}("");
            require(ownerSuccess, "RentalHub: owner payment failed");
        }
        
        // Transfer platform fee
        if (platformFee > 0) {
            (bool feeSuccess, ) = payable(feeRecipient).call{value: platformFee}("");
            require(feeSuccess, "RentalHub: fee payment failed");
        }
        
        // Refund excess payment
        if (msg.value > totalPrice) {
            (bool refundSuccess, ) = payable(msg.sender).call{value: msg.value - totalPrice}("");
            require(refundSuccess, "RentalHub: refund failed");
        }
        
        emit RentalBooked(
            rentalId,
            listingId,
            listing.tokenId,
            msg.sender,
            normalizedCheckIn,
            normalizedCheckOut,
            totalPrice
        );
        
        return rentalId;
    }
    
    /**
     * @dev Cancel a rental (before check-in date)
     * @param rentalId The rental ID to cancel
     */
    function cancelRental(uint256 rentalId) external whenNotPaused nonReentrant {
        Rental storage rental = rentals[rentalId];
        require(rental.status == RentalStatus.Active, "RentalHub: rental not active");
        require(
            msg.sender == rental.renter || msg.sender == rentalListings[rental.listingId].owner,
            "RentalHub: not authorized"
        );
        require(block.timestamp < rental.checkInDate, "RentalHub: cannot cancel after check-in");
        
        // Update status
        rental.status = RentalStatus.Cancelled;
        
        // Free up the dates
        _unbookDates(rental.listingId, rental.checkInDate, rental.checkOutDate);
        
        emit RentalCancelled(rentalId, msg.sender);
        
        // Refund logic can be added here (e.g., partial refund based on cancellation policy)
        // For now, no refund
    }
    
    // ============================================
    // VIEW FUNCTIONS - RENTAL LISTINGS
    // ============================================
    
    /**
     * @dev Get total number of active rental listings
     */
    function getActiveRentalListingsCount() external view returns (uint256) {
        return _activeRentalListingIds.length;
    }
    
    /**
     * @dev Get all active rental listings
     */
    function getActiveRentalListings() external view returns (RentalListing[] memory) {
        uint256 count = _activeRentalListingIds.length;
        RentalListing[] memory result = new RentalListing[](count);
        
        for (uint256 i = 0; i < count; i++) {
            result[i] = rentalListings[_activeRentalListingIds[i]];
        }
        
        return result;
    }
    
    /**
     * @dev Get rental listing by ID
     */
    function getRentalListing(uint256 listingId) external view returns (RentalListing memory) {
        require(rentalListings[listingId].listingId != 0, "RentalHub: listing does not exist");
        return rentalListings[listingId];
    }
    
    /**
     * @dev Get all active rental listings for a specific asset
     */
    function getRentalListingsByAsset(uint256 tokenId) external view returns (RentalListing[] memory) {
        uint256 count = 0;
        
        // Count matching listings
        for (uint256 i = 0; i < _activeRentalListingIds.length; i++) {
            if (rentalListings[_activeRentalListingIds[i]].tokenId == tokenId) {
                count++;
            }
        }
        
        // Populate result array
        RentalListing[] memory result = new RentalListing[](count);
        uint256 index = 0;
        for (uint256 i = 0; i < _activeRentalListingIds.length; i++) {
            if (rentalListings[_activeRentalListingIds[i]].tokenId == tokenId) {
                result[index] = rentalListings[_activeRentalListingIds[i]];
                index++;
            }
        }
        
        return result;
    }
    
    /**
     * @dev Check if dates are available for a listing
     */
    function areDatesAvailable(
        uint256 listingId,
        uint256 checkInDate,
        uint256 checkOutDate
    ) external view returns (bool) {
        uint256 normalizedCheckIn = _normalizeDate(checkInDate);
        uint256 normalizedCheckOut = _normalizeDate(checkOutDate);
        return !_hasDateConflict(listingId, normalizedCheckIn, normalizedCheckOut);
    }
    
    /**
     * @dev Get booked dates for a listing
     */
    function getBookedDates(uint256 listingId) external view returns (uint256[] memory) {
        return _bookedDatesList[listingId];
    }
    
    // ============================================
    // VIEW FUNCTIONS - RENTALS
    // ============================================
    
    /**
     * @dev Get rental by ID
     */
    function getRental(uint256 rentalId) external view returns (Rental memory) {
        require(rentals[rentalId].rentalId != 0, "RentalHub: rental does not exist");
        return rentals[rentalId];
    }
    
    /**
     * @dev Get all rentals by renter
     */
    function getRentalsByRenter(address renter) external view returns (uint256[] memory) {
        return _renterToRentals[renter];
    }
    
    /**
     * @dev Get all rentals for an asset
     */
    function getRentalsByAsset(uint256 tokenId) external view returns (uint256[] memory) {
        return _assetToRentals[tokenId];
    }
    
    // ============================================
    // HELPER FUNCTIONS
    // ============================================
    
    /**
     * @dev Check if an address is the majority shareholder (top shareholder) for an asset
     * Majority shareholder = address with the highest balance, not necessarily >50%
     * Example: 40-30-30 distribution -> 40% holder is the majority shareholder
     */
    function isMajorityShareholder(address account, uint256 tokenId) public view returns (bool) {
        require(address(smartRentHub) != address(0), "RentalHub: smart rent hub not set");
        
        // Delegate to SmartRentHub which tracks all owners and can determine top shareholder
        return smartRentHub.isMajorityShareholder(account, tokenId);
    }
    
    /**
     * @dev Get majority shareholder (top shareholder) for an asset
     * Note: This is gas-intensive and should primarily be called off-chain
     */
    function getMajorityShareholder(uint256 tokenId) external view returns (address topHolder, uint256 topBalance) {
        require(address(smartRentHub) != address(0), "RentalHub: smart rent hub not set");
        
        // Delegate to SmartRentHub which efficiently tracks all owners
        return smartRentHub.getTopShareholder(tokenId);
    }
    
    /**
     * @dev Normalize date to start of day (00:00:00 UTC)
     */
    function _normalizeDate(uint256 timestamp) internal pure returns (uint256) {
        return (timestamp / 1 days) * 1 days;
    }
    
    /**
     * @dev Check if there's a date conflict
     */
    function _hasDateConflict(
        uint256 listingId,
        uint256 checkInDate,
        uint256 checkOutDate
    ) internal view returns (bool) {
        for (uint256 date = checkInDate; date < checkOutDate; date += 1 days) {
            if (_bookedDates[listingId][date]) {
                return true;
            }
        }
        return false;
    }
    
    /**
     * @dev Mark dates as booked
     */
    function _bookDates(
        uint256 listingId,
        uint256 checkInDate,
        uint256 checkOutDate
    ) internal {
        for (uint256 date = checkInDate; date < checkOutDate; date += 1 days) {
            if (!_bookedDates[listingId][date]) {
                _bookedDates[listingId][date] = true;
                _bookedDatesList[listingId].push(date);
            }
        }
    }
    
    /**
     * @dev Unbook dates (for cancellations)
     */
    function _unbookDates(
        uint256 listingId,
        uint256 checkInDate,
        uint256 checkOutDate
    ) internal {
        for (uint256 date = checkInDate; date < checkOutDate; date += 1 days) {
            _bookedDates[listingId][date] = false;
        }
        
        // Rebuild bookedDatesList (gas-intensive, but cancellations should be rare)
        delete _bookedDatesList[listingId];
        // Note: In production, consider optimizing this
    }
    
    /**
     * @dev Remove listing from active rental listings array
     */
    function _removeFromActiveRentalListings(uint256 listingId) internal {
        uint256 index = _activeRentalListingIndex[listingId];
        uint256 lastIndex = _activeRentalListingIds.length - 1;
        
        if (index != lastIndex) {
            uint256 lastListingId = _activeRentalListingIds[lastIndex];
            _activeRentalListingIds[index] = lastListingId;
            _activeRentalListingIndex[lastListingId] = index;
        }
        
        _activeRentalListingIds.pop();
        delete _activeRentalListingIndex[listingId];
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
            require(success, "RentalHub: withdraw failed");
        }
    }
}


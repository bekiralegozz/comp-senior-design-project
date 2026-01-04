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
    // IOT DEVICE REGISTRY
    // ============================================
    
    // Mapping from tokenId (asset) to deviceId (ESP32)
    mapping(uint256 => string) public assetToDevice;
    
    // Mapping from deviceId to tokenId
    mapping(string => uint256) public deviceToAsset;
    
    // Mapping to check if device is registered to any asset
    mapping(string => bool) public deviceRegistered;
    
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
    
    event RentalListingDeactivatedDueToOwnershipChange(
        uint256 indexed listingId,
        uint256 indexed tokenId,
        address indexed previousOwner,
        address newTopShareholder
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
    
    // Device Registry Events
    event DeviceRegistered(
        uint256 indexed tokenId,
        string deviceId,
        address indexed registeredBy
    );
    
    event DeviceUnregistered(
        uint256 indexed tokenId,
        string deviceId,
        address indexed unregisteredBy
    );
    
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
    
    /**
     * @dev Called by SmartRentHub when top shareholder changes for a token
     * Automatically deactivates rental listings if the owner is no longer the top shareholder
     * @param tokenId The token ID whose top shareholder has changed
     * @param previousTopShareholder The address of the previous top shareholder
     * @param newTopShareholder The address of the new top shareholder
     */
    function onTopShareholderChanged(
        uint256 tokenId,
        address previousTopShareholder,
        address newTopShareholder
    ) external {
        // Only SmartRentHub can call this
        require(msg.sender == address(smartRentHub), "RentalHub: only SmartRentHub can call");
        require(previousTopShareholder != newTopShareholder, "RentalHub: shareholders are the same");
        
        // Find and deactivate all active listings by previousTopShareholder for this tokenId
        uint256 deactivatedCount = 0;
        for (uint256 i = 0; i < _activeRentalListingIds.length; i++) {
            uint256 listingId = _activeRentalListingIds[i];
            RentalListing storage listing = rentalListings[listingId];
            
            // Check if this listing matches: same tokenId, same owner, and is active
            if (listing.tokenId == tokenId && 
                listing.owner == previousTopShareholder && 
                listing.isActive) {
                
                // Deactivate the listing
                listing.isActive = false;
                
                // Remove from active listings array
                _removeFromActiveRentalListings(listingId);
                
                emit RentalListingDeactivatedDueToOwnershipChange(
                    listingId,
                    tokenId,
                    previousTopShareholder,
                    newTopShareholder
                );
                
                deactivatedCount++;
                
                // Decrement i because we removed an element
                if (i > 0) i--;
            }
        }
        
        // Note: We don't revert if no listings found, as this is a valid scenario
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
        
        // Distribute payment to all shareholders proportionally
        if (ownerPayment > 0) {
            _distributeRentalPayment(listing.tokenId, ownerPayment);
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
     * @dev Distribute rental payment to all shareholders proportionally
     * @param tokenId The token ID (property) to distribute payment for
     * @param totalPayment Total payment to distribute
     */
    function _distributeRentalPayment(uint256 tokenId, uint256 totalPayment) private {
        // Get all shareholders from SmartRentHub
        address[] memory shareholders = ISmartRentHub(smartRentHub).getAssetOwners(tokenId);
        require(shareholders.length > 0, "RentalHub: no shareholders found");
        
        // Get total shares for this token from SmartRentHub
        ISmartRentHub.AssetInfo memory asset = ISmartRentHub(smartRentHub).getAsset(tokenId);
        uint256 totalShares = asset.totalShares;
        require(totalShares > 0, "RentalHub: no shares exist");
        
        // Distribute payment proportionally to each shareholder
        uint256 distributedAmount = 0;
        for (uint256 i = 0; i < shareholders.length; i++) {
            address shareholder = shareholders[i];
            uint256 shareholderBalance = IERC1155(buildingToken).balanceOf(shareholder, tokenId);
            
            if (shareholderBalance > 0) {
                // Calculate proportional payment
                uint256 payment = (totalPayment * shareholderBalance) / totalShares;
                
                if (payment > 0) {
                    distributedAmount += payment;
                    (bool success, ) = payable(shareholder).call{value: payment}("");
                    require(success, "RentalHub: shareholder payment failed");
                }
            }
        }
        
        // Handle any remaining dust (rounding errors)
        if (totalPayment > distributedAmount) {
            uint256 dust = totalPayment - distributedAmount;
            // Send dust to first shareholder or fee recipient
            if (dust > 0 && shareholders.length > 0) {
                (bool dustSuccess, ) = payable(shareholders[0]).call{value: dust}("");
                require(dustSuccess, "RentalHub: dust payment failed");
            }
        }
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
    // IOT DEVICE REGISTRY FUNCTIONS
    // ============================================
    
    /**
     * @dev Register an IoT device (ESP32) to an asset
     * Only the majority shareholder of the asset can register a device
     * @param tokenId The asset token ID
     * @param deviceId The unique device identifier (e.g., "ESP32-ROOM-101")
     */
    function registerDevice(
        uint256 tokenId,
        string calldata deviceId
    ) external whenNotPaused {
        require(bytes(deviceId).length > 0, "RentalHub: deviceId cannot be empty");
        require(bytes(deviceId).length <= 64, "RentalHub: deviceId too long");
        require(!deviceRegistered[deviceId], "RentalHub: device already registered");
        require(bytes(assetToDevice[tokenId]).length == 0, "RentalHub: asset already has device");
        
        // Only majority shareholder can register device
        require(
            isMajorityShareholder(msg.sender, tokenId),
            "RentalHub: only majority shareholder can register device"
        );
        
        // Register device
        assetToDevice[tokenId] = deviceId;
        deviceToAsset[deviceId] = tokenId;
        deviceRegistered[deviceId] = true;
        
        emit DeviceRegistered(tokenId, deviceId, msg.sender);
    }
    
    /**
     * @dev Unregister an IoT device from an asset
     * Only the majority shareholder or contract owner can unregister
     * @param tokenId The asset token ID
     */
    function unregisterDevice(uint256 tokenId) external whenNotPaused {
        string memory deviceId = assetToDevice[tokenId];
        require(bytes(deviceId).length > 0, "RentalHub: no device registered");
        
        // Only majority shareholder or owner can unregister
        require(
            isMajorityShareholder(msg.sender, tokenId) || msg.sender == owner(),
            "RentalHub: not authorized to unregister"
        );
        
        // Clear mappings
        delete deviceToAsset[deviceId];
        delete deviceRegistered[deviceId];
        delete assetToDevice[tokenId];
        
        emit DeviceUnregistered(tokenId, deviceId, msg.sender);
    }
    
    /**
     * @dev Check if a user is authorized to unlock a device
     * User must have an active rental for the asset that:
     * 1. Is in Active status
     * 2. Current time is within check-in and check-out dates
     * @param deviceId The device identifier
     * @param user The user's wallet address
     * @return authorized True if user can unlock
     * @return rentalId The rental ID that authorizes access (0 if not authorized)
     */
    function isAuthorizedToUnlock(
        string calldata deviceId,
        address user
    ) external view returns (bool authorized, uint256 rentalId) {
        // Check device is registered
        if (!deviceRegistered[deviceId]) {
            return (false, 0);
        }
        
        // Get the asset for this device
        uint256 tokenId = deviceToAsset[deviceId];
        
        // Get all rentals for this asset
        uint256[] memory rentalIds = _assetToRentals[tokenId];
        
        // Current timestamp
        uint256 currentTime = block.timestamp;
        
        // Check each rental
        for (uint256 i = 0; i < rentalIds.length; i++) {
            Rental storage rental = rentals[rentalIds[i]];
            
            // Check if this rental belongs to the user and is active
            if (rental.renter == user && 
                rental.status == RentalStatus.Active &&
                currentTime >= rental.checkInDate &&
                currentTime < rental.checkOutDate) {
                return (true, rental.rentalId);
            }
        }
        
        return (false, 0);
    }
    
    /**
     * @dev Get device ID for an asset
     * @param tokenId The asset token ID
     * @return deviceId The registered device ID (empty string if none)
     */
    function getDeviceByAsset(uint256 tokenId) external view returns (string memory) {
        return assetToDevice[tokenId];
    }
    
    /**
     * @dev Get asset token ID for a device
     * @param deviceId The device identifier
     * @return tokenId The asset token ID (0 if not registered)
     */
    function getAssetByDevice(string calldata deviceId) external view returns (uint256) {
        return deviceToAsset[deviceId];
    }
    
    /**
     * @dev Check if a device is registered
     * @param deviceId The device identifier
     * @return True if device is registered to an asset
     */
    function isDeviceRegistered(string calldata deviceId) external view returns (bool) {
        return deviceRegistered[deviceId];
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


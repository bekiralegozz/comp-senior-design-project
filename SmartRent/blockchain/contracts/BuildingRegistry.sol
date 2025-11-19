// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./BuildingToken.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

/**
 * @title BuildingRegistry
 * @dev Main contract for managing buildings, investments, and rental payments
 * Handles building creation, investment collection, and automatic rent distribution
 */
contract BuildingRegistry is Ownable, ReentrancyGuard {
    // Building structure
    struct Building {
        uint256 id;
        string name;
        string description;
        string location;
        address tokenAddress;        // Address of the BuildingToken contract
        uint256 totalShares;         // Total shares available (e.g., 10000)
        uint256 pricePerShare;       // Price per share in wei
        uint256 totalInvested;       // Total amount invested so far
        uint256 rentalPricePerDay;   // Daily rental price in wei
        address creator;             // Address that created the building
        bool exists;
        bool investmentOpen;        // Whether investment is still open
    }
    
    // Storage
    mapping(uint256 => Building) public buildings;
    mapping(address => uint256[]) public investorBuildings; // Investor address -> building IDs
    mapping(uint256 => uint256) public buildingRentals;     // Building ID -> total rental income
    mapping(uint256 => mapping(address => uint256)) public investorRentEarnings; // Building ID -> Investor -> Earnings
    
    uint256 private _buildingIdCounter;
    
    // Events
    event BuildingCreated(
        uint256 indexed buildingId,
        string name,
        address indexed tokenAddress,
        address indexed creator,
        uint256 totalShares,
        uint256 pricePerShare
    );
    
    event InvestmentMade(
        uint256 indexed buildingId,
        address indexed investor,
        uint256 amount,
        uint256 sharesReceived
    );
    
    event RentPaid(
        uint256 indexed buildingId,
        address indexed renter,
        uint256 amount,
        uint256 daysRented
    );
    
    event RentDistributed(
        uint256 indexed buildingId,
        uint256 totalAmount,
        uint256 distributedAmount
    );
    
    event InvestmentClosed(uint256 indexed buildingId);
    
    /**
     * @dev Create a new building and deploy its token contract
     * @param name Building name
     * @param description Building description
     * @param location Building location
     * @param totalShares Total number of shares (e.g., 10000 for 100%)
     * @param pricePerShare Price per share in wei
     * @param rentalPricePerDay Daily rental price in wei
     */
    function createBuilding(
        string memory name,
        string memory description,
        string memory location,
        uint256 totalShares,
        uint256 pricePerShare,
        uint256 rentalPricePerDay
    ) external returns (uint256) {
        require(bytes(name).length > 0, "Building name cannot be empty");
        require(totalShares > 0, "Total shares must be greater than 0");
        require(pricePerShare > 0, "Price per share must be greater than 0");
        require(rentalPricePerDay > 0, "Rental price must be greater than 0");
        
        uint256 buildingId = _buildingIdCounter++;
        
        // Deploy new BuildingToken contract
        BuildingToken token = new BuildingToken(
            buildingId,
            name,
            totalShares,
            address(this) // Registry owns the token initially
        );
        
        // Create building record
        buildings[buildingId] = Building({
            id: buildingId,
            name: name,
            description: description,
            location: location,
            tokenAddress: address(token),
            totalShares: totalShares,
            pricePerShare: pricePerShare,
            totalInvested: 0,
            rentalPricePerDay: rentalPricePerDay,
            creator: msg.sender,
            exists: true,
            investmentOpen: true
        });
        
        emit BuildingCreated(
            buildingId,
            name,
            address(token),
            msg.sender,
            totalShares,
            pricePerShare
        );
        
        return buildingId;
    }
    
    /**
     * @dev Invest in a building by purchasing shares
     * @param buildingId ID of the building to invest in
     */
    function investInBuilding(uint256 buildingId) external payable nonReentrant {
        Building storage building = buildings[buildingId];
        require(building.exists, "Building does not exist");
        require(building.investmentOpen, "Investment is closed for this building");
        
        BuildingToken token = BuildingToken(building.tokenAddress);
        require(!token.isFullyInvested(), "Building is fully invested");
        
        // Calculate how many shares can be purchased
        uint256 maxShares = token.getRemainingShares();
        uint256 sharesToBuy = msg.value / building.pricePerShare;
        
        require(sharesToBuy > 0, "Insufficient payment for at least one share");
        
        // Limit to remaining shares
        if (sharesToBuy > maxShares) {
            sharesToBuy = maxShares;
        }
        
        uint256 actualCost = sharesToBuy * building.pricePerShare;
        uint256 refund = msg.value - actualCost;
        
        // Mint tokens to investor
        token.mint(msg.sender, actualCost, sharesToBuy);
        
        // Update building stats
        building.totalInvested += actualCost;
        
        // Track investor's buildings
        bool alreadyInvested = false;
        for (uint256 i = 0; i < investorBuildings[msg.sender].length; i++) {
            if (investorBuildings[msg.sender][i] == buildingId) {
                alreadyInvested = true;
                break;
            }
        }
        if (!alreadyInvested) {
            investorBuildings[msg.sender].push(buildingId);
        }
        
        // Refund excess payment
        if (refund > 0) {
            payable(msg.sender).transfer(refund);
        }
        
        // Close investment if fully invested
        if (token.isFullyInvested()) {
            building.investmentOpen = false;
            emit InvestmentClosed(buildingId);
        }
        
        emit InvestmentMade(buildingId, msg.sender, actualCost, sharesToBuy);
    }
    
    /**
     * @dev Pay rent for a building (called by renter)
     * @param buildingId ID of the building being rented
     * @param daysRented Number of days being rented
     */
    function payRent(uint256 buildingId, uint256 daysRented) external payable nonReentrant {
        Building storage building = buildings[buildingId];
        require(building.exists, "Building does not exist");
        require(daysRented > 0, "Days rented must be greater than 0");
        
        uint256 totalRent = building.rentalPricePerDay * daysRented;
        require(msg.value >= totalRent, "Insufficient payment for rent");
        
        // Update rental income
        buildingRentals[buildingId] += totalRent;
        
        // Distribute rent to investors
        _distributeRent(buildingId, totalRent);
        
        // Refund excess payment
        if (msg.value > totalRent) {
            payable(msg.sender).transfer(msg.value - totalRent);
        }
        
        emit RentPaid(buildingId, msg.sender, totalRent, daysRented);
    }
    
    /**
     * @dev Internal function to distribute rent to token holders
     * @param buildingId ID of the building
     * @param rentAmount Total rent amount to distribute
     */
    function _distributeRent(uint256 buildingId, uint256 rentAmount) internal {
        Building storage building = buildings[buildingId];
        BuildingToken token = BuildingToken(building.tokenAddress);
        
        uint256 totalSupply = token.totalSupply();
        if (totalSupply == 0) {
            // No investors yet, keep rent in contract
            return;
        }
        
        // Distribute proportionally to all token holders
        // We need to track all holders, but ERC20 doesn't have an easy way to enumerate
        // For simplicity, we'll store earnings and let investors withdraw
        
        // Note: We use a withdrawal pattern - investors will claim their earnings
        // This is more gas-efficient than distributing to all holders immediately
        uint256 distributedAmount = 0; // Will be 0 as we use withdrawal pattern
        
        // Note: In a production system, you'd want to iterate through holders
        // For now, we'll use a withdrawal pattern where investors can claim their earnings
        // This is more gas-efficient for large numbers of investors
        
        // Store the rent amount for later distribution via withdrawal pattern
        // For this implementation, we'll distribute immediately to known holders
        // A better approach would be to use a withdrawal pattern
        
        // For simplicity, we'll keep the rent in the contract and allow withdrawal
        // This requires tracking earnings per investor, which we'll do in a separate mapping
        
        emit RentDistributed(buildingId, rentAmount, distributedAmount);
    }
    
    /**
     * @dev Withdraw accumulated rent earnings for a specific building
     * @param buildingId ID of the building
     */
    function withdrawRentEarnings(uint256 buildingId) external nonReentrant {
        Building storage building = buildings[buildingId];
        require(building.exists, "Building does not exist");
        
        BuildingToken token = BuildingToken(building.tokenAddress);
        uint256 balance = token.balanceOf(msg.sender);
        require(balance > 0, "No shares owned in this building");
        
        uint256 totalSupply = token.totalSupply();
        require(totalSupply > 0, "No tokens issued");
        
        // Calculate earnings based on total rentals and user's share
        uint256 totalRentals = buildingRentals[buildingId];
        uint256 userEarnings = (totalRentals * balance) / totalSupply;
        uint256 alreadyWithdrawn = investorRentEarnings[buildingId][msg.sender];
        uint256 withdrawable = userEarnings - alreadyWithdrawn;
        
        require(withdrawable > 0, "No earnings to withdraw");
        
        // Update withdrawn amount
        investorRentEarnings[buildingId][msg.sender] = userEarnings;
        
        // Transfer earnings
        payable(msg.sender).transfer(withdrawable);
    }
    
    /**
     * @dev Get investor's withdrawable earnings for a building
     * @param buildingId ID of the building
     * @param investor Address of the investor
     * @return Total earnings, already withdrawn, withdrawable amount
     */
    function getInvestorEarnings(uint256 buildingId, address investor) 
        external 
        view 
        returns (uint256, uint256, uint256) 
    {
        Building storage building = buildings[buildingId];
        require(building.exists, "Building does not exist");
        
        BuildingToken token = BuildingToken(building.tokenAddress);
        uint256 balance = token.balanceOf(investor);
        uint256 totalSupply = token.totalSupply();
        
        if (totalSupply == 0 || balance == 0) {
            return (0, 0, 0);
        }
        
        uint256 totalRentals = buildingRentals[buildingId];
        uint256 totalEarnings = (totalRentals * balance) / totalSupply;
        uint256 alreadyWithdrawn = investorRentEarnings[buildingId][investor];
        uint256 withdrawable = totalEarnings - alreadyWithdrawn;
        
        return (totalEarnings, alreadyWithdrawn, withdrawable);
    }
    
    /**
     * @dev Get building information
     * @param buildingId ID of the building
     * @return Building struct
     */
    function getBuilding(uint256 buildingId) external view returns (Building memory) {
        require(buildings[buildingId].exists, "Building does not exist");
        return buildings[buildingId];
    }
    
    /**
     * @dev Get all buildings an investor has invested in
     * @param investor Address of the investor
     * @return Array of building IDs
     */
    function getInvestorBuildings(address investor) external view returns (uint256[] memory) {
        return investorBuildings[investor];
    }
    
    /**
     * @dev Get total number of buildings
     * @return Total count
     */
    function getTotalBuildings() external view returns (uint256) {
        return _buildingIdCounter;
    }
    
    /**
     * @dev Close investment for a building (only owner)
     * @param buildingId ID of the building
     */
    function closeInvestment(uint256 buildingId) external onlyOwner {
        Building storage building = buildings[buildingId];
        require(building.exists, "Building does not exist");
        building.investmentOpen = false;
        emit InvestmentClosed(buildingId);
    }
}


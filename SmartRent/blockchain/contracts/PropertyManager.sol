// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "./PropertyToken.sol";

/**
 * @title PropertyManager
 * @dev Smart contract for managing rental income distribution to property token holders
 * - Automatically distributes rental income to all token holders based on their ownership percentage
 * - Funds are sent directly to investor wallets (no manual withdrawal needed)
 * - Uses PropertyToken contract to track ownership
 */
contract PropertyManager is Ownable, ReentrancyGuard {
    // Reference to PropertyToken contract
    PropertyToken public propertyToken;

    // Total rental income distributed (for tracking)
    uint256 public totalRentalIncomeDistributed;

    // Mapping to track rental income per distribution
    mapping(uint256 => RentalDistribution) public rentalDistributions;

    // Rental distribution counter
    uint256 public distributionCounter;

    // Struct for rental distribution record
    struct RentalDistribution {
        uint256 amount;
        uint256 timestamp;
        uint256 investorCount;
    }

    // Events
    event RentalIncomeDistributed(
        uint256 indexed distributionId,
        uint256 totalAmount,
        uint256 timestamp,
        uint256 investorCount
    );

    event IncomeSent(
        address indexed investor,
        uint256 amount,
        uint256 tokensOwned,
        uint256 ownershipPercentage
    );

    /**
     * @dev Constructor - sets the PropertyToken contract address
     * @param _propertyTokenAddress Address of the PropertyToken contract
     */
    constructor(address _propertyTokenAddress) Ownable(msg.sender) {
        require(_propertyTokenAddress != address(0), "Invalid token address");
        propertyToken = PropertyToken(_propertyTokenAddress);
    }

    /**
     * @dev Distribute rental income to all token holders based on their ownership percentage
     * This function automatically sends ETH directly to investor wallets
     * @notice Call this function with ETH value (e.g., 1 ETH) to distribute rental income
     */
    function distributeRentalIncome() public payable nonReentrant {
        require(msg.value > 0, "No rental income provided");
        require(
            propertyToken.totalSupply() > 0,
            "No tokens have been sold yet"
        );

        uint256 totalSupply = propertyToken.TOTAL_SUPPLY();
        require(totalSupply > 0, "Property not initialized");

        // Get all investors
        address[] memory investors = propertyToken.getAllInvestors();
        require(investors.length > 0, "No investors found");

        totalRentalIncomeDistributed += msg.value;
        uint256 totalDistributed = 0;
        uint256 investorCount = 0;

        // Distribute income proportionally to all investors and send directly
        for (uint256 i = 0; i < investors.length; i++) {
            address investor = investors[i];
            uint256 tokensOwned = propertyToken.balanceOf(investor);

            if (tokensOwned > 0) {
                // Calculate share: (tokensOwned / totalSupply) * rentalIncome
                uint256 share = (msg.value * tokensOwned) / totalSupply;

                if (share > 0) {
                    // Send ETH directly to investor wallet
                    (bool success, ) = payable(investor).call{value: share}("");
                    require(success, "Failed to send ETH to investor");

                    totalDistributed += share;
                    investorCount++;

                    // Calculate ownership percentage for event
                    uint256 ownershipPercentage = (tokensOwned * 100) /
                        totalSupply;

                    emit IncomeSent(
                        investor,
                        share,
                        tokensOwned,
                        ownershipPercentage
                    );
                }
            }
        }

        // Refund any remaining dust (due to rounding) to owner
        uint256 remaining = msg.value - totalDistributed;
        if (remaining > 0) {
            (bool success, ) = payable(owner()).call{value: remaining}("");
            require(success, "Failed to refund remaining amount");
        }

        // Record distribution
        distributionCounter++;
        rentalDistributions[distributionCounter] = RentalDistribution({
            amount: msg.value,
            timestamp: block.timestamp,
            investorCount: investorCount
        });

        emit RentalIncomeDistributed(
            distributionCounter,
            msg.value,
            block.timestamp,
            investorCount
        );
    }

    /**
     * @dev Get rental distribution details
     * @param _distributionId Distribution ID
     * @return RentalDistribution struct
     */
    function getRentalDistribution(
        uint256 _distributionId
    ) public view returns (RentalDistribution memory) {
        return rentalDistributions[_distributionId];
    }

    /**
     * @dev Get total number of distributions
     * @return Number of rental distributions made
     */
    function getDistributionCount() public view returns (uint256) {
        return distributionCounter;
    }

    /**
     * @dev Calculate how much an investor would receive for a given rental amount
     * @param _investor Investor address
     * @param _rentalAmount Rental income amount in wei
     * @return Amount investor would receive in wei
     */
    function calculateInvestorShare(
        address _investor,
        uint256 _rentalAmount
    ) public view returns (uint256) {
        uint256 tokensOwned = propertyToken.balanceOf(_investor);
        if (tokensOwned == 0) {
            return 0;
        }
        uint256 totalSupply = propertyToken.TOTAL_SUPPLY();
        return (_rentalAmount * tokensOwned) / totalSupply;
    }

    /**
     * @dev Get investor's expected share percentage
     * @param _investor Investor address
     * @return Ownership percentage (0-100)
     */
    function getInvestorOwnershipPercentage(
        address _investor
    ) public view returns (uint256) {
        return propertyToken.getInvestorShare(_investor);
    }

    /**
     * @dev Update PropertyToken contract address (only owner)
     * @param _newTokenAddress New PropertyToken contract address
     */
    function updatePropertyTokenAddress(
        address _newTokenAddress
    ) public onlyOwner {
        require(_newTokenAddress != address(0), "Invalid token address");
        propertyToken = PropertyToken(_newTokenAddress);
    }

    /**
     * @dev Emergency function to withdraw contract balance (only owner)
     * @notice Use only in emergency situations
     */
    function emergencyWithdraw() public onlyOwner {
        uint256 balance = address(this).balance;
        require(balance > 0, "No funds to withdraw");
        payable(owner()).transfer(balance);
    }

    /**
     * @dev Receive function to accept ETH
     * @notice ETH sent directly to contract will be held until distributeRentalIncome is called
     */
    receive() external payable {
        // Allow direct ETH transfers to contract
        // Users should call distributeRentalIncome() to distribute funds
    }
}


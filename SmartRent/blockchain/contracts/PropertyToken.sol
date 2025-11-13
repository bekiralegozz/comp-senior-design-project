// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/**
 * @title PropertyToken
 * @dev ERC-20 token contract for fractional property ownership
 * Each property has exactly 100 tokens (each token = 1% ownership)
 * Uses OpenZeppelin ERC20 standard for token functionality
 */
contract PropertyToken is ERC20, Ownable, ReentrancyGuard {
    // Property information
    struct Property {
        string name;
        string description;
        string location;
        uint256 tokenPrice; // Price per token in wei
        bool initialized;
    }

    // Property data
    Property public property;

    // Total supply is fixed at 100 tokens (100%)
    uint256 public constant TOTAL_SUPPLY = 100 * 10**18; // 100 tokens with 18 decimals
    uint256 public constant TOKENS_PER_PERCENT = 1 * 10**18; // 1 token = 1%

    // Token price for purchase
    uint256 public tokenPrice;

    // Mapping to track if address has purchased tokens
    mapping(address => bool) public hasPurchased;

    // List of all token holders (investors)
    address[] public investors;

    // Events
    event PropertyInitialized(
        string indexed name,
        string location,
        uint256 tokenPrice
    );

    event TokensPurchased(
        address indexed investor,
        uint256 amount,
        uint256 totalPaid,
        uint256 ownershipPercentage
    );

    constructor() ERC20("Property Token", "PROP") Ownable(msg.sender) {
        // Contract is deployed but property not initialized yet
    }

    /**
     * @dev Initialize a property with token price
     * @param _name Property name
     * @param _description Property description
     * @param _location Property location
     * @param _tokenPrice Price per token in wei
     */
    function initializeProperty(
        string memory _name,
        string memory _description,
        string memory _location,
        uint256 _tokenPrice
    ) public onlyOwner {
        require(!property.initialized, "Property already initialized");
        require(bytes(_name).length > 0, "Property name cannot be empty");
        require(_tokenPrice > 0, "Token price must be greater than 0");

        property = Property({
            name: _name,
            description: _description,
            location: _location,
            tokenPrice: _tokenPrice,
            initialized: true
        });

        tokenPrice = _tokenPrice;

        emit PropertyInitialized(_name, _location, _tokenPrice);
    }

    /**
     * @dev Buy tokens for the property
     * @param _amount Number of tokens to buy (in wei, considering 18 decimals)
     */
    function buyTokens(uint256 _amount) public payable nonReentrant {
        require(property.initialized, "Property not initialized");
        require(_amount > 0, "Amount must be greater than 0");
        require(
            totalSupply() + _amount <= TOTAL_SUPPLY,
            "Not enough tokens available"
        );

        // Calculate cost: amount * price per token
        // _amount is in wei (with 18 decimals), tokenPrice is in wei
        uint256 totalCost = (_amount * tokenPrice) / 10**18;
        require(msg.value >= totalCost, "Insufficient payment");

        // Mint tokens to buyer
        _mint(msg.sender, _amount);

        // Add to investors list if first purchase
        if (!hasPurchased[msg.sender]) {
            investors.push(msg.sender);
            hasPurchased[msg.sender] = true;
        }

        // Refund excess payment
        if (msg.value > totalCost) {
            payable(msg.sender).transfer(msg.value - totalCost);
        }

        // Calculate ownership percentage (each token = 1%)
        uint256 ownershipPercentage = (_amount * 100) / TOTAL_SUPPLY;

        emit TokensPurchased(
            msg.sender,
            _amount,
            totalCost,
            ownershipPercentage
        );
    }

    /**
     * @dev Buy tokens by percentage (easier for users)
     * @param _percentage Percentage of ownership to buy (1-100)
     */
    function buyTokensByPercentage(uint256 _percentage) public payable {
        require(_percentage > 0 && _percentage <= 100, "Invalid percentage");
        uint256 tokensToBuy = (TOTAL_SUPPLY * _percentage) / 100;
        buyTokens(tokensToBuy);
    }

    /**
     * @dev Get investor's ownership percentage
     * @param _investor Investor address
     * @return Percentage of ownership (0-100)
     */
    function getInvestorShare(address _investor) public view returns (uint256) {
        uint256 balance = balanceOf(_investor);
        return (balance * 100) / TOTAL_SUPPLY;
    }

    /**
     * @dev Get number of tokens available for purchase
     * @return Number of available tokens (in wei with 18 decimals)
     */
    function getAvailableTokens() public view returns (uint256) {
        return TOTAL_SUPPLY - totalSupply();
    }

    /**
     * @dev Get available tokens as percentage
     * @return Percentage of tokens still available (0-100)
     */
    function getAvailablePercentage() public view returns (uint256) {
        uint256 available = getAvailableTokens();
        return (available * 100) / TOTAL_SUPPLY;
    }

    /**
     * @dev Get property information
     * @return Property struct
     */
    function getPropertyInfo() public view returns (Property memory) {
        return property;
    }

    /**
     * @dev Get all investors
     * @return Array of investor addresses
     */
    function getAllInvestors() public view returns (address[] memory) {
        return investors;
    }

    /**
     * @dev Get investor count
     * @return Number of investors
     */
    function getInvestorCount() public view returns (uint256) {
        return investors.length;
    }

    /**
     * @dev Get investor details (balance and percentage)
     * @param _investor Investor address
     * @return balance Token balance (in wei with 18 decimals)
     * @return percentage Ownership percentage (0-100)
     */
    function getInvestorDetails(address _investor)
        public
        view
        returns (uint256 balance, uint256 percentage)
    {
        balance = balanceOf(_investor);
        percentage = getInvestorShare(_investor);
    }

    /**
     * @dev Override decimals to use 18 (standard ERC20)
     */
    function decimals() public pure override returns (uint8) {
        return 18;
    }

    /**
     * @dev Emergency function to withdraw contract balance (only owner)
     */
    function emergencyWithdraw() public onlyOwner {
        uint256 balance = address(this).balance;
        require(balance > 0, "No funds to withdraw");
        payable(owner()).transfer(balance);
    }

    /**
     * @dev Receive function to accept ETH
     */
    receive() external payable {
        // Allow direct ETH transfers to contract
    }
}


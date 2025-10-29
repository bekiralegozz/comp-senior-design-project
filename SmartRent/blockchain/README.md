# SmartRent Blockchain

Smart contracts for the SmartRent blockchain-enabled rental and asset-sharing platform.

## Overview

This module contains the Ethereum smart contracts that power SmartRent's decentralized rental system:

- **AssetToken.sol**: ERC-721 NFT contract for tokenizing physical assets
- **RentalAgreement.sol**: Escrow and rental management contract with automated lifecycle

## Features

### AssetToken Contract
- 🎨 **NFT Representation**: Each physical asset is represented as a unique NFT
- 🏷️ **Rich Metadata**: Store asset name, description, category, location, and pricing
- 🔐 **Access Control**: Owner and operator permissions for rental management
- 📊 **Asset Discovery**: Query assets by owner, category, and availability
- 💰 **Dynamic Pricing**: Set and update rental prices per asset

### RentalAgreement Contract
- 🤝 **Escrow System**: Secure payment handling with automatic fund release
- 🔒 **Security Deposits**: Configurable deposits with automated return
- ⏰ **Time-based Logic**: Rental periods with start/end time enforcement
- 🛡️ **Dispute Resolution**: Admin-mediated dispute resolution system
- 💸 **Platform Fees**: Configurable fee structure for platform sustainability
- 🚨 **Emergency Controls**: Pause functionality and emergency withdrawal

## Quick Start

### Prerequisites

- Node.js 16+ and npm
- Hardhat development environment
- MetaMask or similar Ethereum wallet
- Infura/Alchemy account for testnet deployment

### Installation

```bash
# Navigate to blockchain directory
cd blockchain/

# Install dependencies
npm install

# Create environment file
cp .env.example .env
```

### Environment Configuration

Create `.env` file with your configuration:

```bash
# Wallet private key (DO NOT commit this!)
PRIVATE_KEY=your_private_key_here

# RPC Provider URLs
INFURA_PROJECT_ID=your_infura_project_id
ALCHEMY_KEY=your_alchemy_api_key

# API Keys for contract verification
ETHERSCAN_API_KEY=your_etherscan_api_key
POLYGONSCAN_API_KEY=your_polygonscan_api_key
BSCSCAN_API_KEY=your_bscscan_api_key

# Optional: Gas reporting
COINMARKETCAP_API_KEY=your_coinmarketcap_api_key
REPORT_GAS=true
```

### Compile Contracts

```bash
# Compile all contracts
npm run compile

# Clean build artifacts
npm run clean
```

### Testing

```bash
# Run all tests
npm run test

# Run with gas reporting
npm run gas-report

# Generate coverage report
npm run coverage
```

### Deployment

#### Local Development
```bash
# Start local Hardhat node
npm run node

# Deploy to local network (in another terminal)
npx hardhat run scripts/deploy.js --network localhost
```

#### Testnet Deployment
```bash
# Deploy to Goerli testnet
npm run deploy:testnet

# Verify contracts on Etherscan
npx hardhat verify --network goerli CONTRACT_ADDRESS
```

#### Mainnet Deployment
```bash
# Deploy to Ethereum mainnet
npm run deploy:mainnet
```

## Contract Addresses

Update after deployment:

### Goerli Testnet
- AssetToken: `0x...` (Update after deployment)
- RentalAgreement: `0x...` (Update after deployment)

### Ethereum Mainnet
- AssetToken: `0x...` (Update after deployment)
- RentalAgreement: `0x...` (Update after deployment)

## Usage Examples

### Minting an Asset NFT

```solidity
// Connect to AssetToken contract
AssetToken assetToken = AssetToken(CONTRACT_ADDRESS);

// Mint a new asset
uint256 tokenId = assetToken.mintAsset(
    msg.sender,                    // owner
    "Tesla Model 3",               // name
    "Electric vehicle for rent",   // description
    "vehicles",                    // category
    "San Francisco, CA",           // location
    0.1 ether,                     // price per day (in wei)
    "https://ipfs.io/ipfs/..."     // metadata URI
);
```

### Creating a Rental Agreement

```solidity
// Connect to RentalAgreement contract
RentalAgreement rental = RentalAgreement(CONTRACT_ADDRESS);

// Create rental with payment
uint256 rentalId = rental.createRental{value: totalCost}(
    tokenId,                       // asset token ID
    startTime,                     // rental start timestamp
    endTime,                       // rental end timestamp
    securityDeposit                // security deposit amount
);
```

### Managing Rental Lifecycle

```solidity
// Start rental (called by renter when period begins)
rental.startRental(rentalId);

// Complete rental (called by either party)
rental.completeRental(rentalId);

// Cancel rental (before it starts)
rental.cancelRental(rentalId);
```

## Integration with Backend

The Python backend integrates with these contracts through Web3.py:

```python
from app.core.web3_utils import get_web3

# Get Web3 manager instance
w3_manager = get_web3()

# Interact with AssetToken contract
asset_contract = w3_manager.get_contract(
    address=settings.CONTRACT_ADDRESS_ASSET_TOKEN,
    abi=asset_token_abi
)

# Mint asset NFT
tx_hash = asset_contract.functions.mintAsset(
    owner_address,
    name,
    description,
    category,
    location,
    price_per_day,
    token_uri
).transact({'from': w3_manager.account.address})
```

## Security Considerations

### Smart Contract Security
- ✅ **ReentrancyGuard**: Protection against reentrancy attacks
- ✅ **Access Control**: Proper permission checks for all functions
- ✅ **Input Validation**: Comprehensive validation of all inputs
- ✅ **SafeMath**: Built-in overflow protection (Solidity 0.8+)
- ✅ **Pausable**: Emergency pause functionality

### Operational Security
- 🔐 **Private Key Management**: Never commit private keys to version control
- 🌐 **Network Configuration**: Use reputable RPC providers
- 📊 **Gas Optimization**: Contracts optimized for gas efficiency
- 🔍 **Contract Verification**: Verify contracts on Etherscan after deployment

## Development

### Code Quality

```bash
# Lint Solidity code
npm run lint

# Fix linting issues
npm run lint:fix

# Format code
npm run prettier

# Check contract sizes
npm run size
```

### Testing Strategy

1. **Unit Tests**: Test individual contract functions
2. **Integration Tests**: Test contract interactions
3. **Scenario Tests**: Test complete rental workflows
4. **Gas Tests**: Optimize for gas efficiency

### Adding New Features

1. Write comprehensive tests first
2. Implement the smart contract feature
3. Add integration with backend API
4. Update documentation
5. Deploy and verify on testnet

## Troubleshooting

### Common Issues

**Compilation Errors**
```bash
# Clear cache and rebuild
npm run clean
npm run compile
```

**Deployment Failures**
- Check network configuration in `hardhat.config.js`
- Verify private key and RPC URL in `.env`
- Ensure sufficient ETH balance for gas fees

**Transaction Reverts**
- Check function requirements and validation
- Verify contract state and permissions
- Use hardhat console for debugging

### Getting Help

- Review Hardhat documentation: https://hardhat.org/docs
- Check OpenZeppelin contracts: https://docs.openzeppelin.com/contracts
- Ethereum development resources: https://ethereum.org/developers

## Contributing

1. Follow established coding patterns
2. Add comprehensive tests for new features
3. Update documentation
4. Use conventional commit messages
5. Ensure all tests pass before submitting

## License

MIT License - see LICENSE file for details









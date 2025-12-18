/// Blockchain Configuration
/// Polygon Mainnet configuration for SmartRent contracts
class BlockchainConfig {
  // Polygon RPC URL (Free Public RPC)
  static const String polygonRpcUrl = 'https://polygon-rpc.com';

  // Polygon Chain ID
  static const int chainId = 137;

  // Contract Addresses (TODO: Deploy to Polygon Mainnet)
  static const String building1122Address = '0x0000000000000000000000000000000000000000';
  static const String rentalManagerAddress = '0x0000000000000000000000000000000000000000';
  static const String marketplaceAddress = '0x0000000000000000000000000000000000000000';

  // Network Configuration
  static const String networkName = 'Polygon Mainnet';
  static const String currencySymbol = 'MATIC';
  static const int decimals = 18;

  // Gas Configuration
  static const int defaultGasLimit = 300000;
  static final BigInt maxGasPrice = BigInt.from(100000000000); // 100 gwei
}


/// Blockchain Configuration
/// Polygon Mainnet configuration for SmartRent contracts
class BlockchainConfig {
  // Polygon RPC URL (Free Public RPC)
  static const String polygonRpcUrl = 'https://polygon-rpc.com';

  // Polygon Chain ID
  static const int chainId = 137;

  // Contract Addresses - DEPLOYED ON POLYGON MAINNET (18 Aralık 2024)
  static const String building1122Address = '0x6b9aa94207650AaeC4a89F6818c4E8791AF10ed3';
  static const String smartRentHubAddress = '0x6E5FF6db7cdB03881710A497e449274ab8c4a3d0';
  static const String rentalManagerAddress = '0x45FAd67F890a4154C5c83191231BD2E20048a729';
  
  // Legacy alias
  static const String marketplaceAddress = smartRentHubAddress;

  // Network Configuration
  static const String networkName = 'Polygon Mainnet';
  static const String currencySymbol = 'POL'; // Rebranded from MATIC
  static const int decimals = 18;

  // Gas Configuration
  static const int defaultGasLimit = 300000;
  static final BigInt maxGasPrice = BigInt.from(100000000000); // 100 gwei
}


/// Blockchain Configuration
/// Sepolia Testnet configuration for SmartRent contracts
class BlockchainConfig {
  // Sepolia RPC URL (Alchemy)
  static const String sepoliaRpcUrl =
      'https://eth-sepolia.g.alchemy.com/v2/e7KBw7Uhu7r1meEBJRPyZ';

  // Sepolia Chain ID
  static const int chainId = 11155111;

  // Contract Addresses (Deployed on Sepolia)
  static const String building1122Address =
      '0x56cefb343baf4573af99b9128e498f1e68178816';
  static const String rentalManagerAddress =
      '0x57044386a0c5fb623315dd5b8eeea6078bb9193c';
  static const String marketplaceAddress =
      '0x2ffcd104d50c99d24d76acfc3ef1dfb550127a1f';

  // Network Configuration
  static const String networkName = 'Sepolia Testnet';
  static const String currencySymbol = 'ETH';
  static const int decimals = 18;

  // Gas Configuration
  static const int defaultGasLimit = 300000;
  static final BigInt maxGasPrice = BigInt.from(100000000000); // 100 gwei
}


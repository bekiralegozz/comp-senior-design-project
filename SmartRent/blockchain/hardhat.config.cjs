require("@nomicfoundation/hardhat-toolbox");
require("dotenv/config");

/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  solidity: {
    version: "0.8.20",
    settings: {
      optimizer: {
        enabled: true,
        runs: 10000 // Maksimum optimize - deployment çok ucuzlar
      },
      viaIR: true // Daha agresif Yul optimizer
    }
  },
  networks: {
    polygon: {
      url: process.env.POLYGON_RPC_URL || "https://polygon-rpc.com",
      accounts: process.env.WALLET_PRIVATE_KEY ? [process.env.WALLET_PRIVATE_KEY] : [],
      chainId: 137,
      // Gas price: AUTO (Infura otomatik belirliyor)
      gas: 8000000,
      timeout: 600000, // 10 dakika
      confirmations: 2, // 2 confirmation (güvenli)
      httpHeaders: {
        'User-Agent': 'hardhat'
      }
    },
    hardhat: {
      chainId: 1337
    }
  },
  etherscan: {
    apiKey: {
      polygon: process.env.POLYGONSCAN_API_KEY || ""
    }
  }
};

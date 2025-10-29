require("@nomicfoundation/hardhat-toolbox");
require("@nomiclabs/hardhat-etherscan");
require("hardhat-gas-reporter");
require("solidity-coverage");
require("hardhat-contract-sizer");
require("dotenv").config();

// Ensure private key exists or use dummy key for development
const PRIVATE_KEY = process.env.PRIVATE_KEY || "0x1234567890123456789012345678901234567890123456789012345678901234";

// API keys
const INFURA_PROJECT_ID = process.env.INFURA_PROJECT_ID || "";
const ALCHEMY_KEY = process.env.ALCHEMY_KEY || "";
const ETHERSCAN_API_KEY = process.env.ETHERSCAN_API_KEY || "";
const COINMARKETCAP_API_KEY = process.env.COINMARKETCAP_API_KEY || "";

/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  solidity: {
    version: "0.8.19",
    settings: {
      optimizer: {
        enabled: true,
        runs: 200,
      },
      viaIR: true,
    },
  },
  
  networks: {
    // Local development network
    hardhat: {
      chainId: 31337,
      gas: 12000000,
      blockGasLimit: 0x1fffffffffffff,
      allowUnlimitedContractSize: true,
      timeout: 1800000
    },
    
    // Local node for testing
    localhost: {
      url: "http://127.0.0.1:8545",
      chainId: 31337,
    },
    
    // Ethereum Mainnet
    mainnet: {
      url: INFURA_PROJECT_ID 
        ? `https://mainnet.infura.io/v3/${INFURA_PROJECT_ID}` 
        : `https://eth-mainnet.g.alchemy.com/v2/${ALCHEMY_KEY}`,
      accounts: [PRIVATE_KEY],
      chainId: 1,
      gas: "auto",
      gasPrice: "auto",
    },
    
    // Ethereum Testnets
    goerli: {
      url: INFURA_PROJECT_ID 
        ? `https://goerli.infura.io/v3/${INFURA_PROJECT_ID}` 
        : `https://eth-goerli.g.alchemy.com/v2/${ALCHEMY_KEY}`,
      accounts: [PRIVATE_KEY],
      chainId: 5,
      gas: "auto",
      gasPrice: "auto",
    },
    
    sepolia: {
      url: INFURA_PROJECT_ID 
        ? `https://sepolia.infura.io/v3/${INFURA_PROJECT_ID}` 
        : `https://eth-sepolia.g.alchemy.com/v2/${ALCHEMY_KEY}`,
      accounts: [PRIVATE_KEY],
      chainId: 11155111,
      gas: "auto",
      gasPrice: "auto",
    },
    
    // Polygon networks
    polygon: {
      url: INFURA_PROJECT_ID 
        ? `https://polygon-mainnet.infura.io/v3/${INFURA_PROJECT_ID}`
        : `https://polygon-mainnet.g.alchemy.com/v2/${ALCHEMY_KEY}`,
      accounts: [PRIVATE_KEY],
      chainId: 137,
    },
    
    mumbai: {
      url: INFURA_PROJECT_ID 
        ? `https://polygon-mumbai.infura.io/v3/${INFURA_PROJECT_ID}`
        : `https://polygon-mumbai.g.alchemy.com/v2/${ALCHEMY_KEY}`,
      accounts: [PRIVATE_KEY],
      chainId: 80001,
    },
    
    // BSC networks
    bsc: {
      url: "https://bsc-dataseed1.binance.org/",
      accounts: [PRIVATE_KEY],
      chainId: 56,
    },
    
    bscTestnet: {
      url: "https://data-seed-prebsc-1-s1.binance.org:8545/",
      accounts: [PRIVATE_KEY],
      chainId: 97,
    }
  },
  
  // Etherscan verification configuration
  etherscan: {
    apiKey: {
      mainnet: ETHERSCAN_API_KEY,
      goerli: ETHERSCAN_API_KEY,
      sepolia: ETHERSCAN_API_KEY,
      polygon: process.env.POLYGONSCAN_API_KEY || "",
      polygonMumbai: process.env.POLYGONSCAN_API_KEY || "",
      bsc: process.env.BSCSCAN_API_KEY || "",
      bscTestnet: process.env.BSCSCAN_API_KEY || "",
    }
  },
  
  // Gas reporter configuration
  gasReporter: {
    enabled: process.env.REPORT_GAS !== undefined,
    currency: "USD",
    gasPrice: 20,
    coinmarketcap: COINMARKETCAP_API_KEY,
    excludeContracts: ["test/", "mock/"],
  },
  
  // Contract size reporter
  contractSizer: {
    alphaSort: true,
    disambiguatePaths: false,
    runOnCompile: true,
    strict: true,
  },
  
  // Coverage configuration
  coverage: {
    skipFiles: ["test/", "mock/"],
  },
  
  // Path configuration
  paths: {
    sources: "./contracts",
    tests: "./test",
    cache: "./cache",
    artifacts: "./artifacts"
  },
  
  // Mocha test configuration
  mocha: {
    timeout: 40000
  }
};









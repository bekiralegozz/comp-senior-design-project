require('dotenv').config();

module.exports = {
  /**
   * Networks define how you connect to your ethereum client and let you set the
   * defaults web3 uses to send transactions. If you don't specify one truffle
   * will spin up a development blockchain for you on port 9545 when you
   * run `truffle develop`. You can ask a truffle command to use a specific
   * network from the command line, e.g
   *
   * $ truffle test --network ganache
   */

  networks: {
    // Ganache local blockchain
    ganache: {
      host: "127.0.0.1",
      port: 7545,
      network_id: 5777, // Ganache network ID
      gas: 6721975,     // Ganache gas limit
      gasPrice: 20000000000, // Ganache gas price
    },

    // Development network (Truffle's built-in)
    development: {
      host: "127.0.0.1",
      port: 8545,
      network_id: "*", // Match any network id
    },
  },

  // Set default mocha options here, use special reporters etc.
  mocha: {
    // timeout: 100000
  },

  // Configure your compilers
  compilers: {
    solc: {
      version: "0.8.19",    // Fetch exact version from solc-bin
      settings: {          // See the solidity docs for advice about optimization and evmVersion
        optimizer: {
          enabled: true,
          runs: 200
        },
        evmVersion: "london"
      }
    }
  }
};


import { ethers } from 'ethers';
import config from '../config/config.js';

/**
 * Web3 Service
 * Handles Ethereum provider and wallet setup
 */
class Web3Service {
  constructor() {
    // Initialize provider
    this.provider = new ethers.JsonRpcProvider(config.sepolia.rpcUrl);

    // Initialize wallet
    if (config.wallet.privateKey) {
      this.wallet = new ethers.Wallet(config.wallet.privateKey, this.provider);
    } else if (config.wallet.mnemonic) {
      this.wallet = ethers.Wallet.fromPhrase(config.wallet.mnemonic).connect(this.provider);
    } else {
      throw new Error('Wallet configuration is missing. Please set SERVER_PRIVATE_KEY or SERVER_MNEMONIC in .env file.');
    }

    console.log(`🔑 Wallet address: ${this.wallet.address}`);
  }

  /**
   * Get provider instance
   * @returns {ethers.JsonRpcProvider}
   */
  getProvider() {
    return this.provider;
  }

  /**
   * Get wallet instance (signer)
   * @returns {ethers.Wallet}
   */
  getWallet() {
    return this.wallet;
  }

  /**
   * Get wallet balance
   * @returns {Promise<string>} Balance in ETH
   */
  async getBalance() {
    const balance = await this.provider.getBalance(this.wallet.address);
    return ethers.formatEther(balance);
  }

  /**
   * Wait for transaction confirmation
   * @param {string} txHash - Transaction hash
   * @param {number} confirmations - Number of confirmations to wait (default: 1)
   * @returns {Promise<ethers.TransactionReceipt>}
   */
  async waitForTransaction(txHash, confirmations = 1) {
    return await this.provider.waitForTransaction(txHash, confirmations);
  }
}

// Export singleton instance
export default new Web3Service();


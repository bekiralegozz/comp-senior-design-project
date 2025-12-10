import { ethers } from 'ethers';
import web3Service from '../services/web3.js';
import config from '../config/config.js';
import Building1122ABI from '../../abis/Building1122.json' assert { type: 'json' };

/**
 * Building1122 Contract Wrapper
 * ERC-1155 compatible multi-token contract for fractional ownership
 */
class Building1122Contract {
  constructor() {
    this.address = config.contracts.building1122;
    this.contract = new ethers.Contract(
      this.address,
      Building1122ABI,
      web3Service.getWallet()
    );
  }

  /**
   * Mint initial supply for a new asset
   * @param {number} tokenId - Token ID (asset ID)
   * @param {string} initialOwner - Initial owner address
   * @param {number} amount - Total supply amount
   * @param {string} metadataURI - Metadata URI (optional)
   * @returns {Promise<ethers.ContractTransactionResponse>}
   */
  async mintInitialSupply(tokenId, initialOwner, amount, metadataURI = '') {
    try {
      const tx = await this.contract.mintInitialSupply(
        tokenId,
        initialOwner,
        amount,
        metadataURI
      );
      return tx;
    } catch (error) {
      console.error(`Error minting initial supply for tokenId ${tokenId}:`, error);
      throw error;
    }
  }

  /**
   * Get balance of an account for a specific token
   * @param {string} account - Account address
   * @param {number} tokenId - Token ID
   * @returns {Promise<bigint>} Balance
   */
  async balanceOf(account, tokenId) {
    try {
      return await this.contract.balanceOf(account, tokenId);
    } catch (error) {
      console.error(`Error getting balance for account ${account}, tokenId ${tokenId}:`, error);
      throw error;
    }
  }

  /**
   * Get ownership percentage
   * @param {string} account - Account address
   * @param {number} tokenId - Token ID
   * @returns {Promise<number>} Ownership percentage (in basis points, e.g., 5000 = 50%)
   */
  async getOwnershipPercentage(account, tokenId) {
    try {
      return await this.contract.getOwnershipPercentage(account, tokenId);
    } catch (error) {
      console.error(`Error getting ownership percentage for account ${account}, tokenId ${tokenId}:`, error);
      throw error;
    }
  }

  /**
   * Check if token exists
   * @param {number} tokenId - Token ID
   * @returns {Promise<boolean>}
   */
  async exists(tokenId) {
    try {
      return await this.contract.exists(tokenId);
    } catch (error) {
      console.error(`Error checking existence for tokenId ${tokenId}:`, error);
      throw error;
    }
  }

  /**
   * Get total supply for a token
   * @param {number} tokenId - Token ID
   * @returns {Promise<bigint>} Total supply
   */
  async totalSupply(tokenId) {
    try {
      return await this.contract.totalSupply(tokenId);
    } catch (error) {
      console.error(`Error getting total supply for tokenId ${tokenId}:`, error);
      throw error;
    }
  }

  /**
   * Get contract instance for event listening
   * @returns {ethers.Contract} Contract instance with provider (not wallet)
   */
  getContractForEvents() {
    return new ethers.Contract(
      this.address,
      Building1122ABI,
      web3Service.getProvider()
    );
  }
}

export default new Building1122Contract();


import { ethers } from 'ethers';
import web3Service from '../services/web3.js';
import config from '../config/config.js';
import RentalManagerABI from '../../abis/RentalManager.json' assert { type: 'json' };

/**
 * RentalManager Contract Wrapper
 * Handles rent payments and distribution to fractional owners
 */
class RentalManagerContract {
  constructor() {
    this.address = config.contracts.rentalManager;
    this.contract = new ethers.Contract(
      this.address,
      RentalManagerABI,
      web3Service.getWallet()
    );
  }

  /**
   * Pay rent for an asset
   * @param {number} assetId - Asset ID (tokenId)
   * @param {Array<string>} owners - Array of owner addresses
   * @param {string} amount - Amount in ETH (as string, e.g., "0.1")
   * @returns {Promise<ethers.ContractTransactionResponse>}
   */
  async payRent(assetId, owners, amount) {
    try {
      const value = ethers.parseEther(amount);
      const tx = await this.contract.payRent(assetId, owners, { value });
      return tx;
    } catch (error) {
      console.error(`Error paying rent for assetId ${assetId}:`, error);
      throw error;
    }
  }

  /**
   * Get total rent collected for an asset
   * @param {number} assetId - Asset ID
   * @returns {Promise<bigint>} Total rent collected (in wei)
   */
  async getTotalRentCollected(assetId) {
    try {
      return await this.contract.getTotalRentCollected(assetId);
    } catch (error) {
      console.error(`Error getting total rent collected for assetId ${assetId}:`, error);
      throw error;
    }
  }

  /**
   * Get rent payment count for an asset
   * @param {number} assetId - Asset ID
   * @returns {Promise<bigint>} Number of rent payments
   */
  async getRentPaymentCount(assetId) {
    try {
      return await this.contract.getRentPaymentCount(assetId);
    } catch (error) {
      console.error(`Error getting rent payment count for assetId ${assetId}:`, error);
      throw error;
    }
  }

  /**
   * Get a specific rent payment
   * @param {number} assetId - Asset ID
   * @param {number} index - Payment index
   * @returns {Promise<Object>} Rent payment object
   */
  async getRentPayment(assetId, index) {
    try {
      return await this.contract.getRentPayment(assetId, index);
    } catch (error) {
      console.error(`Error getting rent payment for assetId ${assetId}, index ${index}:`, error);
      throw error;
    }
  }

  /**
   * Calculate owner share for a rent payment
   * @param {number} assetId - Asset ID
   * @param {string} owner - Owner address
   * @param {string} rentAmount - Rent amount in ETH (as string)
   * @returns {Promise<bigint>} Owner share (in wei)
   */
  async calculateOwnerShare(assetId, owner, rentAmount) {
    try {
      const amount = ethers.parseEther(rentAmount);
      return await this.contract.calculateOwnerShare(assetId, owner, amount);
    } catch (error) {
      console.error(`Error calculating owner share for assetId ${assetId}, owner ${owner}:`, error);
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
      RentalManagerABI,
      web3Service.getProvider()
    );
  }
}

export default new RentalManagerContract();


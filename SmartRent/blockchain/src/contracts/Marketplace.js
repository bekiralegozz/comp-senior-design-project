import { ethers } from 'ethers';
import web3Service from '../services/web3.js';
import config from '../config/config.js';
import MarketplaceABI from '../../abis/Marketplace.json' assert { type: 'json' };

/**
 * Marketplace Contract Wrapper
 * Handles buying and selling of fractional ownership shares
 */
class MarketplaceContract {
  constructor() {
    this.address = config.contracts.marketplace;
    this.contract = new ethers.Contract(
      this.address,
      MarketplaceABI,
      web3Service.getWallet()
    );
  }

  /**
   * Buy shares from a seller
   * @param {number} tokenId - Token ID (asset ID)
   * @param {string} seller - Seller address
   * @param {number} shareAmount - Amount of shares to buy
   * @param {string} ethAmount - ETH amount to pay (as string, e.g., "0.1")
   * @returns {Promise<ethers.ContractTransactionResponse>}
   */
  async buyShare(tokenId, seller, shareAmount, ethAmount) {
    try {
      const value = ethers.parseEther(ethAmount);
      const tx = await this.contract.buyShare(tokenId, seller, shareAmount, { value });
      return tx;
    } catch (error) {
      console.error(`Error buying share for tokenId ${tokenId}:`, error);
      throw error;
    }
  }

  /**
   * Get platform fee in basis points
   * @returns {Promise<bigint>} Platform fee (e.g., 250 = 2.5%)
   */
  async getPlatformFee() {
    try {
      return await this.contract.platformFeeBps();
    } catch (error) {
      console.error('Error getting platform fee:', error);
      throw error;
    }
  }

  /**
   * Get fee recipient address
   * @returns {Promise<string>} Fee recipient address
   */
  async getFeeRecipient() {
    try {
      return await this.contract.feeRecipient();
    } catch (error) {
      console.error('Error getting fee recipient:', error);
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
      MarketplaceABI,
      web3Service.getProvider()
    );
  }
}

export default new MarketplaceContract();


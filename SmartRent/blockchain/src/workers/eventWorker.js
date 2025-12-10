import { ethers } from 'ethers';
import database from '../services/database.js';
import building1122 from '../contracts/Building1122.js';
import rentalManager from '../contracts/RentalManager.js';
import marketplace from '../contracts/Marketplace.js';

/**
 * Event Worker - Event-Only Mode
 * Listens to contract events and syncs data to database
 * 
 * NOTE: This worker only listens to events, does NOT send transactions.
 * Database is kept in sync with blockchain as the source of truth.
 */
class EventWorker {
  constructor() {
    this.isRunning = false;
    this.listeners = [];
  }

  /**
   * Start the event worker
   */
  start() {
    if (this.isRunning) {
      console.log('⚠️ Event worker is already running');
      return;
    }

    this.isRunning = true;
    console.log('👂 Event worker started - listening to contract events');

    this.setupEventListeners();
  }

  /**
   * Stop the event worker
   */
  stop() {
    if (!this.isRunning) {
      return;
    }

    this.isRunning = false;
    // Remove all listeners
    this.listeners.forEach(listener => {
      listener.removeAllListeners();
    });
    this.listeners = [];
    console.log('🛑 Event worker stopped');
  }

  /**
   * Setup event listeners for all contracts
   */
  setupEventListeners() {
    // RentalManager events
    const rentalManagerContract = rentalManager.getContractForEvents();
    
    // Listen to RentPaid event
    rentalManagerContract.on('RentPaid', async (assetId, payer, amount, timestamp, event) => {
      try {
        console.log(`\n💰 RentPaid event received:`);
        console.log(`  Asset ID: ${assetId}`);
        console.log(`  Payer: ${payer}`);
        console.log(`  Amount: ${ethers.formatEther(amount)} ETH`);
        console.log(`  Timestamp: ${timestamp}`);
        console.log(`  TX Hash: ${event.transactionHash}`);

        // Sync rent payment to database
        await database.insertRentPayment({
          assetId: Number(assetId),
          payer: payer,
          amount: ethers.formatEther(amount),
          timestamp: Number(timestamp),
          txHash: event.transactionHash,
        });

        console.log('✅ Rent payment synced to database');
      } catch (error) {
        console.error('Error handling RentPaid event:', error);
      }
    });

    this.listeners.push(rentalManagerContract);

    // Marketplace events
    const marketplaceContract = marketplace.getContractForEvents();
    
    // Listen to ShareTraded event
    marketplaceContract.on('ShareTraded', async (tokenId, buyer, seller, shareAmount, ethAmount, timestamp, event) => {
      try {
        console.log(`\n🔄 ShareTraded event received:`);
        console.log(`  Token ID: ${tokenId}`);
        console.log(`  Buyer: ${buyer}`);
        console.log(`  Seller: ${seller}`);
        console.log(`  Share Amount: ${shareAmount}`);
        console.log(`  ETH Amount: ${ethers.formatEther(ethAmount)} ETH`);
        console.log(`  TX Hash: ${event.transactionHash}`);

        // Update ownership for buyer
        await database.updateOwnership({
          assetId: Number(tokenId),
          owner: buyer,
          shareAmount: Number(shareAmount),
        });

        // Update ownership for seller (decrease)
        const sellerBalance = await building1122.balanceOf(seller, Number(tokenId));
        await database.updateOwnership({
          assetId: Number(tokenId),
          owner: seller,
          shareAmount: Number(sellerBalance),
        });

        console.log('✅ Share trade synced to database');
      } catch (error) {
        console.error('Error handling ShareTraded event:', error);
      }
    });

    this.listeners.push(marketplaceContract);

    // Building1122 events
    const building1122Contract = building1122.getContractForEvents();
    
    // Listen to TransferSingle event (ERC-1155 transfer)
    building1122Contract.on('TransferSingle', async (operator, from, to, id, value, event) => {
      try {
        // Only log if it's not a mint (from != zero address) or burn (to != zero address)
        if (from !== ethers.ZeroAddress && to !== ethers.ZeroAddress) {
          console.log(`\n🔄 TransferSingle event received:`);
          console.log(`  Token ID: ${id}`);
          console.log(`  From: ${from}`);
          console.log(`  To: ${to}`);
          console.log(`  Amount: ${value}`);
          console.log(`  TX Hash: ${event.transactionHash}`);

          // Update ownership for both addresses
          const fromBalance = await building1122.balanceOf(from, Number(id));
          const toBalance = await building1122.balanceOf(to, Number(id));

          await database.updateOwnership({
            assetId: Number(id),
            owner: from,
            shareAmount: Number(fromBalance),
          });

          await database.updateOwnership({
            assetId: Number(id),
            owner: to,
            shareAmount: Number(toBalance),
          });
        }
      } catch (error) {
        console.error('Error handling TransferSingle event:', error);
      }
    });

    // Listen to AssetInitialized event
    building1122Contract.on('AssetInitialized', async (tokenId, initialOwner, totalSupply, metadataURI, event) => {
      try {
        console.log(`\n✨ AssetInitialized event received:`);
        console.log(`  Token ID: ${tokenId}`);
        console.log(`  Initial Owner: ${initialOwner}`);
        console.log(`  Total Supply: ${totalSupply}`);
        console.log(`  Metadata URI: ${metadataURI}`);
        console.log(`  TX Hash: ${event.transactionHash}`);

        // Sync asset initialization to database
        await database.updateOwnership({
          assetId: Number(tokenId),
          owner: initialOwner,
          shareAmount: Number(totalSupply),
        });

        console.log('✅ Asset initialization synced to database');
      } catch (error) {
        console.error('Error handling AssetInitialized event:', error);
      }
    });

    this.listeners.push(building1122Contract);

    console.log('✅ Event listeners setup complete');
  }
}

export default new EventWorker();


import { ethers } from 'ethers';
import database from './database.js';
import building1122 from '../contracts/Building1122.js';
import rentalManager from '../contracts/RentalManager.js';

/**
 * Sync Service
 * Syncs blockchain data to database (blockchain as source of truth)
 * 
 * Features:
 * - Initial sync: Pull all data from blockchain on startup
 * - Conflict resolution: Blockchain data always wins
 * - Historical event sync: Process past events
 */
class SyncService {
  constructor() {
    this.isSyncing = false;
  }

  /**
   * Perform initial sync from blockchain to database
   * This should be run when starting the server or after a long downtime
   * 
   * @param {number} fromBlock - Starting block number (0 = genesis)
   * @param {string|number} toBlock - Ending block ('latest' or block number)
   */
  async initialSync(fromBlock = 0, toBlock = 'latest') {
    if (this.isSyncing) {
      console.log('⚠️  Sync already in progress');
      return;
    }

    this.isSyncing = true;
    console.log('\n╔════════════════════════════════════════════════════════╗');
    console.log('║          Starting Initial Blockchain Sync           ║');
    console.log('╚════════════════════════════════════════════════════════╝\n');
    console.log(`📊 Syncing from block ${fromBlock} to ${toBlock}...\n`);

    try {
      // Sync asset initializations
      await this.syncAssetInitializations(fromBlock, toBlock);
      
      // Sync rent payments
      await this.syncRentPayments(fromBlock, toBlock);
      
      // Sync share trades
      await this.syncShareTrades(fromBlock, toBlock);
      
      // Sync ownership transfers
      await this.syncOwnershipTransfers(fromBlock, toBlock);

      console.log('\n✅ Initial sync completed successfully!');
    } catch (error) {
      console.error('❌ Error during initial sync:', error);
      throw error;
    } finally {
      this.isSyncing = false;
    }
  }

  /**
   * Sync AssetInitialized events
   */
  async syncAssetInitializations(fromBlock, toBlock) {
    console.log('🏠 Syncing asset initializations...');
    
    try {
      const contract = building1122.getContractForEvents();
      const filter = contract.filters.AssetInitialized();
      const events = await contract.queryFilter(filter, fromBlock, toBlock);

      console.log(`   Found ${events.length} asset initialization(s)`);

      for (const event of events) {
        const { tokenId, initialOwner, totalSupply, metadataURI } = event.args;
        
        console.log(`   • Token ${tokenId}: ${initialOwner} (${totalSupply} shares)`);
        
        // Update ownership in database
        await database.updateOwnership({
          assetId: Number(tokenId),
          owner: initialOwner,
          shareAmount: Number(totalSupply),
        });
      }

      console.log('   ✅ Asset initializations synced\n');
    } catch (error) {
      console.error('   ❌ Error syncing asset initializations:', error);
      throw error;
    }
  }

  /**
   * Sync RentPaid events
   */
  async syncRentPayments(fromBlock, toBlock) {
    console.log('💰 Syncing rent payments...');
    
    try {
      const contract = rentalManager.getContractForEvents();
      const filter = contract.filters.RentPaid();
      const events = await contract.queryFilter(filter, fromBlock, toBlock);

      console.log(`   Found ${events.length} rent payment(s)`);

      for (const event of events) {
        const { assetId, payer, amount, timestamp } = event.args;
        
        console.log(`   • Asset ${assetId}: ${ethers.formatEther(amount)} ETH from ${payer}`);
        
        // Insert rent payment into database
        await database.insertRentPayment({
          assetId: Number(assetId),
          payer: payer,
          amount: ethers.formatEther(amount),
          timestamp: Number(timestamp),
          txHash: event.transactionHash,
        });
      }

      console.log('   ✅ Rent payments synced\n');
    } catch (error) {
      console.error('   ❌ Error syncing rent payments:', error);
      throw error;
    }
  }

  /**
   * Sync ShareTraded events from Marketplace
   */
  async syncShareTrades(fromBlock, toBlock) {
    console.log('🔄 Syncing share trades...');
    
    try {
      const marketplace = await import('../contracts/Marketplace.js');
      const contract = marketplace.default.getContractForEvents();
      const filter = contract.filters.ShareTraded();
      const events = await contract.queryFilter(filter, fromBlock, toBlock);

      console.log(`   Found ${events.length} share trade(s)`);

      for (const event of events) {
        const { tokenId, buyer, seller, shareAmount, ethAmount } = event.args;
        
        console.log(`   • Token ${tokenId}: ${shareAmount} shares, ${buyer} ← ${seller}`);
        
        // Update ownership for both parties
        const buyerBalance = await building1122.balanceOf(buyer, Number(tokenId));
        const sellerBalance = await building1122.balanceOf(seller, Number(tokenId));

        await database.updateOwnership({
          assetId: Number(tokenId),
          owner: buyer,
          shareAmount: Number(buyerBalance),
        });

        await database.updateOwnership({
          assetId: Number(tokenId),
          owner: seller,
          shareAmount: Number(sellerBalance),
        });
      }

      console.log('   ✅ Share trades synced\n');
    } catch (error) {
      console.error('   ❌ Error syncing share trades:', error);
      throw error;
    }
  }

  /**
   * Sync TransferSingle events (ERC-1155 transfers)
   */
  async syncOwnershipTransfers(fromBlock, toBlock) {
    console.log('📦 Syncing ownership transfers...');
    
    try {
      const contract = building1122.getContractForEvents();
      const filter = contract.filters.TransferSingle();
      const events = await contract.queryFilter(filter, fromBlock, toBlock);

      // Filter out mints and burns (from/to zero address)
      const transfers = events.filter(e => 
        e.args.from !== ethers.ZeroAddress && 
        e.args.to !== ethers.ZeroAddress
      );

      console.log(`   Found ${transfers.length} transfer(s)`);

      for (const event of transfers) {
        const { from, to, id, value } = event.args;
        
        console.log(`   • Token ${id}: ${value} shares, ${to} ← ${from}`);
        
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

      console.log('   ✅ Ownership transfers synced\n');
    } catch (error) {
      console.error('   ❌ Error syncing ownership transfers:', error);
      throw error;
    }
  }

  /**
   * Sync specific asset ownership from blockchain to database
   * Useful for resolving conflicts
   * 
   * @param {number} tokenId - Asset token ID
   */
  async syncAssetOwnership(tokenId) {
    console.log(`\n🔄 Syncing ownership for token ${tokenId}...`);
    
    try {
      // Get all TransferSingle events for this token
      const contract = building1122.getContractForEvents();
      const filter = contract.filters.TransferSingle(null, null, null, tokenId);
      const events = await contract.queryFilter(filter, 0, 'latest');

      // Collect unique addresses
      const addresses = new Set();
      for (const event of events) {
        if (event.args.from !== ethers.ZeroAddress) {
          addresses.add(event.args.from);
        }
        if (event.args.to !== ethers.ZeroAddress) {
          addresses.add(event.args.to);
        }
      }

      console.log(`   Found ${addresses.size} owner(s) for token ${tokenId}`);

      // Sync each owner's balance
      for (const address of addresses) {
        const balance = await building1122.balanceOf(address, tokenId);
        
        if (Number(balance) > 0) {
          console.log(`   • ${address}: ${balance} shares`);
          
          await database.updateOwnership({
            assetId: tokenId,
            owner: address,
            shareAmount: Number(balance),
          });
        }
      }

      console.log('   ✅ Ownership synced');
    } catch (error) {
      console.error('   ❌ Error syncing asset ownership:', error);
      throw error;
    }
  }

  /**
   * Verify database consistency with blockchain
   * Compare database records with blockchain state
   * 
   * @returns {Object} Verification report
   */
  async verifyConsistency() {
    console.log('\n🔍 Verifying database consistency with blockchain...\n');
    
    const report = {
      assetsChecked: 0,
      inconsistencies: [],
      errors: [],
    };

    try {
      // Get all assets from database
      const dbAssets = await database.getAllAssets();
      
      for (const asset of dbAssets) {
        if (!asset.token_id) continue;
        
        report.assetsChecked++;
        
        try {
          // Check if token exists on blockchain
          const exists = await building1122.exists(asset.token_id);
          
          if (!exists) {
            report.inconsistencies.push({
              tokenId: asset.token_id,
              issue: 'Asset exists in database but not on blockchain',
            });
          }
          
          // Check total supply
          const blockchainSupply = await building1122.totalSupply(asset.token_id);
          const dbSupply = asset.total_supply || 0;
          
          if (Number(blockchainSupply) !== Number(dbSupply)) {
            report.inconsistencies.push({
              tokenId: asset.token_id,
              issue: 'Total supply mismatch',
              blockchain: Number(blockchainSupply),
              database: Number(dbSupply),
            });
          }
        } catch (error) {
          report.errors.push({
            tokenId: asset.token_id,
            error: error.message,
          });
        }
      }

      console.log(`✅ Consistency check complete:`);
      console.log(`   Assets checked: ${report.assetsChecked}`);
      console.log(`   Inconsistencies: ${report.inconsistencies.length}`);
      console.log(`   Errors: ${report.errors.length}\n`);

      if (report.inconsistencies.length > 0) {
        console.log('⚠️  Inconsistencies found:');
        report.inconsistencies.forEach(inc => {
          console.log(`   • Token ${inc.tokenId}: ${inc.issue}`);
        });
        console.log('\n');
      }

      return report;
    } catch (error) {
      console.error('❌ Error verifying consistency:', error);
      throw error;
    }
  }
}

export default new SyncService();


import { createClient } from '@supabase/supabase-js';
import config from '../config/config.js';

/**
 * Supabase Database Service
 * Handles all database operations for chain_actions and related tables
 */
class DatabaseService {
  constructor() {
    if (!config.supabase.url || !config.supabase.serviceRoleKey) {
      throw new Error('Supabase configuration is missing. Please check your .env file.');
    }

    this.client = createClient(config.supabase.url, config.supabase.serviceRoleKey);
  }

  /**
   * Get pending chain actions
   * @returns {Promise<Array>} Array of pending actions
   */
  async getPendingActions() {
    try {
      const { data, error } = await this.client
        .from('chain_actions')
        .select('*')
        .eq('status', 'PENDING')
        .order('created_at', { ascending: true });

      if (error) {
        console.error('Error fetching pending actions:', error);
        throw error;
      }

      return data || [];
    } catch (error) {
      console.error('Database error in getPendingActions:', error);
      throw error;
    }
  }

  /**
   * Update chain action status
   * @param {string} actionId - Action ID (UUID)
   * @param {string} status - New status (SENT, CONFIRMED, FAILED)
   * @param {string} txHash - Transaction hash (optional)
   * @param {string} errorMessage - Error message (optional, for FAILED status)
   */
  async updateActionStatus(actionId, status, txHash = null, errorMessage = null) {
    try {
      const updateData = {
        status,
        updated_at: new Date().toISOString(),
      };

      if (txHash) {
        updateData.tx_hash = txHash;
      }

      if (errorMessage) {
        updateData.error_message = errorMessage;
      }

      const { error } = await this.client
        .from('chain_actions')
        .update(updateData)
        .eq('id', actionId);

      if (error) {
        console.error('Error updating action status:', error);
        throw error;
      }

      console.log(`✅ Action ${actionId} updated to ${status}${txHash ? ` (tx: ${txHash})` : ''}`);
    } catch (error) {
      console.error('Database error in updateActionStatus:', error);
      throw error;
    }
  }

  /**
   * Insert rent payment record
   * @param {Object} rentData - Rent payment data
   */
  async insertRentPayment(rentData) {
    try {
      const { error } = await this.client
        .from('rentals')
        .insert({
          asset_id: rentData.assetId,
          payer: rentData.payer,
          amount: rentData.amount,
          timestamp: new Date(rentData.timestamp * 1000).toISOString(),
          tx_hash: rentData.txHash,
        });

      if (error) {
        console.error('Error inserting rent payment:', error);
        throw error;
      }

      console.log(`✅ Rent payment recorded for asset ${rentData.assetId}`);
    } catch (error) {
      console.error('Database error in insertRentPayment:', error);
      throw error;
    }
  }

  /**
   * Update ownership record
   * @param {Object} ownershipData - Ownership data
   */
  async updateOwnership(ownershipData) {
    try {
      // This will depend on your ownership table structure
      // Example implementation:
      const { error } = await this.client
        .from('ownerships')
        .upsert({
          asset_id: ownershipData.assetId,
          owner_address: ownershipData.owner,
          share_amount: ownershipData.shareAmount,
          updated_at: new Date().toISOString(),
        }, {
          onConflict: 'asset_id,owner_address',
        });

      if (error) {
        console.error('Error updating ownership:', error);
        throw error;
      }

      console.log(`✅ Ownership updated for asset ${ownershipData.assetId}, owner ${ownershipData.owner}`);
    } catch (error) {
      console.error('Database error in updateOwnership:', error);
      throw error;
    }
  }

  /**
   * Get action by transaction hash
   * @param {string} txHash - Transaction hash
   * @returns {Promise<Object|null>} Action object or null
   */
  async getActionByTxHash(txHash) {
    try {
      const { data, error } = await this.client
        .from('chain_actions')
        .select('*')
        .eq('tx_hash', txHash)
        .single();

      if (error) {
        if (error.code === 'PGRST116') {
          // No rows found
          return null;
        }
        throw error;
      }

      return data;
    } catch (error) {
      console.error('Database error in getActionByTxHash:', error);
      throw error;
    }
  }
}

// Export singleton instance
export default new DatabaseService();


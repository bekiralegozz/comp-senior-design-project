import eventWorker from './workers/eventWorker.js';
import syncService from './services/syncService.js';
import config from './config/config.js';

/**
 * SmartRent Blockchain Server - Event-Only Mode
 * Listens to blockchain events and syncs to database
 * 
 * NOTE: This server NO LONGER sends transactions.
 * All transactions are sent from mobile app via WalletConnect.
 */

console.log('╔═══════════════════════════════════════════════════════════╗');
console.log('║   SmartRent Blockchain Server - Event-Only Mode        ║');
console.log('║   📡 Listening to blockchain events...                  ║');
console.log('╚═══════════════════════════════════════════════════════════╝\n');

// Environment variable to control initial sync
const PERFORM_INITIAL_SYNC = process.env.INITIAL_SYNC === 'true';
const SYNC_FROM_BLOCK = parseInt(process.env.SYNC_FROM_BLOCK || '0', 10);

// Graceful shutdown
function setupGracefulShutdown() {
  const shutdown = async (signal) => {
    console.log(`\n\n${signal} received. Shutting down gracefully...`);
    
    eventWorker.stop();
    
    console.log('✅ Shutdown complete');
    process.exit(0);
  };

  process.on('SIGINT', () => shutdown('SIGINT'));
  process.on('SIGTERM', () => shutdown('SIGTERM'));
}

// Main function
async function main() {
  try {
    // Perform initial sync if enabled
    if (PERFORM_INITIAL_SYNC) {
      console.log('🔄 Initial sync enabled...');
      await syncService.initialSync(SYNC_FROM_BLOCK, 'latest');
    }

    // Start event worker (event-only mode)
    console.log('📡 Starting event worker...\n');
    eventWorker.start();

    console.log('\n✅ Blockchain Server is running in Event-Only Mode!');
    console.log('   🔍 Listening to contract events');
    console.log('   ⚠️  NO transactions will be sent from this server');
    console.log('   📱 Transactions are sent from mobile app via WalletConnect');
    console.log('   Press Ctrl+C to stop\n');

    // Optional: Verify consistency on startup
    if (process.env.VERIFY_CONSISTENCY === 'true') {
      console.log('🔍 Verifying database consistency...');
      await syncService.verifyConsistency();
    }

  } catch (error) {
    console.error('❌ Fatal error starting server:', error);
    process.exit(1);
  }
}

// Setup graceful shutdown
setupGracefulShutdown();

// Start the server
main();


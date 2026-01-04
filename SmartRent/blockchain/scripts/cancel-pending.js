import hre from "hardhat";

async function main() {
  console.log("🔥 Canceling Pending Transactions...\n");

  const [deployer] = await hre.ethers.getSigners();
  console.log("📍 Address:", deployer.address);
  
  const balance = await hre.ethers.provider.getBalance(deployer.address);
  console.log("💰 Balance:", hre.ethers.formatEther(balance), "POL\n");

  // Get current nonce (son kullanılan nonce)
  const currentNonce = await hre.ethers.provider.getTransactionCount(deployer.address, "latest");
  console.log("🔢 Current Nonce (latest):", currentNonce);
  
  // Get pending nonce (bekleyen transaction'ın nonce'u)
  const pendingNonce = await hre.ethers.provider.getTransactionCount(deployer.address, "pending");
  console.log("⏳ Pending Nonce:", pendingNonce);
  
  const pendingCount = pendingNonce - currentNonce;
  console.log("📊 Pending Transactions:", pendingCount, "\n");

  if (pendingCount === 0) {
    console.log("✅ No pending transactions!");
    return;
  }

  console.log("⚠️  Found", pendingCount, "pending transaction(s)");
  console.log("🔥 Sending replacement transactions to cancel them...\n");

  // Get current gas price
  const feeData = await hre.ethers.provider.getFeeData();
  const currentGasPrice = feeData.gasPrice;
  console.log("⛽ Current gas price:", hre.ethers.formatUnits(currentGasPrice, "gwei"), "gwei");
  
  // Use 150% of current gas price for replacement
  const replacementGasPrice = (currentGasPrice * 150n) / 100n;
  console.log("⛽ Replacement gas price:", hre.ethers.formatUnits(replacementGasPrice, "gwei"), "gwei\n");

  // Cancel each pending transaction
  for (let i = currentNonce; i < pendingNonce; i++) {
    try {
      console.log(`🔥 Canceling nonce ${i}...`);
      
      // Send 0 POL to yourself with higher gas price
      const tx = await deployer.sendTransaction({
        to: deployer.address,
        value: 0,
        nonce: i,
        gasLimit: 21000, // Minimum gas for transfer
        gasPrice: replacementGasPrice
      });
      
      console.log(`📤 Replacement TX: ${tx.hash}`);
      console.log(`⏳ Waiting for confirmation...`);
      
      await tx.wait(1);
      console.log(`✅ Nonce ${i} cancelled!\n`);
      
    } catch (error) {
      console.error(`❌ Failed to cancel nonce ${i}:`, error.message);
      if (error.message.includes("replacement fee too low")) {
        console.log("⚠️  Try increasing gas price manually\n");
      }
    }
  }

  console.log("🎉 All pending transactions processed!");
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error("❌ Error:", error);
    process.exit(1);
  });


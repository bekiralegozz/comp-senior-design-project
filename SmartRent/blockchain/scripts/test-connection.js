import hre from "hardhat";

async function main() {
  console.log("🔍 Testing Polygon connection...\n");

  const [deployer] = await hre.ethers.getSigners();
  console.log("📍 Address:", deployer.address);
  
  const balance = await hre.ethers.provider.getBalance(deployer.address);
  console.log("💰 Balance:", hre.ethers.formatEther(balance), "POL");
  
  const nonce = await hre.ethers.provider.getTransactionCount(deployer.address);
  console.log("🔢 Nonce:", nonce);
  
  const gasPrice = await hre.ethers.provider.getFeeData();
  console.log("⛽ Current gas price:", hre.ethers.formatUnits(gasPrice.gasPrice, "gwei"), "gwei");
  
  console.log("\n✅ Connection successful!");
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error("❌ Error:", error);
    process.exit(1);
  });


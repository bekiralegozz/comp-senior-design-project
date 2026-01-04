import hre from "hardhat";
import fs from "fs";
import path from "path";

async function main() {
  console.log("🚀 Deploying ONLY updated contracts (SmartRentHub + RentalHub)...\n");

  // Get deployer account
  const [deployer] = await hre.ethers.getSigners();
  console.log("📍 Deploying with account:", deployer.address);
  
  const balance = await hre.ethers.provider.getBalance(deployer.address);
  console.log("💰 Account balance:", hre.ethers.formatEther(balance), "POL\n");

  // Load existing addresses
  const addressesPath = path.join(process.cwd(), "deployment-addresses.json");
  let existingAddresses = {};
  
  if (fs.existsSync(addressesPath)) {
    existingAddresses = JSON.parse(fs.readFileSync(addressesPath, "utf8"));
    console.log("📋 Using existing Building1122:", existingAddresses.building1122);
    console.log("📋 Using existing RentalManager:", existingAddresses.rentalManager, "\n");
  }

  const building1122Address = existingAddresses.building1122 || "0x1179c6722cBEdB2bdF38FE1B3103edDa341523DC";
  const rentalManagerAddress = existingAddresses.rentalManager || "0xD10fcf5dC4188C688634865b6A89776b9ED57358";

  // ============================================
  // STEP 1: Deploy SmartRentHub (UPDATED)
  // ============================================
  console.log("📦 Deploying SmartRentHub contract...");
  const SmartRentHub = await hre.ethers.getContractFactory("SmartRentHub");
  console.log("🔨 Sending deployment transaction...");
  const smartRentHub = await SmartRentHub.deploy(
    deployer.address, // Initial owner
    deployer.address  // Fee recipient
  );
  console.log("⏳ Waiting for deployment confirmation...");
  console.log("Transaction hash:", smartRentHub.deploymentTransaction()?.hash);
  await smartRentHub.waitForDeployment();
  const smartRentHubAddress = await smartRentHub.getAddress();
  console.log("✅ SmartRentHub deployed to:", smartRentHubAddress, "\n");

  // ============================================
  // STEP 2: Configure SmartRentHub
  // ============================================
  console.log("⚙️  Configuring SmartRentHub...");
  await smartRentHub.setBuildingToken(building1122Address);
  console.log("✅ Building1122 token set\n");

  // ============================================
  // STEP 3: Deploy RentalHub (UPDATED)
  // ============================================
  console.log("📦 Deploying RentalHub contract...");
  const RentalHub = await hre.ethers.getContractFactory("RentalHub");
  console.log("🔨 Sending deployment transaction...");
  const rentalHub = await RentalHub.deploy(
    smartRentHubAddress,
    building1122Address,
    deployer.address // Fee recipient
  );
  console.log("⏳ Waiting for deployment confirmation...");
  console.log("Transaction hash:", rentalHub.deploymentTransaction()?.hash);
  await rentalHub.waitForDeployment();
  const rentalHubAddress = await rentalHub.getAddress();
  console.log("✅ RentalHub deployed to:", rentalHubAddress, "\n");

  // ============================================
  // STEP 4: Configure RentalHub
  // ============================================
  console.log("⚙️  Configuring RentalHub...");
  await rentalHub.setSmartRentHub(smartRentHubAddress);
  console.log("✅ SmartRentHub set in RentalHub\n");

  // ============================================
  // STEP 5: Set RentalHub in SmartRentHub
  // ============================================
  console.log("⚙️  Setting RentalHub in SmartRentHub...");
  await smartRentHub.setRentalHub(rentalHubAddress);
  console.log("✅ RentalHub set in SmartRentHub\n");

  // ============================================
  // Save Addresses
  // ============================================
  const deploymentInfo = {
    network: "polygon",
    deployer: deployer.address,
    timestamp: new Date().toISOString(),
    building1122: building1122Address,
    smartRentHub: smartRentHubAddress,
    rentalManager: rentalManagerAddress,
    rentalHub: rentalHubAddress
  };

  fs.writeFileSync(
    addressesPath,
    JSON.stringify(deploymentInfo, null, 2)
  );
  console.log("💾 Deployment addresses saved to deployment-addresses.json\n");

  // ============================================
  // Summary
  // ============================================
  console.log("🎉 Deployment Complete!\n");
  console.log("📋 Contract Addresses:");
  console.log("   Building1122 (REUSED):", building1122Address);
  console.log("   SmartRentHub (NEW):", smartRentHubAddress);
  console.log("   RentalManager (REUSED):", rentalManagerAddress);
  console.log("   RentalHub (NEW):", rentalHubAddress);
  console.log("\n⚠️  IMPORTANT: Update Building1122 to point to new SmartRentHub!");
  console.log("   Run: building1122.setSmartRentHub('" + smartRentHubAddress + "')");
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error("❌ Deployment failed:", error);
    process.exit(1);
  });


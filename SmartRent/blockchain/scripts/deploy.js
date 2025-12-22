import hre from "hardhat";

async function main() {
  console.log("🚀 Starting deployment to Polygon Mainnet...\n");

  // Get deployer account
  const [deployer] = await hre.ethers.getSigners();
  console.log("📍 Deploying with account:", deployer.address);
  
  const balance = await hre.ethers.provider.getBalance(deployer.address);
  console.log("💰 Account balance:", hre.ethers.formatEther(balance), "POL\n");

  // Check minimum balance (1 POL recommended)
  if (balance < hre.ethers.parseEther("1")) {
    console.warn("⚠️  Warning: Low balance. Recommended at least 1 POL for deployment");
  }

  // ============================================
  // STEP 1: Deploy SmartRentHub (Registry + Marketplace)
  // ============================================
  console.log("📦 Deploying SmartRentHub contract...");
  const SmartRentHub = await hre.ethers.getContractFactory("SmartRentHub");
  const smartRentHub = await SmartRentHub.deploy(
    deployer.address, // Initial owner
    deployer.address  // Fee recipient
  );
  await smartRentHub.waitForDeployment();
  const smartRentHubAddress = await smartRentHub.getAddress();
  
  console.log("✅ SmartRentHub deployed to:", smartRentHubAddress, "\n");

  // Wait for block confirmations
  console.log("⏳ Waiting for 5 block confirmations...");
  await smartRentHub.deploymentTransaction().wait(5);
  console.log("✅ Confirmed!\n");

  // ============================================
  // STEP 2: Deploy Building1122 (ERC-1155 Token)
  // ============================================
  console.log("📦 Deploying Building1122 contract...");
  const Building1122 = await hre.ethers.getContractFactory("Building1122");
  
  // Base URI will be updated later with IPFS, deployer is initial owner
  const building1122 = await Building1122.deploy("https://ipfs.io/ipfs/", deployer.address);
  await building1122.waitForDeployment();
  const building1122Address = await building1122.getAddress();
  
  console.log("✅ Building1122 deployed to:", building1122Address, "\n");

  // Wait for block confirmations
  console.log("⏳ Waiting for 5 block confirmations...");
  await building1122.deploymentTransaction().wait(5);
  console.log("✅ Confirmed!\n");

  // ============================================
  // STEP 3: Cross-reference Setup
  // ============================================
  console.log("🔗 Setting up cross-references...\n");

  // Set SmartRentHub address in Building1122
  console.log("   Setting SmartRentHub in Building1122...");
  const tx1 = await building1122.setSmartRentHub(smartRentHubAddress);
  await tx1.wait(2);
  console.log("   ✅ Done!\n");

  // Set Building1122 address in SmartRentHub
  console.log("   Setting Building1122 in SmartRentHub...");
  const tx2 = await smartRentHub.setBuildingToken(building1122Address);
  await tx2.wait(2);
  console.log("   ✅ Done!\n");

  // ============================================
  // STEP 4: Deploy RentalManager (For future use)
  // ============================================
  console.log("📦 Deploying RentalManager contract...");
  const RentalManager = await hre.ethers.getContractFactory("RentalManager");
  const rentalManager = await RentalManager.deploy(
    building1122Address,
    deployer.address // Initial owner
  );
  await rentalManager.waitForDeployment();
  const rentalManagerAddress = await rentalManager.getAddress();
  
  console.log("✅ RentalManager deployed to:", rentalManagerAddress, "\n");
  
  await rentalManager.deploymentTransaction().wait(5);

  // ============================================
  // Summary
  // ============================================
  console.log("🎉 Deployment Complete!\n");
  console.log("📋 Contract Addresses:");
  console.log("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");
  console.log("SmartRentHub:  ", smartRentHubAddress, " (Registry + Marketplace)");
  console.log("Building1122:  ", building1122Address, " (ERC-1155 Token)");
  console.log("RentalManager: ", rentalManagerAddress, " (Future: Rent Distribution)");
  console.log("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n");

  console.log("📝 Next Steps:");
  console.log("1. Save these addresses to your .env file");
  console.log("2. Verify contracts on PolygonScan");
  console.log("3. Update backend config with new addresses");
  console.log("4. Test: Mint → List → Buy flow\n");

  // Verification commands
  console.log("🔍 Verify on PolygonScan:");
  console.log(`npx hardhat verify --network polygon ${smartRentHubAddress} ${deployer.address} ${deployer.address}`);
  console.log(`npx hardhat verify --network polygon ${building1122Address} "https://ipfs.io/ipfs/" ${deployer.address}`);
  console.log(`npx hardhat verify --network polygon ${rentalManagerAddress} ${building1122Address} ${deployer.address}\n`);

  // Save addresses to file
  const fs = await import('fs');
  const addresses = {
    smartRentHub: smartRentHubAddress,
    building1122: building1122Address,
    rentalManager: rentalManagerAddress,
    deployer: deployer.address,
    network: "polygon",
    chainId: 137,
    deployedAt: new Date().toISOString(),
    crossReferences: {
      "Building1122.smartRentHub": smartRentHubAddress,
      "SmartRentHub.buildingToken": building1122Address
    }
  };
  
  fs.writeFileSync(
    'deployment-addresses.json',
    JSON.stringify(addresses, null, 2)
  );
  console.log("💾 Addresses saved to deployment-addresses.json");
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error("❌ Deployment failed:", error);
    process.exit(1);
  });

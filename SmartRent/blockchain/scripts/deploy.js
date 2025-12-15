import hre from "hardhat";

async function main() {
  console.log("🚀 Starting deployment to Polygon Mainnet...\n");

  // Get deployer account
  const [deployer] = await hre.ethers.getSigners();
  console.log("📍 Deploying with account:", deployer.address);
  
  const balance = await hre.ethers.provider.getBalance(deployer.address);
  console.log("💰 Account balance:", hre.ethers.formatEther(balance), "MATIC\n");

  // Check minimum balance (1 MATIC recommended)
  if (balance < hre.ethers.parseEther("1")) {
    console.warn("⚠️  Warning: Low balance. Recommended at least 1 MATIC for deployment");
  }

  // Deploy Building1122 (Main NFT Contract)
  console.log("📦 Deploying Building1122 contract...");
  const Building1122 = await hre.ethers.getContractFactory("Building1122");
  
  // Base URI will be updated later with IPFS, deployer is initial owner
  const building1122 = await Building1122.deploy("https://ipfs.io/ipfs/", deployer.address);
  await building1122.waitForDeployment();
  const building1122Address = await building1122.getAddress();
  
  console.log("✅ Building1122 deployed to:", building1122Address, "\n");

  // Wait for a few block confirmations
  console.log("⏳ Waiting for 5 block confirmations...");
  await building1122.deploymentTransaction().wait(5);
  console.log("✅ Confirmed!\n");

  // Deploy Marketplace
  console.log("📦 Deploying Marketplace contract...");
  const Marketplace = await hre.ethers.getContractFactory("Marketplace");
  const marketplace = await Marketplace.deploy(
    building1122Address,
    deployer.address, // Fee recipient
    deployer.address  // Initial owner
  );
  await marketplace.waitForDeployment();
  const marketplaceAddress = await marketplace.getAddress();
  
  console.log("✅ Marketplace deployed to:", marketplaceAddress, "\n");
  
  await marketplace.deploymentTransaction().wait(5);

  // Deploy RentalManager
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

  // Summary
  console.log("🎉 Deployment Complete!\n");
  console.log("📋 Contract Addresses:");
  console.log("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");
  console.log("Building1122:  ", building1122Address);
  console.log("Marketplace:   ", marketplaceAddress);
  console.log("RentalManager: ", rentalManagerAddress);
  console.log("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n");

  console.log("📝 Next Steps:");
  console.log("1. Save these addresses to your .env file");
  console.log("2. Verify contracts on PolygonScan");
  console.log("3. Set up IPFS metadata");
  console.log("4. Configure OpenSea collection\n");

  // Verification commands
  console.log("🔍 Verify on PolygonScan:");
  console.log(`npx hardhat verify --network polygon ${building1122Address} "https://ipfs.io/ipfs/" ${deployer.address}`);
  console.log(`npx hardhat verify --network polygon ${marketplaceAddress} ${building1122Address} ${deployer.address} ${deployer.address}`);
  console.log(`npx hardhat verify --network polygon ${rentalManagerAddress} ${building1122Address} ${deployer.address}\n`);

  // OpenSea links
  console.log("🌐 OpenSea Collection URL (after metadata setup):");
  console.log(`https://opensea.io/assets/matic/${building1122Address}`);
  
  // Save addresses to file
  const fs = await import('fs');
  const addresses = {
    building1122: building1122Address,
    marketplace: marketplaceAddress,
    rentalManager: rentalManagerAddress,
    deployer: deployer.address,
    network: "polygon",
    deployedAt: new Date().toISOString()
  };
  
  fs.writeFileSync(
    'deployment-addresses.json',
    JSON.stringify(addresses, null, 2)
  );
  console.log("\n💾 Addresses saved to deployment-addresses.json");
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error("❌ Deployment failed:", error);
    process.exit(1);
  });

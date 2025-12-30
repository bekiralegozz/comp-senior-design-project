import hre from "hardhat";
import fs from "fs";
import path from "path";

async function main() {
  console.log("🚀 Starting RentalHub deployment to Polygon Mainnet...\n");

  // Get deployer account
  const [deployer] = await hre.ethers.getSigners();
  console.log("📍 Deploying with account:", deployer.address);
  
  const balance = await hre.ethers.provider.getBalance(deployer.address);
  console.log("💰 Account balance:", hre.ethers.formatEther(balance), "POL\n");

  // Check minimum balance
  if (balance < hre.ethers.parseEther("0.5")) {
    console.warn("⚠️  Warning: Low balance. Recommended at least 0.5 POL for deployment");
  }

  // Load existing deployment addresses
  let existingAddresses = {};
  try {
    const addressesFile = fs.readFileSync('deployment-addresses.json', 'utf8');
    existingAddresses = JSON.parse(addressesFile);
    console.log("📂 Loaded existing deployment addresses");
    console.log("   SmartRentHub:", existingAddresses.smartRentHub);
    console.log("   Building1122:", existingAddresses.building1122);
    console.log("");
  } catch (err) {
    console.error("❌ Could not load deployment-addresses.json");
    console.error("   Please deploy SmartRentHub and Building1122 first!");
    process.exit(1);
  }

  // Verify required contracts are deployed
  if (!existingAddresses.smartRentHub || !existingAddresses.building1122) {
    console.error("❌ Missing contract addresses!");
    console.error("   SmartRentHub and Building1122 must be deployed first");
    process.exit(1);
  }

  // ============================================
  // STEP 1: Deploy RentalHub
  // ============================================
  console.log("📦 Deploying RentalHub contract...");
  console.log("   Fee recipient:", deployer.address);
  
  const RentalHub = await hre.ethers.getContractFactory("RentalHub");
  const rentalHub = await RentalHub.deploy(
    deployer.address, // Initial owner
    deployer.address  // Fee recipient
  );
  
  await rentalHub.waitForDeployment();
  const rentalHubAddress = await rentalHub.getAddress();
  
  console.log("✅ RentalHub deployed to:", rentalHubAddress);
  console.log("");

  // Wait for block confirmations
  console.log("⏳ Waiting for 5 block confirmations...");
  await rentalHub.deploymentTransaction().wait(5);
  console.log("✅ Confirmed!\n");

  // ============================================
  // STEP 2: Configure RentalHub
  // ============================================
  console.log("🔧 Configuring RentalHub...\n");

  // Set Building1122 address
  console.log("   Setting Building1122 address...");
  const tx1 = await rentalHub.setBuildingToken(existingAddresses.building1122);
  await tx1.wait(2);
  console.log("   ✅ Building1122 set to:", existingAddresses.building1122);
  console.log("");

  // Set SmartRentHub address
  console.log("   Setting SmartRentHub address...");
  const tx2 = await rentalHub.setSmartRentHub(existingAddresses.smartRentHub);
  await tx2.wait(2);
  console.log("   ✅ SmartRentHub set to:", existingAddresses.smartRentHub);
  console.log("");

  // Set platform fee (2.5% = 250 basis points)
  console.log("   Setting platform fee to 2.5%...");
  const tx3 = await rentalHub.setPlatformFee(250);
  await tx3.wait(2);
  console.log("   ✅ Platform fee set!\n");

  // ============================================
  // STEP 3: Generate ABI file
  // ============================================
  console.log("📄 Generating ABI file...");
  
  const abiDir = path.join(process.cwd(), 'abis');
  if (!fs.existsSync(abiDir)) {
    fs.mkdirSync(abiDir, { recursive: true });
  }

  // Load compiled artifact
  const artifact = await hre.artifacts.readArtifact("RentalHub");
  
  // Save ABI
  fs.writeFileSync(
    path.join(abiDir, 'RentalHub.json'),
    JSON.stringify(artifact.abi, null, 2)
  );
  
  console.log("✅ ABI saved to abis/RentalHub.json\n");

  // ============================================
  // STEP 4: Update deployment addresses
  // ============================================
  console.log("💾 Updating deployment-addresses.json...");
  
  const updatedAddresses = {
    ...existingAddresses,
    rentalHub: rentalHubAddress,
    rentalHubDeployedAt: new Date().toISOString(),
    crossReferences: {
      ...existingAddresses.crossReferences,
      "RentalHub.buildingToken": existingAddresses.building1122,
      "RentalHub.smartRentHub": existingAddresses.smartRentHub
    }
  };
  
  fs.writeFileSync(
    'deployment-addresses.json',
    JSON.stringify(updatedAddresses, null, 2)
  );
  
  console.log("✅ Addresses updated!\n");

  // ============================================
  // Summary
  // ============================================
  console.log("🎉 RentalHub Deployment Complete!\n");
  console.log("📋 All Contract Addresses:");
  console.log("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");
  console.log("SmartRentHub:  ", existingAddresses.smartRentHub);
  console.log("Building1122:  ", existingAddresses.building1122);
  console.log("RentalManager: ", existingAddresses.rentalManager || "N/A");
  console.log("RentalHub:     ", rentalHubAddress, " ⭐ NEW!");
  console.log("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n");

  console.log("📝 Next Steps:");
  console.log("1. Update backend .env file:");
  console.log(`   RENTAL_HUB_CONTRACT_ADDRESS=${rentalHubAddress}`);
  console.log("");
  console.log("2. Verify contract on PolygonScan:");
  console.log(`   npx hardhat verify --network polygon ${rentalHubAddress} ${deployer.address} ${deployer.address}`);
  console.log("");
  console.log("3. Test rental flow:");
  console.log("   - Create rental listing (majority shareholder)");
  console.log("   - Check dates availability");
  console.log("   - Book a rental");
  console.log("");

  // ============================================
  // Generate .env update template
  // ============================================
  console.log("📋 Add this to backend/.env:");
  console.log("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");
  console.log(`RENTAL_HUB_CONTRACT_ADDRESS=${rentalHubAddress}`);
  console.log("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n");

  // Test connectivity
  console.log("🧪 Testing contract connectivity...");
  try {
    const activeListingsCount = await rentalHub.getActiveRentalListingsCount();
    console.log("✅ Contract is responsive!");
    console.log("   Active listings:", activeListingsCount.toString());
    console.log("");
  } catch (err) {
    console.error("⚠️  Warning: Could not test contract:", err.message);
  }

  console.log("✨ Deployment successful! Happy renting! 🏠\n");
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error("❌ Deployment failed:", error);
    process.exit(1);
  });


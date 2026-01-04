import hre from "hardhat";
import fs from "fs";
import path from "path";

async function main() {
  console.log("🚀 Fast Deployment (SmartRentHub + RentalHub)...\n");

  const [deployer] = await hre.ethers.getSigners();
  console.log("📍 Deployer:", deployer.address);
  
  const balance = await hre.ethers.provider.getBalance(deployer.address);
  console.log("💰 Balance:", hre.ethers.formatEther(balance), "POL\n");

  // Use current contract addresses from backend .env (2026-01-03 deployment)
  const building1122Address = "0xd4f7c1D9979a6b1795C4E23fF9FD6b3De0ce3793"; // ✅ CURRENT
  const rentalManagerAddress = "0xD10fcf5dC4188C688634865b6A89776b9ED57358";

  try {
    // Deploy SmartRentHub
    console.log("📦 Deploying SmartRentHub...");
    const SmartRentHub = await hre.ethers.getContractFactory("SmartRentHub");
    const smartRentHub = await SmartRentHub.deploy(deployer.address, deployer.address);
    
    const smartRentHubTxHash = smartRentHub.deploymentTransaction()?.hash;
    console.log("📤 TX:", smartRentHubTxHash);
    console.log("⏳ Waiting for confirmation...");
    
    await smartRentHub.waitForDeployment();
    
    const smartRentHubAddress = await smartRentHub.getAddress();
    console.log("✅ SmartRentHub:", smartRentHubAddress, "\n");

    // Configure SmartRentHub
    console.log("⚙️  Configuring SmartRentHub...");
    const tx1 = await smartRentHub.setBuildingToken(building1122Address);
    console.log("📤 Config TX:", tx1.hash);
    await tx1.wait(1);
    console.log("✅ Config done\n");

    // Deploy RentalHub (OpenZeppelin Ownable pattern)
    console.log("📦 Deploying RentalHub...");
    const RentalHub = await hre.ethers.getContractFactory("RentalHub");
    const rentalHub = await RentalHub.deploy(
      deployer.address, // initialOwner
      deployer.address  // _feeRecipient
    );
    
    const rentalHubTxHash = rentalHub.deploymentTransaction()?.hash;
    console.log("📤 TX:", rentalHubTxHash);
    console.log("⏳ Waiting for confirmation...");
    
    await rentalHub.waitForDeployment();
    
    const rentalHubAddress = await rentalHub.getAddress();
    console.log("✅ RentalHub:", rentalHubAddress, "\n");

    // Configure RentalHub - Set SmartRentHub
    console.log("⚙️  Configuring RentalHub (SmartRentHub)...");
    const tx2 = await rentalHub.setSmartRentHub(smartRentHubAddress);
    console.log("📤 Config TX:", tx2.hash);
    await tx2.wait(1);
    console.log("✅ SmartRentHub set\n");
    
    // Configure RentalHub - Set Building1122
    console.log("⚙️  Configuring RentalHub (Building1122)...");
    const tx3 = await rentalHub.setBuildingToken(building1122Address);
    console.log("📤 Config TX:", tx3.hash);
    await tx3.wait(1);
    console.log("✅ Building1122 set\n");

    // Set RentalHub in SmartRentHub
    console.log("⚙️  Linking RentalHub to SmartRentHub...");
    const tx4 = await smartRentHub.setRentalHub(rentalHubAddress);
    console.log("📤 Link TX:", tx4.hash);
    await tx4.wait(1);
    console.log("✅ Link done\n");
    
    // Link SmartRentHub to Building1122 (CRITICAL for distribution!)
    console.log("⚙️  Linking SmartRentHub to Building1122...");
    const Building1122 = await hre.ethers.getContractAt("Building1122", building1122Address);
    const tx5 = await Building1122.setSmartRentHub(smartRentHubAddress);
    console.log("📤 Link TX:", tx5.hash);
    await tx5.wait(1);
    console.log("✅ Building1122 → SmartRentHub linked\n");

    // Save addresses
    const deploymentInfo = {
      network: "polygon",
      deployer: deployer.address,
      timestamp: new Date().toISOString(),
      building1122: building1122Address,
      smartRentHub: smartRentHubAddress,
      rentalManager: rentalManagerAddress,
      rentalHub: rentalHubAddress
    };

    const addressesPath = path.join(process.cwd(), "deployment-addresses.json");
    fs.writeFileSync(addressesPath, JSON.stringify(deploymentInfo, null, 2));
    console.log("💾 Saved to deployment-addresses.json\n");

    // Copy ABIs
    console.log("📄 Copying ABIs...");
    const artifactsDir = path.join(process.cwd(), "artifacts", "contracts");
    
    const smartRentHubAbi = JSON.parse(
      fs.readFileSync(path.join(artifactsDir, "SmartRentHub.sol", "SmartRentHub.json"))
    ).abi;
    
    const rentalHubAbi = JSON.parse(
      fs.readFileSync(path.join(artifactsDir, "RentalHub.sol", "RentalHub.json"))
    ).abi;

    fs.writeFileSync(
      path.join(process.cwd(), "abi", "SmartRentHub.json"),
      JSON.stringify(smartRentHubAbi, null, 2)
    );
    
    fs.writeFileSync(
      path.join(process.cwd(), "abi", "RentalHub.json"),
      JSON.stringify(rentalHubAbi, null, 2)
    );
    
    console.log("✅ ABIs copied to abi/\n");

    // Summary
    console.log("🎉 DEPLOYMENT COMPLETE!\n");
    console.log("📋 Addresses:");
    console.log("   SmartRentHub:", smartRentHubAddress);
    console.log("   RentalHub:", rentalHubAddress);
    console.log("   Building1122:", building1122Address);
    console.log("   RentalManager:", rentalManagerAddress);
    console.log("\n✅ All contract links configured!");
    console.log("   - SmartRentHub ↔ Building1122");
    console.log("   - SmartRentHub ↔ RentalHub");
    console.log("   - RentalHub → Building1122");
    console.log("\n📝 NEXT STEPS:");
    console.log("   1. Update backend .env with new addresses");
    console.log("   2. Update mobile config.dart with new addresses");
    console.log("   3. Copy ABIs to backend and mobile");
    console.log("   4. Restart backend");
    console.log("   5. Hot restart Flutter app");

  } catch (error) {
    console.error("\n❌ ERROR:", error.message);
    throw error;
  }
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error("❌ Failed:", error);
    process.exit(1);
  });


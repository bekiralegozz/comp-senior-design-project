import hre from "hardhat";
import fs from "fs";
import path from "path";

async function main() {
  console.log("🚀 Deploying NEW Building1122 + Linking Everything...\n");

  const [deployer] = await hre.ethers.getSigners();
  console.log("📍 Deployer:", deployer.address);
  
  const balance = await hre.ethers.provider.getBalance(deployer.address);
  console.log("💰 Balance:", hre.ethers.formatEther(balance), "POL\n");

  // Existing addresses (will be updated)
  const smartRentHubAddress = "0xa5F12C3c5A43fdEfcAff190DcAb057144897df8d";
  const rentalHubAddress = "0xbC549BD4a892aDfAa42399E8cD22D3574f113B5a";
  const rentalManagerAddress = "0xD10fcf5dC4188C688634865b6A89776b9ED57358";

  try {
    // 1. Deploy NEW Building1122
    console.log("📦 Deploying NEW Building1122...");
    const Building1122 = await hre.ethers.getContractFactory("Building1122");
    const building1122 = await Building1122.deploy(deployer.address, deployer.address);
    
    console.log("📤 TX:", building1122.deploymentTransaction()?.hash);
    console.log("⏳ Waiting for confirmation...");
    
    await building1122.waitForDeployment();
    
    const building1122Address = await building1122.getAddress();
    console.log("✅ NEW Building1122:", building1122Address, "\n");

    // 2. Set SmartRentHub in Building1122
    console.log("⚙️  Linking Building1122 → SmartRentHub...");
    const tx1 = await building1122.setSmartRentHub(smartRentHubAddress);
    console.log("📤 TX:", tx1.hash);
    await tx1.wait(2);
    console.log("✅ Done\n");

    // 3. Set Building1122 in SmartRentHub
    console.log("⚙️  Linking SmartRentHub → Building1122...");
    const SmartRentHub = await hre.ethers.getContractFactory("SmartRentHub");
    const smartRentHub = SmartRentHub.attach(smartRentHubAddress);
    const tx2 = await smartRentHub.setBuildingToken(building1122Address);
    console.log("📤 TX:", tx2.hash);
    await tx2.wait(2);
    console.log("✅ Done\n");

    // 4. Set Building1122 in RentalHub
    console.log("⚙️  Linking RentalHub → Building1122...");
    const RentalHub = await hre.ethers.getContractFactory("RentalHub");
    const rentalHub = RentalHub.attach(rentalHubAddress);
    const tx3 = await rentalHub.setBuildingToken(building1122Address);
    console.log("📤 TX:", tx3.hash);
    await tx3.wait(2);
    console.log("✅ Done\n");

    // 5. Save addresses
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

    // 6. Copy ABI
    console.log("📄 Copying Building1122 ABI...");
    const artifactsDir = path.join(process.cwd(), "artifacts", "contracts");
    const building1122Abi = JSON.parse(
      fs.readFileSync(path.join(artifactsDir, "Building1122.sol", "Building1122.json"))
    ).abi;
    
    fs.writeFileSync(
      path.join(process.cwd(), "abi", "Building1122.json"),
      JSON.stringify(building1122Abi, null, 2)
    );
    fs.writeFileSync(
      path.join(process.cwd(), "abis", "Building1122.json"),
      JSON.stringify(building1122Abi, null, 2)
    );
    console.log("✅ ABIs copied\n");

    // Summary
    console.log("🎉 DEPLOYMENT COMPLETE!\n");
    console.log("📋 Updated Contract Addresses:");
    console.log("   Building1122 (NEW):", building1122Address);
    console.log("   SmartRentHub:", smartRentHubAddress);
    console.log("   RentalHub:", rentalHubAddress);
    console.log("   RentalManager:", rentalManagerAddress);
    console.log("\n📝 Next Steps:");
    console.log("   1. Update backend/.env with NEW Building1122 address");
    console.log("   2. Update mobile/lib/constants/config.dart");
    console.log("   3. Restart backend");
    console.log("   4. Hot restart Flutter");
    console.log("   5. Mint NEW NFTs - they will appear immediately!");

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


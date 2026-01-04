import hre from "hardhat";
import fs from "fs";
import path from "path";

async function main() {
  console.log("🚀 Deploying ONLY RentalHub (SmartRentHub already deployed)...\n");

  const [deployer] = await hre.ethers.getSigners();
  console.log("📍 Deployer:", deployer.address);
  
  const balance = await hre.ethers.provider.getBalance(deployer.address);
  console.log("💰 Balance:", hre.ethers.formatEther(balance), "POL\n");

  // Existing addresses
  const smartRentHubAddress = "0xa5F12C3c5A43fdEfcAff190DcAb057144897df8d"; // NEWLY DEPLOYED!
  const building1122Address = "0x1179c6722cBEdB2bdF38FE1B3103edDa341523DC";
  const rentalManagerAddress = "0xD10fcf5dC4188C688634865b6A89776b9ED57358";

  console.log("✅ Using existing SmartRentHub:", smartRentHubAddress, "\n");

  try {
    // Deploy RentalHub
    console.log("📦 Deploying RentalHub...");
    const RentalHub = await hre.ethers.getContractFactory("RentalHub");
    const rentalHub = await RentalHub.deploy(
      deployer.address, // initialOwner
      deployer.address  // _feeRecipient
    );
    
    console.log("📤 TX:", rentalHub.deploymentTransaction()?.hash);
    console.log("⏳ Waiting for confirmation...");
    
    await rentalHub.waitForDeployment();
    
    const rentalHubAddress = await rentalHub.getAddress();
    console.log("✅ RentalHub:", rentalHubAddress, "\n");

    // Configure RentalHub - Set SmartRentHub
    console.log("⚙️  Setting SmartRentHub...");
    const tx1 = await rentalHub.setSmartRentHub(smartRentHubAddress);
    console.log("📤 TX:", tx1.hash);
    await tx1.wait(2);
    console.log("✅ Done\n");
    
    // Configure RentalHub - Set Building1122
    console.log("⚙️  Setting Building1122...");
    const tx2 = await rentalHub.setBuildingToken(building1122Address);
    console.log("📤 TX:", tx2.hash);
    await tx2.wait(2);
    console.log("✅ Done\n");

    // Link RentalHub to SmartRentHub
    console.log("⚙️  Linking RentalHub to SmartRentHub...");
    const SmartRentHub = await hre.ethers.getContractFactory("SmartRentHub");
    const smartRentHub = SmartRentHub.attach(smartRentHubAddress);
    
    const tx3 = await smartRentHub.setRentalHub(rentalHubAddress);
    console.log("📤 TX:", tx3.hash);
    await tx3.wait(2);
    console.log("✅ Done\n");

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
    
    console.log("✅ ABIs copied\n");

    // Summary
    console.log("🎉 DEPLOYMENT COMPLETE!\n");
    console.log("📋 Contract Addresses:");
    console.log("   SmartRentHub:", smartRentHubAddress);
    console.log("   RentalHub:", rentalHubAddress);
    console.log("   Building1122:", building1122Address);
    console.log("   RentalManager:", rentalManagerAddress);

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


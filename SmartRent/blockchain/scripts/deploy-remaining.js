import hre from "hardhat";
import fs from "fs";
import path from "path";
import dotenv from "dotenv";

// Load environment variables
dotenv.config();

/**
 * CONTINUE DEPLOYMENT - SmartRentHub + RentalHub
 * Building1122 already deployed: 0xC1BaB914b2ad7762E9174c7BD76cf48884F48B9c
 */

async function main() {
  console.log("🚀 CONTINUING DEPLOYMENT - SmartRentHub + RentalHub\n");
  console.log("=" .repeat(70));
  
  const networkName = hre.network.name;
  console.log("\n🌐 Network:", networkName);
  console.log("🔗 Chain ID:", hre.network.config.chainId);
  console.log("");

  const [deployer] = await hre.ethers.getSigners();
  console.log("📍 Deployer:", deployer.address);
  
  const balance = await hre.ethers.provider.getBalance(deployer.address);
  console.log("💰 Balance:", hre.ethers.formatEther(balance), "POL\n");

  // EXISTING Building1122 address (already deployed)
  const building1122Address = "0xC1BaB914b2ad7762E9174c7BD76cf48884F48B9c";
  console.log("✅ Building1122 (EXISTING):", building1122Address);
  console.log("");

  try {
    // ================================================================
    // STEP 1: Deploy SmartRentHub
    // ================================================================
    console.log("=" .repeat(70));
    console.log("STEP 1/3: Deploying SmartRentHub");
    console.log("=" .repeat(70) + "\n");
    
    const SmartRentHub = await hre.ethers.getContractFactory("SmartRentHub");
    console.log("📦 Deploying SmartRentHub...");
    
    const smartRentHub = await SmartRentHub.deploy(
      deployer.address, // initialOwner
      deployer.address  // feeRecipient
    );
    
    const hubTxHash = smartRentHub.deploymentTransaction()?.hash;
    console.log("📤 TX Hash:", hubTxHash);
    console.log("⏳ Waiting for confirmation...");
    
    await smartRentHub.waitForDeployment();
    const smartRentHubAddress = await smartRentHub.getAddress();
    
    console.log("✅ SmartRentHub deployed:", smartRentHubAddress);
    console.log("");
    
    // Link SmartRentHub → Building1122
    console.log("🔗 Linking SmartRentHub → Building1122...");
    const linkTx1 = await smartRentHub.setBuildingToken(building1122Address);
    console.log("📤 TX Hash:", linkTx1.hash);
    await linkTx1.wait(1);
    console.log("✅ SmartRentHub → Building1122 linked\n");

    // ================================================================
    // STEP 2: Deploy RentalHub
    // ================================================================
    console.log("=" .repeat(70));
    console.log("STEP 2/3: Deploying RentalHub");
    console.log("=" .repeat(70) + "\n");
    
    const RentalHub = await hre.ethers.getContractFactory("RentalHub");
    console.log("📦 Deploying RentalHub...");
    
    const rentalHub = await RentalHub.deploy(
      deployer.address, // initialOwner
      deployer.address  // feeRecipient
    );
    
    const rentalTxHash = rentalHub.deploymentTransaction()?.hash;
    console.log("📤 TX Hash:", rentalTxHash);
    console.log("⏳ Waiting for confirmation...");
    
    await rentalHub.waitForDeployment();
    const rentalHubAddress = await rentalHub.getAddress();
    
    console.log("✅ RentalHub deployed:", rentalHubAddress);
    console.log("");
    
    // Link RentalHub → SmartRentHub
    console.log("🔗 Linking RentalHub → SmartRentHub...");
    const linkTx2 = await rentalHub.setSmartRentHub(smartRentHubAddress);
    console.log("📤 TX Hash:", linkTx2.hash);
    await linkTx2.wait(1);
    console.log("✅ RentalHub → SmartRentHub linked\n");
    
    // Link RentalHub → Building1122
    console.log("🔗 Linking RentalHub → Building1122...");
    const linkTx3 = await rentalHub.setBuildingToken(building1122Address);
    console.log("📤 TX Hash:", linkTx3.hash);
    await linkTx3.wait(1);
    console.log("✅ RentalHub → Building1122 linked\n");

    // ================================================================
    // STEP 3: Cross-Link ALL
    // ================================================================
    console.log("=" .repeat(70));
    console.log("STEP 3/3: Cross-Linking All Contracts");
    console.log("=" .repeat(70) + "\n");
    
    // SmartRentHub → RentalHub
    console.log("🔗 Linking SmartRentHub → RentalHub...");
    const linkTx4 = await smartRentHub.setRentalHub(rentalHubAddress);
    console.log("📤 TX Hash:", linkTx4.hash);
    await linkTx4.wait(1);
    console.log("✅ SmartRentHub → RentalHub linked\n");
    
    // Building1122 → SmartRentHub
    console.log("🔗 Linking Building1122 → SmartRentHub...");
    const Building1122 = await hre.ethers.getContractAt("Building1122", building1122Address);
    const linkTx5 = await Building1122.setSmartRentHub(smartRentHubAddress);
    console.log("📤 TX Hash:", linkTx5.hash);
    await linkTx5.wait(1);
    console.log("✅ Building1122 → SmartRentHub linked\n");

    // ================================================================
    // VERIFICATION
    // ================================================================
    console.log("=" .repeat(70));
    console.log("🔍 VERIFYING ALL LINKS");
    console.log("=" .repeat(70) + "\n");
    
    const building_to_hub = await Building1122.smartRentHub();
    const hub_to_building = await smartRentHub.buildingToken();
    const hub_to_rental = await smartRentHub.rentalHub();
    const rental_to_hub = await rentalHub.smartRentHub();
    const rental_to_building = await rentalHub.buildingToken();
    
    const allGood = 
      building_to_hub.toLowerCase() === smartRentHubAddress.toLowerCase() &&
      hub_to_building.toLowerCase() === building1122Address.toLowerCase() &&
      hub_to_rental.toLowerCase() === rentalHubAddress.toLowerCase() &&
      rental_to_hub.toLowerCase() === smartRentHubAddress.toLowerCase() &&
      rental_to_building.toLowerCase() === building1122Address.toLowerCase();
    
    console.log("1. Building1122 → SmartRentHub:", building_to_hub.toLowerCase() === smartRentHubAddress.toLowerCase() ? "✅" : "❌");
    console.log("2. SmartRentHub → Building1122:", hub_to_building.toLowerCase() === building1122Address.toLowerCase() ? "✅" : "❌");
    console.log("3. SmartRentHub → RentalHub:", hub_to_rental.toLowerCase() === rentalHubAddress.toLowerCase() ? "✅" : "❌");
    console.log("4. RentalHub → SmartRentHub:", rental_to_hub.toLowerCase() === smartRentHubAddress.toLowerCase() ? "✅" : "❌");
    console.log("5. RentalHub → Building1122:", rental_to_building.toLowerCase() === building1122Address.toLowerCase() ? "✅" : "❌");
    console.log("");

    if (!allGood) {
      throw new Error("Link verification failed!");
    }

    // ================================================================
    // SAVE DEPLOYMENT INFO
    // ================================================================
    console.log("=" .repeat(70));
    console.log("💾 SAVING DEPLOYMENT INFO");
    console.log("=" .repeat(70) + "\n");
    
    const deploymentInfo = {
      network: "polygon-mainnet",
      deployer: deployer.address,
      timestamp: new Date().toISOString(),
      contracts: {
        Building1122: building1122Address,
        SmartRentHub: smartRentHubAddress,
        RentalHub: rentalHubAddress
      }
    };

    const addressesPath = path.join(process.cwd(), "deployment-addresses.json");
    fs.writeFileSync(addressesPath, JSON.stringify(deploymentInfo, null, 2));
    console.log("✅ Saved to deployment-addresses.json\n");

    // ================================================================
    // COPY ABIs
    // ================================================================
    console.log("=" .repeat(70));
    console.log("📄 COPYING ABIs");
    console.log("=" .repeat(70) + "\n");
    
    const artifactsDir = path.join(process.cwd(), "artifacts", "contracts");
    const abisDir = path.join(process.cwd(), "abis");
    
    if (!fs.existsSync(abisDir)) {
      fs.mkdirSync(abisDir, { recursive: true });
    }
    
    // Copy all ABIs
    const contracts = ["Building1122", "SmartRentHub", "RentalHub"];
    for (const contractName of contracts) {
      const abiPath = path.join(artifactsDir, `${contractName}.sol`, `${contractName}.json`);
      const abi = JSON.parse(fs.readFileSync(abiPath)).abi;
      fs.writeFileSync(
        path.join(abisDir, `${contractName}.json`),
        JSON.stringify(abi, null, 2)
      );
      console.log(`✅ ${contractName}.json → abis/`);
    }
    console.log("");

    // ================================================================
    // SUMMARY
    // ================================================================
    console.log("=" .repeat(70));
    console.log("🎉 DEPLOYMENT COMPLETE!");
    console.log("=" .repeat(70) + "\n");
    
    console.log("📋 CONTRACT ADDRESSES:\n");
    console.log("   Building1122:  ", building1122Address);
    console.log("   SmartRentHub:  ", smartRentHubAddress);
    console.log("   RentalHub:     ", rentalHubAddress);
    console.log("\n🔗 ALL LINKS VERIFIED: ✅\n");
    
    console.log("📝 ADDRESSES FOR CONFIG FILES:\n");
    console.log("Backend .env:");
    console.log(`BUILDING1122_CONTRACT_ADDRESS=${building1122Address}`);
    console.log(`SMARTRENTHUB_CONTRACT_ADDRESS=${smartRentHubAddress}`);
    console.log(`RENTAL_HUB_CONTRACT_ADDRESS=${rentalHubAddress}`);
    console.log("");
    console.log("Mobile config.dart:");
    console.log(`building1122Contract = '${building1122Address}';`);
    console.log(`smartRentHubContract = '${smartRentHubAddress}';`);
    console.log(`rentalHubContract = '${rentalHubAddress}';`);
    console.log("");
    console.log("=" .repeat(70));

  } catch (error) {
    console.error("\n❌ DEPLOYMENT FAILED!");
    console.error("Error:", error.message);
    throw error;
  }
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error("❌ Fatal error:", error);
    process.exit(1);
  });


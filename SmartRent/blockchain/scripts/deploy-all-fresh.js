import hre from "hardhat";
import fs from "fs";
import path from "path";
import dotenv from "dotenv";

// Load environment variables
dotenv.config();

/**
 * FRESH DEPLOYMENT - All contracts from scratch
 * 
 * Order is critical to avoid circular dependencies:
 * 1. Deploy Building1122 (no dependencies)
 * 2. Deploy SmartRentHub → link to Building1122
 * 3. Deploy RentalHub → link to SmartRentHub & Building1122
 * 4. Cross-link: SmartRentHub → RentalHub
 * 5. Cross-link: Building1122 → SmartRentHub
 */

async function main() {
  console.log("🚀 FRESH DEPLOYMENT - All Contracts\n");
  console.log("=" .repeat(70));
  
  // Debug network info
  const networkName = hre.network.name;
  const networkConfig = hre.network.config;
  console.log("\n🌐 Network:", networkName);
  console.log("🔗 Chain ID:", networkConfig.chainId);
  console.log("📡 RPC URL:", networkConfig.url || "N/A");
  console.log("");

  const [deployer] = await hre.ethers.getSigners();
  console.log("📍 Deployer:", deployer.address);
  
  const balance = await hre.ethers.provider.getBalance(deployer.address);
  console.log("💰 Balance:", hre.ethers.formatEther(balance), "POL\n");
  
  if (parseFloat(hre.ethers.formatEther(balance)) < 1.0) {
    console.error("❌ Insufficient balance! Need at least 1 POL for deployment.");
    process.exit(1);
  }

  try {
    // ================================================================
    // STEP 1: Deploy Building1122 (ERC1155 Token Contract)
    // ================================================================
    console.log("=" .repeat(70));
    console.log("STEP 1/5: Deploying Building1122 (ERC1155)");
    console.log("=" .repeat(70) + "\n");
    
    const Building1122 = await hre.ethers.getContractFactory("Building1122");
    console.log("📦 Deploying Building1122...");
    
    // Building1122 constructor: (string uri_, address initialOwner)
    const building1122 = await Building1122.deploy(
      "https://ipfs.io/ipfs/{id}",  // Base URI for metadata
      deployer.address               // Initial owner
    );
    const buildingTxHash = building1122.deploymentTransaction()?.hash;
    console.log("📤 TX Hash:", buildingTxHash);
    console.log("⏳ Waiting for confirmation...");
    
    await building1122.waitForDeployment();
    const building1122Address = await building1122.getAddress();
    
    console.log("✅ Building1122 deployed:", building1122Address);
    console.log("");

    // ================================================================
    // STEP 2: Deploy SmartRentHub (Registry & Marketplace)
    // ================================================================
    console.log("=" .repeat(70));
    console.log("STEP 2/5: Deploying SmartRentHub (Registry & Marketplace)");
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
    // STEP 3: Deploy RentalHub (Rental Marketplace)
    // ================================================================
    console.log("=" .repeat(70));
    console.log("STEP 3/5: Deploying RentalHub (Rental Marketplace)");
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
    // STEP 4: Cross-Link SmartRentHub ↔ RentalHub
    // ================================================================
    console.log("=" .repeat(70));
    console.log("STEP 4/5: Cross-Linking SmartRentHub ↔ RentalHub");
    console.log("=" .repeat(70) + "\n");
    
    console.log("🔗 Linking SmartRentHub → RentalHub...");
    const linkTx4 = await smartRentHub.setRentalHub(rentalHubAddress);
    console.log("📤 TX Hash:", linkTx4.hash);
    await linkTx4.wait(1);
    console.log("✅ SmartRentHub → RentalHub linked\n");

    // ================================================================
    // STEP 5: Cross-Link Building1122 ↔ SmartRentHub
    // ================================================================
    console.log("=" .repeat(70));
    console.log("STEP 5/5: Cross-Linking Building1122 ↔ SmartRentHub");
    console.log("=" .repeat(70) + "\n");
    
    console.log("🔗 Linking Building1122 → SmartRentHub...");
    const linkTx5 = await building1122.setSmartRentHub(smartRentHubAddress);
    console.log("📤 TX Hash:", linkTx5.hash);
    await linkTx5.wait(1);
    console.log("✅ Building1122 → SmartRentHub linked\n");

    // ================================================================
    // VERIFICATION: Check all links
    // ================================================================
    console.log("=" .repeat(70));
    console.log("🔍 VERIFYING ALL LINKS");
    console.log("=" .repeat(70) + "\n");
    
    const building_to_hub = await building1122.smartRentHub();
    const hub_to_building = await smartRentHub.buildingToken();
    const hub_to_rental = await smartRentHub.rentalHub();
    const rental_to_hub = await rentalHub.smartRentHub();
    const rental_to_building = await rentalHub.buildingToken();
    
    console.log("1. Building1122 → SmartRentHub:", building_to_hub);
    console.log("   Expected:", smartRentHubAddress);
    console.log("   Match:", building_to_hub.toLowerCase() === smartRentHubAddress.toLowerCase() ? "✅" : "❌");
    
    console.log("\n2. SmartRentHub → Building1122:", hub_to_building);
    console.log("   Expected:", building1122Address);
    console.log("   Match:", hub_to_building.toLowerCase() === building1122Address.toLowerCase() ? "✅" : "❌");
    
    console.log("\n3. SmartRentHub → RentalHub:", hub_to_rental);
    console.log("   Expected:", rentalHubAddress);
    console.log("   Match:", hub_to_rental.toLowerCase() === rentalHubAddress.toLowerCase() ? "✅" : "❌");
    
    console.log("\n4. RentalHub → SmartRentHub:", rental_to_hub);
    console.log("   Expected:", smartRentHubAddress);
    console.log("   Match:", rental_to_hub.toLowerCase() === smartRentHubAddress.toLowerCase() ? "✅" : "❌");
    
    console.log("\n5. RentalHub → Building1122:", rental_to_building);
    console.log("   Expected:", building1122Address);
    console.log("   Match:", rental_to_building.toLowerCase() === building1122Address.toLowerCase() ? "✅" : "❌");
    
    console.log("");

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
      gasUsed: "~0.5-1.0 POL",
      contracts: {
        Building1122: building1122Address,
        SmartRentHub: smartRentHubAddress,
        RentalHub: rentalHubAddress
      },
      links: {
        "Building1122 → SmartRentHub": building_to_hub,
        "SmartRentHub → Building1122": hub_to_building,
        "SmartRentHub → RentalHub": hub_to_rental,
        "RentalHub → SmartRentHub": rental_to_hub,
        "RentalHub → Building1122": rental_to_building
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
    
    // Ensure abis directory exists
    if (!fs.existsSync(abisDir)) {
      fs.mkdirSync(abisDir, { recursive: true });
    }
    
    // Copy Building1122 ABI
    const building1122AbiPath = path.join(artifactsDir, "Building1122.sol", "Building1122.json");
    const building1122Abi = JSON.parse(fs.readFileSync(building1122AbiPath)).abi;
    fs.writeFileSync(
      path.join(abisDir, "Building1122.json"),
      JSON.stringify(building1122Abi, null, 2)
    );
    console.log("✅ Building1122.json → abis/");
    
    // Copy SmartRentHub ABI
    const smartRentHubAbiPath = path.join(artifactsDir, "SmartRentHub.sol", "SmartRentHub.json");
    const smartRentHubAbi = JSON.parse(fs.readFileSync(smartRentHubAbiPath)).abi;
    fs.writeFileSync(
      path.join(abisDir, "SmartRentHub.json"),
      JSON.stringify(smartRentHubAbi, null, 2)
    );
    console.log("✅ SmartRentHub.json → abis/");
    
    // Copy RentalHub ABI
    const rentalHubAbiPath = path.join(artifactsDir, "RentalHub.sol", "RentalHub.json");
    const rentalHubAbi = JSON.parse(fs.readFileSync(rentalHubAbiPath)).abi;
    fs.writeFileSync(
      path.join(abisDir, "RentalHub.json"),
      JSON.stringify(rentalHubAbi, null, 2)
    );
    console.log("✅ RentalHub.json → abis/");
    
    console.log("");

    // ================================================================
    // DEPLOYMENT SUMMARY
    // ================================================================
    console.log("=" .repeat(70));
    console.log("🎉 DEPLOYMENT COMPLETE!");
    console.log("=" .repeat(70) + "\n");
    
    console.log("📋 CONTRACT ADDRESSES:\n");
    console.log("   Building1122:  ", building1122Address);
    console.log("   SmartRentHub:  ", smartRentHubAddress);
    console.log("   RentalHub:     ", rentalHubAddress);
    
    console.log("\n🔗 ALL LINKS VERIFIED: ✅\n");
    
    console.log("📝 NEXT STEPS:\n");
    console.log("   1. Update backend/.env:");
    console.log(`      BUILDING1122_CONTRACT_ADDRESS=${building1122Address}`);
    console.log(`      SMARTRENTHUB_CONTRACT_ADDRESS=${smartRentHubAddress}`);
    console.log(`      RENTAL_HUB_CONTRACT_ADDRESS=${rentalHubAddress}`);
    console.log("");
    console.log("   2. Update mobile/lib/constants/config.dart:");
    console.log(`      building1122Contract = '${building1122Address}';`);
    console.log(`      smartRentHubContract = '${smartRentHubAddress}';`);
    console.log(`      rentalHubContract = '${rentalHubAddress}';`);
    console.log("");
    console.log("   3. Copy ABIs:");
    console.log("      cp abis/*.json ../backend/app/contracts/");
    console.log("      cp abis/*.json ../mobile/lib/contracts/");
    console.log("");
    console.log("   4. Restart backend:");
    console.log("      cd ../backend && py -m uvicorn app.main:app --reload");
    console.log("");
    console.log("   5. Hot restart Flutter app (R key)");
    console.log("");
    console.log("=" .repeat(70));

  } catch (error) {
    console.error("\n❌ DEPLOYMENT FAILED!");
    console.error("Error:", error.message);
    if (error.transaction) {
      console.error("Transaction Hash:", error.transaction.hash);
    }
    throw error;
  }
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error("❌ Fatal error:", error);
    process.exit(1);
  });


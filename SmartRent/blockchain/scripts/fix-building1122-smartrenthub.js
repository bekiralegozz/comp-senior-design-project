import hre from "hardhat";

async function main() {
  console.log("🔧 Fixing Building1122 → SmartRentHub Link...\n");

  const [deployer] = await hre.ethers.getSigners();
  console.log("📍 Deployer:", deployer.address);
  
  const balance = await hre.ethers.provider.getBalance(deployer.address);
  console.log("💰 Balance:", hre.ethers.formatEther(balance), "POL\n");

  // Addresses
  const building1122Address = "0x1179c6722cBEdB2bdF38FE1B3103edDa341523DC";
  const newSmartRentHubAddress = "0xa5F12C3c5A43fdEfcAff190DcAb057144897df8d";

  console.log("📝 Building1122:", building1122Address);
  console.log("📝 NEW SmartRentHub:", newSmartRentHubAddress, "\n");

  try {
    // Get Building1122 contract instance
    const Building1122 = await hre.ethers.getContractFactory("Building1122");
    const building1122 = Building1122.attach(building1122Address);

    // Check current smartRentHub address
    console.log("🔍 Checking current SmartRentHub address...");
    const currentSmartRentHub = await building1122.smartRentHub();
    console.log("   Current SmartRentHub:", currentSmartRentHub);
    
    if (currentSmartRentHub.toLowerCase() === newSmartRentHubAddress.toLowerCase()) {
      console.log("\n✅ SmartRentHub address is already correct!");
      return;
    }

    // Set new SmartRentHub address
    console.log("\n⚙️  Setting NEW SmartRentHub address...");
    const tx = await building1122.setSmartRentHub(newSmartRentHubAddress);
    console.log("📤 TX:", tx.hash);
    
    console.log("⏳ Waiting for confirmation...");
    await tx.wait(2);
    
    console.log("✅ SmartRentHub address updated!\n");

    // Verify
    const updatedSmartRentHub = await building1122.smartRentHub();
    console.log("🔍 Verification:");
    console.log("   New SmartRentHub:", updatedSmartRentHub);
    
    if (updatedSmartRentHub.toLowerCase() === newSmartRentHubAddress.toLowerCase()) {
      console.log("\n🎉 SUCCESS! Building1122 now points to NEW SmartRentHub!");
      console.log("\n📋 Next Steps:");
      console.log("   1. Try minting a NEW NFT");
      console.log("   2. It should appear in My NFTs immediately!");
    } else {
      console.log("\n❌ ERROR: Address mismatch!");
    }

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


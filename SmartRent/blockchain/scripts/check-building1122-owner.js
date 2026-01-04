import hre from "hardhat";

async function main() {
  console.log("🔍 Checking Building1122 Owner & SmartRentHub Link...\n");

  const [deployer] = await hre.ethers.getSigners();
  console.log("📍 Current Wallet:", deployer.address);
  
  const building1122Address = "0x1179c6722cBEdB2bdF38FE1B3103edDa341523DC";
  const newSmartRentHubAddress = "0xa5F12C3c5A43fdEfcAff190DcAb057144897df8d";

  try {
    const Building1122 = await hre.ethers.getContractFactory("Building1122");
    const building1122 = Building1122.attach(building1122Address);

    // Check owner
    console.log("🔑 Checking owner...");
    const owner = await building1122.owner();
    console.log("   Owner:", owner);
    console.log("   Current Wallet:", deployer.address);
    console.log("   Is Owner:", owner.toLowerCase() === deployer.address.toLowerCase(), "\n");

    // Check current smartRentHub
    console.log("🔗 Checking SmartRentHub link...");
    const currentSmartRentHub = await building1122.smartRentHub();
    console.log("   Current SmartRentHub:", currentSmartRentHub);
    console.log("   New SmartRentHub:", newSmartRentHubAddress);
    console.log("   Needs Update:", currentSmartRentHub.toLowerCase() !== newSmartRentHubAddress.toLowerCase(), "\n");

    // If we are owner and need update, try to update
    if (owner.toLowerCase() === deployer.address.toLowerCase()) {
      if (currentSmartRentHub.toLowerCase() !== newSmartRentHubAddress.toLowerCase()) {
        console.log("✅ We are owner! Updating SmartRentHub address...");
        const tx = await building1122.setSmartRentHub(newSmartRentHubAddress);
        console.log("📤 TX:", tx.hash);
        await tx.wait(2);
        console.log("✅ SmartRentHub updated!\n");
      } else {
        console.log("✅ SmartRentHub already correct!\n");
      }
    } else {
      console.log("❌ We are NOT the owner. Cannot update SmartRentHub.");
      console.log("\n🚨 PROBLEM: Building1122 is pointing to OLD SmartRentHub!");
      console.log("   This means new NFT mints will NOT be registered in NEW SmartRentHub.");
      console.log("\n💡 SOLUTION OPTIONS:");
      console.log("   1. Get the old wallet's private key and transfer ownership");
      console.log("   2. Deploy a NEW Building1122 contract (clean start)");
      console.log("   3. Manually register NFTs after minting\n");
    }

  } catch (error) {
    console.error("\n❌ ERROR:", error.message);
  }
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });


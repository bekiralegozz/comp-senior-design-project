import hre from "hardhat";
import fs from "fs";

async function main() {
  console.log("🔧 Configuring RentalHub...\n");

  // Load deployment addresses
  const addresses = JSON.parse(fs.readFileSync('deployment-addresses.json', 'utf8'));
  
  const rentalHubAddress = addresses.rentalHub;
  const building1122Address = addresses.building1122;
  const smartRentHubAddress = addresses.smartRentHub;

  console.log("RentalHub:    ", rentalHubAddress);
  console.log("Building1122: ", building1122Address);
  console.log("SmartRentHub: ", smartRentHubAddress);
  console.log("");

  // Get contract instance
  const RentalHub = await hre.ethers.getContractAt("RentalHub", rentalHubAddress);

  // Configure
  console.log("1️⃣ Setting Building1122 address...");
  const tx1 = await RentalHub.setBuildingToken(building1122Address);
  await tx1.wait(2);
  console.log("✅ Done!");

  console.log("2️⃣ Setting SmartRentHub address...");
  const tx2 = await RentalHub.setSmartRentHub(smartRentHubAddress);
  await tx2.wait(2);
  console.log("✅ Done!");

  console.log("3️⃣ Setting platform fee to 2.5%...");
  const tx3 = await RentalHub.setPlatformFee(250); // 2.5% = 250 basis points
  await tx3.wait(2);
  console.log("✅ Done!\n");

  console.log("🎉 RentalHub configuration complete!\n");
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error("❌ Configuration failed:", error);
    process.exit(1);
  });


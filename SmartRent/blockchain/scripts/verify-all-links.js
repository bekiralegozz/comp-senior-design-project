import hre from "hardhat";

async function main() {
  console.log("🔍 VERIFYING ALL CONTRACT LINKS...\n");

  const building1122Address = "0xd4f7c1D9979a6b1795C4E23fF9FD6b3De0ce3793";
  const smartRentHubAddress = "0xa5F12C3c5A43fdEfcAff190DcAb057144897df8d";
  const rentalHubAddress = "0xbC549BD4a892aDfAa42399E8cD22D3574f113B5a";

  try {
    // 1. Building1122 → SmartRentHub
    console.log("1️⃣ Building1122 → SmartRentHub:");
    const Building1122 = await hre.ethers.getContractFactory("Building1122");
    const building1122 = Building1122.attach(building1122Address);
    const building1122SmartRentHub = await building1122.smartRentHub();
    console.log(`   Expected: ${smartRentHubAddress}`);
    console.log(`   Actual:   ${building1122SmartRentHub}`);
    console.log(`   Status:   ${building1122SmartRentHub.toLowerCase() === smartRentHubAddress.toLowerCase() ? '✅ CORRECT' : '❌ WRONG'}\n`);

    // 2. SmartRentHub → Building1122
    console.log("2️⃣ SmartRentHub → Building1122:");
    const SmartRentHub = await hre.ethers.getContractFactory("SmartRentHub");
    const smartRentHub = SmartRentHub.attach(smartRentHubAddress);
    const smartRentHubBuilding = await smartRentHub.buildingToken();
    console.log(`   Expected: ${building1122Address}`);
    console.log(`   Actual:   ${smartRentHubBuilding}`);
    console.log(`   Status:   ${smartRentHubBuilding.toLowerCase() === building1122Address.toLowerCase() ? '✅ CORRECT' : '❌ WRONG'}\n`);

    // 3. SmartRentHub → RentalHub
    console.log("3️⃣ SmartRentHub → RentalHub:");
    const smartRentHubRentalHub = await smartRentHub.rentalHub();
    console.log(`   Expected: ${rentalHubAddress}`);
    console.log(`   Actual:   ${smartRentHubRentalHub}`);
    console.log(`   Status:   ${smartRentHubRentalHub.toLowerCase() === rentalHubAddress.toLowerCase() ? '✅ CORRECT' : '❌ WRONG'}\n`);

    // 4. RentalHub → SmartRentHub
    console.log("4️⃣ RentalHub → SmartRentHub:");
    const RentalHub = await hre.ethers.getContractFactory("RentalHub");
    const rentalHub = RentalHub.attach(rentalHubAddress);
    const rentalHubSmartRentHub = await rentalHub.smartRentHub();
    console.log(`   Expected: ${smartRentHubAddress}`);
    console.log(`   Actual:   ${rentalHubSmartRentHub}`);
    console.log(`   Status:   ${rentalHubSmartRentHub.toLowerCase() === smartRentHubAddress.toLowerCase() ? '✅ CORRECT' : '❌ WRONG'}\n`);

    // 5. RentalHub → Building1122
    console.log("5️⃣ RentalHub → Building1122:");
    const rentalHubBuilding = await rentalHub.buildingToken();
    console.log(`   Expected: ${building1122Address}`);
    console.log(`   Actual:   ${rentalHubBuilding}`);
    console.log(`   Status:   ${rentalHubBuilding.toLowerCase() === building1122Address.toLowerCase() ? '✅ CORRECT' : '❌ WRONG'}\n`);

    // Summary
    const allCorrect = 
      building1122SmartRentHub.toLowerCase() === smartRentHubAddress.toLowerCase() &&
      smartRentHubBuilding.toLowerCase() === building1122Address.toLowerCase() &&
      smartRentHubRentalHub.toLowerCase() === rentalHubAddress.toLowerCase() &&
      rentalHubSmartRentHub.toLowerCase() === smartRentHubAddress.toLowerCase() &&
      rentalHubBuilding.toLowerCase() === building1122Address.toLowerCase();

    if (allCorrect) {
      console.log("🎉 ALL LINKS CORRECT! All contracts properly connected.\n");
    } else {
      console.log("❌ SOME LINKS ARE WRONG! Please fix them.\n");
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


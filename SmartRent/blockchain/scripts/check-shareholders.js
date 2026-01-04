const hre = require("hardhat");

async function main() {
    const tokenId = process.argv[2] || "1";
    
    console.log(`\n🔍 Checking shareholders for tokenId ${tokenId}...\n`);
    
    // Get contract addresses from env
    const SMARTRENTHUB_ADDRESS = process.env.SMARTRENTHUB_CONTRACT_ADDRESS;
    const BUILDING1122_ADDRESS = process.env.BUILDING1122_CONTRACT_ADDRESS;
    
    // Get contracts
    const SmartRentHub = await hre.ethers.getContractAt("SmartRentHub", SMARTRENTHUB_ADDRESS);
    const Building1122 = await hre.ethers.getContractAt("Building1122", BUILDING1122_ADDRESS);
    
    // Get asset info
    const asset = await SmartRentHub.getAsset(tokenId);
    console.log(`📦 Asset Info:`);
    console.log(`   Total Shares: ${asset.totalShares}`);
    console.log(`   Metadata: ${asset.metadataURI}`);
    console.log(`   Created: ${new Date(Number(asset.createdAt) * 1000).toLocaleString()}`);
    
    // Get all shareholders
    const shareholders = await SmartRentHub.getAssetOwners(tokenId);
    console.log(`\n👥 Shareholders (${shareholders.length} total):`);
    
    let totalDistributed = 0;
    
    for (let i = 0; i < shareholders.length; i++) {
        const holder = shareholders[i];
        const balance = await Building1122.balanceOf(holder, tokenId);
        const percentage = (Number(balance) / Number(asset.totalShares)) * 100;
        
        console.log(`\n   ${i + 1}. ${holder}`);
        console.log(`      Shares: ${balance} (${percentage.toFixed(2)}%)`);
        
        totalDistributed += Number(balance);
    }
    
    console.log(`\n✅ Total shares distributed: ${totalDistributed} / ${asset.totalShares}`);
    
    // Get top shareholder
    const [topHolder, topBalance] = await SmartRentHub.getTopShareholder(tokenId);
    console.log(`\n🏆 Top Shareholder: ${topHolder}`);
    console.log(`   Shares: ${topBalance}`);
    
    // Simulate rental payment distribution
    const rentalPayment = hre.ethers.parseEther("0.1"); // 0.1 POL
    console.log(`\n💰 Simulated Rental Payment Distribution (0.1 POL):`);
    
    for (let i = 0; i < shareholders.length; i++) {
        const holder = shareholders[i];
        const balance = await Building1122.balanceOf(holder, tokenId);
        const payment = (rentalPayment * balance) / asset.totalShares;
        const paymentInPol = hre.ethers.formatEther(payment);
        
        console.log(`   ${holder}: ${paymentInPol} POL`);
    }
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });


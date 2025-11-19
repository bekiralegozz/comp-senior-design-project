const BuildingRegistry = artifacts.require("BuildingRegistry");

module.exports = async function (callback) {
    try {
        console.log("🚀 Otomatik Transaction Testi Başlıyor...\n");
        
        // BuildingRegistry instance'ını al
        const registry = await BuildingRegistry.deployed();
        console.log("✅ BuildingRegistry adresi:", registry.address);
        
        // Mevcut hesap bilgisi
        const accounts = await web3.eth.getAccounts();
        const deployer = accounts[0];
        console.log("👤 Kullanılan hesap:", deployer);
        console.log("💰 Bakiye:", web3.utils.fromWei(await web3.eth.getBalance(deployer), "ether"), "ETH\n");
        
        // 1. Bina Oluştur
        console.log("📝 1. Bina oluşturuluyor...");
        const tx1 = await registry.createBuilding(
            "Otomatik Test Binası",
            "Bu bina otomatik test scripti ile oluşturuldu",
            "İstanbul, Türkiye",
            10000,  // 10000 pay
            web3.utils.toWei("1", "ether"),  // 1 ETH per share
            web3.utils.toWei("0.1", "ether")  // 0.1 ETH per day
        );
        
        console.log("   Transaction hash:", tx1.tx);
        console.log("   ⏳ Transaction bekleniyor...");
        
        const receipt1 = await tx1;
        const event1 = receipt1.logs.find(log => log.event === "BuildingCreated");
        const buildingId = event1.args.buildingId.toString();
        
        console.log("   ✅ Bina oluşturuldu!");
        console.log("   🏢 Bina ID:", buildingId);
        console.log("   🪙 Token Adresi:", event1.args.tokenAddress);
        console.log("   📊 Toplam Pay:", event1.args.totalShares.toString());
        console.log("   💵 Pay Başına Fiyat:", web3.utils.fromWei(event1.args.pricePerShare, "ether"), "ETH\n");
        
        // 2. Yatırım Yap
        console.log("💰 2. Yatırım yapılıyor...");
        const investAmount = web3.utils.toWei("5", "ether"); // 5 ETH yatırım
        
        const tx2 = await registry.investInBuilding(buildingId, {
            from: deployer,
            value: investAmount
        });
        
        console.log("   Transaction hash:", tx2.tx);
        console.log("   ⏳ Transaction bekleniyor...");
        
        const receipt2 = await tx2;
        const event2 = receipt2.logs.find(log => log.event === "InvestmentMade");
        
        console.log("   ✅ Yatırım başarılı!");
        console.log("   💰 Yatırım Miktarı:", web3.utils.fromWei(event2.args.amount, "ether"), "ETH");
        console.log("   📈 Alınan Pay:", event2.args.sharesReceived.toString());
        console.log("   📊 Pay Yüzdesi:", (event2.args.sharesReceived / 10000 * 100).toFixed(2), "%\n");
        
        // 3. Kira Öde
        console.log("🏠 3. Kira ödemesi yapılıyor...");
        const rentDays = 7; // 7 gün kiralama
        const rentAmount = web3.utils.toWei("0.7", "ether"); // 0.1 ETH * 7 gün
        
        const tx3 = await registry.payRent(buildingId, rentDays, {
            from: accounts[1], // Farklı bir hesap (kiracı)
            value: rentAmount
        });
        
        console.log("   Transaction hash:", tx3.tx);
        console.log("   ⏳ Transaction bekleniyor...");
        
        const receipt3 = await tx3;
        const event3 = receipt3.logs.find(log => log.event === "RentPaid");
        
        console.log("   ✅ Kira ödemesi başarılı!");
        console.log("   💵 Ödenen Kira:", web3.utils.fromWei(event3.args.amount, "ether"), "ETH");
        console.log("   📅 Kiralama Günü:", event3.args.daysRented.toString(), "gün\n");
        
        // 4. Gelir Çek
        console.log("💸 4. Yatırımcı gelir çekiyor...");
        const tx4 = await registry.withdrawRentEarnings(buildingId, {
            from: deployer // Yatırımcı gelir çekiyor
        });
        
        console.log("   Transaction hash:", tx4.tx);
        console.log("   ⏳ Transaction bekleniyor...");
        
        await tx4;
        console.log("   ✅ Gelir başarıyla çekildi!\n");
        
        // 5. Bina Bilgilerini Göster
        console.log("📋 5. Bina bilgileri:");
        const building = await registry.getBuilding(buildingId);
        console.log("   🏢 Bina Adı:", building.name);
        console.log("   📍 Konum:", building.location);
        console.log("   💰 Toplam Yatırım:", web3.utils.fromWei(building.totalInvested, "ether"), "ETH");
        console.log("   🏠 Günlük Kira:", web3.utils.fromWei(building.rentalPricePerDay, "ether"), "ETH");
        console.log("   🔓 Yatırım Açık:", building.investmentOpen ? "Evet" : "Hayır");
        
        // 6. Yatırımcı kazançlarını göster
        console.log("\n💵 6. Yatırımcı kazançları:");
        const earnings = await registry.getInvestorEarnings(buildingId, deployer);
        console.log("   💰 Toplam Kazanç:", web3.utils.fromWei(earnings[0], "ether"), "ETH");
        console.log("   💸 Çekilen:", web3.utils.fromWei(earnings[1], "ether"), "ETH");
        console.log("   💵 Çekilebilir:", web3.utils.fromWei(earnings[2], "ether"), "ETH");
        
        console.log("\n✅ Tüm testler başarıyla tamamlandı!");
        console.log("📊 Ganache'de Transactions sekmesinde tüm transaction'ları görebilirsiniz.\n");
        
        callback();
    } catch (error) {
        console.error("❌ Hata:", error);
        callback(error);
    }
};


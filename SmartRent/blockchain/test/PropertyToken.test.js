const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("PropertyToken & PropertyManager - Complete Test Scenario", function () {
  let propertyToken;
  let propertyManager;
  let owner;
  let investor1, investor2, investor3, investor4, investor5;
  let renter;

  // Test property data
  const propertyName = "Luxury Apartment Building";
  const propertyDescription = "Modern 10-story apartment building in downtown Istanbul";
  const propertyLocation = "Istanbul, Turkey";
  const tokenPrice = ethers.parseEther("0.1"); // 0.1 ETH per token
  const rentalIncome = ethers.parseEther("1.0"); // 1 ETH rental income

  beforeEach(async function () {
    // Get signers (accounts) - these are our "imaginary" investors and wallets
    [owner, investor1, investor2, investor3, investor4, investor5, renter] =
      await ethers.getSigners();

    // Deploy PropertyToken contract
    const PropertyToken = await ethers.getContractFactory("PropertyToken");
    propertyToken = await PropertyToken.deploy();
    await propertyToken.waitForDeployment();

    // Deploy PropertyManager contract with PropertyToken address
    const PropertyManager = await ethers.getContractFactory("PropertyManager");
    propertyManager = await PropertyManager.deploy(
      await propertyToken.getAddress()
    );
    await propertyManager.waitForDeployment();

    // Initialize property
    await propertyToken
      .connect(owner)
      .initializeProperty(
        propertyName,
        propertyDescription,
        propertyLocation,
        tokenPrice
      );
  });

  describe("Contract Deployment", function () {
    it("Should deploy PropertyToken contract", async function () {
      expect(await propertyToken.getAddress()).to.be.properAddress;
    });

    it("Should deploy PropertyManager contract", async function () {
      expect(await propertyManager.getAddress()).to.be.properAddress;
    });

    it("Should link PropertyManager to PropertyToken", async function () {
      const tokenAddress = await propertyManager.propertyToken();
      expect(tokenAddress).to.equal(await propertyToken.getAddress());
    });
  });

  describe("Property Initialization", function () {
    it("Should initialize property with correct data", async function () {
      const propertyInfo = await propertyToken.getPropertyInfo();
      expect(propertyInfo.name).to.equal(propertyName);
      expect(propertyInfo.location).to.equal(propertyLocation);
      expect(propertyInfo.tokenPrice).to.equal(tokenPrice);
      expect(propertyInfo.initialized).to.be.true;
    });

    it("Should have 100 tokens as total supply", async function () {
      const totalSupply = await propertyToken.TOTAL_SUPPLY();
      expect(totalSupply).to.equal(ethers.parseEther("100")); // 100 tokens with 18 decimals
    });

    it("Should not allow double initialization", async function () {
      await expect(
        propertyToken
          .connect(owner)
          .initializeProperty(
            "Another Property",
            "Description",
            "Location",
            tokenPrice
          )
      ).to.be.revertedWith("Property already initialized");
    });
  });

  describe("Token Purchase by Imaginary Investors", function () {
    it("Should allow investor1 to buy tokens by percentage", async function () {
      const percentage = 40; // 40% ownership
      const tokensExpected = ethers.parseEther("40"); // 40 tokens
      const totalCost = tokenPrice * BigInt(40);

      await propertyToken.connect(investor1).buyTokensByPercentage(percentage, {
        value: totalCost,
      });

      const balance = await propertyToken.balanceOf(investor1.address);
      expect(balance).to.equal(tokensExpected);

      const share = await propertyToken.getInvestorShare(investor1.address);
      expect(share).to.equal(40); // 40%
    });

    it("Should allow multiple imaginary investors to buy tokens", async function () {
      // Investor 1 buys 40% (40 tokens)
      await propertyToken.connect(investor1).buyTokensByPercentage(40, {
        value: tokenPrice * BigInt(40),
      });

      // Investor 2 buys 30% (30 tokens)
      await propertyToken.connect(investor2).buyTokensByPercentage(30, {
        value: tokenPrice * BigInt(30),
      });

      // Investor 3 buys 20% (20 tokens)
      await propertyToken.connect(investor3).buyTokensByPercentage(20, {
        value: tokenPrice * BigInt(20),
      });

      // Investor 4 buys 10% (10 tokens)
      await propertyToken.connect(investor4).buyTokensByPercentage(10, {
        value: tokenPrice * BigInt(10),
      });

      // Verify token ownership
      expect(await propertyToken.balanceOf(investor1.address)).to.equal(
        ethers.parseEther("40")
      );
      expect(await propertyToken.balanceOf(investor2.address)).to.equal(
        ethers.parseEther("30")
      );
      expect(await propertyToken.balanceOf(investor3.address)).to.equal(
        ethers.parseEther("20")
      );
      expect(await propertyToken.balanceOf(investor4.address)).to.equal(
        ethers.parseEther("10")
      );

      // Verify total supply
      const totalSupply = await propertyToken.totalSupply();
      expect(totalSupply).to.equal(ethers.parseEther("100"));
    });

    it("Should calculate ownership percentage correctly", async function () {
      await propertyToken.connect(investor1).buyTokensByPercentage(25, {
        value: tokenPrice * BigInt(25),
      });

      const share = await propertyToken.getInvestorShare(investor1.address);
      expect(share).to.equal(25); // 25 tokens = 25% ownership
    });

    it("Should not allow buying more than 100%", async function () {
      await expect(
        propertyToken.connect(investor1).buyTokensByPercentage(101, {
          value: tokenPrice * BigInt(101),
        })
      ).to.be.revertedWith("Invalid percentage");
    });
  });

  describe("Rental Income Distribution - Automatic Payment to Wallets", function () {
    beforeEach(async function () {
      // Setup: Multiple investors buy all 100 tokens
      await propertyToken.connect(investor1).buyTokensByPercentage(40, {
        value: tokenPrice * BigInt(40),
      }); // 40% ownership
      await propertyToken.connect(investor2).buyTokensByPercentage(30, {
        value: tokenPrice * BigInt(30),
      }); // 30% ownership
      await propertyToken.connect(investor3).buyTokensByPercentage(20, {
        value: tokenPrice * BigInt(20),
      }); // 20% ownership
      await propertyToken.connect(investor4).buyTokensByPercentage(10, {
        value: tokenPrice * BigInt(10),
      }); // 10% ownership
      // Total: 100% ownership
    });

    it("Should automatically send rental income directly to investor wallets", async function () {
      // Get initial balances
      const initialBalance1 = await ethers.provider.getBalance(investor1.address);
      const initialBalance2 = await ethers.provider.getBalance(investor2.address);
      const initialBalance3 = await ethers.provider.getBalance(investor3.address);
      const initialBalance4 = await ethers.provider.getBalance(investor4.address);

      // Distribute 1 ETH rental income
      const tx = await propertyManager.connect(renter).distributeRentalIncome({
        value: rentalIncome,
      });
      const receipt = await tx.wait();
      const gasUsed = receipt.gasUsed * receipt.gasPrice;

      // Get final balances
      const finalBalance1 = await ethers.provider.getBalance(investor1.address);
      const finalBalance2 = await ethers.provider.getBalance(investor2.address);
      const finalBalance3 = await ethers.provider.getBalance(investor3.address);
      const finalBalance4 = await ethers.provider.getBalance(investor4.address);

      // Calculate received amounts
      const received1 = finalBalance1 - initialBalance1;
      const received2 = finalBalance2 - initialBalance2;
      const received3 = finalBalance3 - initialBalance3;
      const received4 = finalBalance4 - initialBalance4;

      // Verify amounts are correct (allowing for gas fees)
      // Investor 1: 40% of 1 ETH = 0.4 ETH
      expect(received1).to.be.closeTo(
        ethers.parseEther("0.4"),
        ethers.parseEther("0.01")
      );

      // Investor 2: 30% of 1 ETH = 0.3 ETH
      expect(received2).to.be.closeTo(
        ethers.parseEther("0.3"),
        ethers.parseEther("0.01")
      );

      // Investor 3: 20% of 1 ETH = 0.2 ETH
      expect(received3).to.be.closeTo(
        ethers.parseEther("0.2"),
        ethers.parseEther("0.01")
      );

      // Investor 4: 10% of 1 ETH = 0.1 ETH
      expect(received4).to.be.closeTo(
        ethers.parseEther("0.1"),
        ethers.parseEther("0.01")
      );
    });

    it("Should emit IncomeSent events for each investor", async function () {
      await expect(
        propertyManager.connect(renter).distributeRentalIncome({
          value: rentalIncome,
        })
      )
        .to.emit(propertyManager, "IncomeSent")
        .withArgs(
          investor1.address,
          ethers.parseEther("0.4"),
          ethers.parseEther("40"),
          40
        )
        .and.to.emit(propertyManager, "IncomeSent")
        .withArgs(
          investor2.address,
          ethers.parseEther("0.3"),
          ethers.parseEther("30"),
          30
        );
    });

    it("Should update total rental income distributed", async function () {
      await propertyManager.connect(renter).distributeRentalIncome({
        value: rentalIncome,
      });

      const totalIncome = await propertyManager.totalRentalIncomeDistributed();
      expect(totalIncome).to.equal(rentalIncome);

      // Distribute another rental
      const secondRental = ethers.parseEther("0.5");
      await propertyManager.connect(renter).distributeRentalIncome({
        value: secondRental,
      });

      const updatedTotal = await propertyManager.totalRentalIncomeDistributed();
      expect(updatedTotal).to.equal(rentalIncome + secondRental);
    });
  });

  describe("Complete Workflow Test - Real Scenario", function () {
    it("Should handle complete workflow: initialize -> buy tokens -> distribute rental -> verify payments", async function () {
      console.log("\n=== Complete Property Tokenization Scenario ===\n");

      // Step 1: Multiple imaginary investors buy tokens
      console.log("Step 1: Imaginary investors buying tokens...");

      await propertyToken.connect(investor1).buyTokensByPercentage(40, {
        value: tokenPrice * BigInt(40),
      });
      console.log(
        `  ✓ Investor 1 (${investor1.address.slice(
          0,
          10
        )}...) bought 40 tokens (40% ownership)`
      );

      await propertyToken.connect(investor2).buyTokensByPercentage(30, {
        value: tokenPrice * BigInt(30),
      });
      console.log(
        `  ✓ Investor 2 (${investor2.address.slice(
          0,
          10
        )}...) bought 30 tokens (30% ownership)`
      );

      await propertyToken.connect(investor3).buyTokensByPercentage(20, {
        value: tokenPrice * BigInt(20),
      });
      console.log(
        `  ✓ Investor 3 (${investor3.address.slice(
          0,
          10
        )}...) bought 20 tokens (20% ownership)`
      );

      await propertyToken.connect(investor4).buyTokensByPercentage(10, {
        value: tokenPrice * BigInt(10),
      });
      console.log(
        `  ✓ Investor 4 (${investor4.address.slice(
          0,
          10
        )}...) bought 10 tokens (10% ownership)`
      );
      console.log("  Total tokens sold: 100/100 (100%)\n");

      // Step 2: Verify ownership
      console.log("Step 2: Verifying ownership percentages...");
      const [balance1, share1] = await propertyToken.getInvestorDetails(
        investor1.address
      );
      const [balance2, share2] = await propertyToken.getInvestorDetails(
        investor2.address
      );
      const [balance3, share3] = await propertyToken.getInvestorDetails(
        investor3.address
      );
      const [balance4, share4] = await propertyToken.getInvestorDetails(
        investor4.address
      );

      console.log(
        `  Investor 1: ${ethers.formatEther(balance1)} tokens = ${share1}% ownership`
      );
      console.log(
        `  Investor 2: ${ethers.formatEther(balance2)} tokens = ${share2}% ownership`
      );
      console.log(
        `  Investor 3: ${ethers.formatEther(balance3)} tokens = ${share3}% ownership`
      );
      console.log(
        `  Investor 4: ${ethers.formatEther(balance4)} tokens = ${share4}% ownership\n`
      );

      // Step 3: Get initial wallet balances
      console.log("Step 3: Getting initial wallet balances...");
      const initialBalance1 = await ethers.provider.getBalance(
        investor1.address
      );
      const initialBalance2 = await ethers.provider.getBalance(
        investor2.address
      );
      const initialBalance3 = await ethers.provider.getBalance(
        investor3.address
      );
      const initialBalance4 = await ethers.provider.getBalance(
        investor4.address
      );

      console.log(
        `  Investor 1 initial balance: ${ethers.formatEther(initialBalance1)} ETH`
      );
      console.log(
        `  Investor 2 initial balance: ${ethers.formatEther(initialBalance2)} ETH`
      );
      console.log(
        `  Investor 3 initial balance: ${ethers.formatEther(initialBalance3)} ETH`
      );
      console.log(
        `  Investor 4 initial balance: ${ethers.formatEther(initialBalance4)} ETH\n`
      );

      // Step 4: Rental income distribution (1 ETH)
      console.log("Step 4: Distributing rental income (1 ETH)...");
      const tx = await propertyManager.connect(renter).distributeRentalIncome({
        value: rentalIncome,
      });
      const receipt = await tx.wait();
      console.log(
        `  ✓ Rental income distributed automatically to all investors`
      );
      console.log(
        `  ✓ Gas used: ${ethers.formatEther(receipt.gasUsed * receipt.gasPrice)} ETH\n`
      );

      // Step 5: Check final wallet balances
      console.log("Step 5: Checking final wallet balances after distribution...");
      const finalBalance1 = await ethers.provider.getBalance(investor1.address);
      const finalBalance2 = await ethers.provider.getBalance(investor2.address);
      const finalBalance3 = await ethers.provider.getBalance(investor3.address);
      const finalBalance4 = await ethers.provider.getBalance(investor4.address);

      const received1 = finalBalance1 - initialBalance1;
      const received2 = finalBalance2 - initialBalance2;
      const received3 = finalBalance3 - initialBalance3;
      const received4 = finalBalance4 - initialBalance4;

      console.log(
        `  Investor 1 received: ${ethers.formatEther(
          received1
        )} ETH (40% of 1 ETH = 0.4 ETH)`
      );
      console.log(
        `  Investor 2 received: ${ethers.formatEther(
          received2
        )} ETH (30% of 1 ETH = 0.3 ETH)`
      );
      console.log(
        `  Investor 3 received: ${ethers.formatEther(
          received3
        )} ETH (20% of 1 ETH = 0.2 ETH)`
      );
      console.log(
        `  Investor 4 received: ${ethers.formatEther(
          received4
        )} ETH (10% of 1 ETH = 0.1 ETH)`
      );
      console.log(`  Total distributed: 1.0 ETH\n`);

      // Verify amounts are correct (allowing for gas fees)
      expect(received1).to.be.closeTo(
        ethers.parseEther("0.4"),
        ethers.parseEther("0.01")
      );
      expect(received2).to.be.closeTo(
        ethers.parseEther("0.3"),
        ethers.parseEther("0.01")
      );
      expect(received3).to.be.closeTo(
        ethers.parseEther("0.2"),
        ethers.parseEther("0.01")
      );
      expect(received4).to.be.closeTo(
        ethers.parseEther("0.1"),
        ethers.parseEther("0.01")
      );

      // Verify total rental income tracked
      const totalIncome = await propertyManager.totalRentalIncomeDistributed();
      console.log(
        `  Total rental income tracked: ${ethers.formatEther(totalIncome)} ETH\n`
      );

      // Check distribution record
      const distribution = await propertyManager.getRentalDistribution(1);
      console.log(`  Distribution #1 recorded:`);
      console.log(
        `    Amount: ${ethers.formatEther(distribution.amount)} ETH`
      );
      console.log(`    Timestamp: ${distribution.timestamp}`);
      console.log(`    Investor Count: ${distribution.investorCount}\n`);

      console.log("=== Scenario completed successfully! ===\n");
      console.log("✅ All investors received their proportional share directly in their wallets!");
      console.log("✅ No manual withdrawal needed - automatic distribution works!");
      console.log("✅ ERC-20 tokens can be transferred between wallets!\n");
    });
  });

  describe("ERC-20 Token Features", function () {
    beforeEach(async function () {
      await propertyToken.connect(investor1).buyTokensByPercentage(50, {
        value: tokenPrice * BigInt(50),
      });
    });

    it("Should allow token transfer between addresses", async function () {
      const transferAmount = ethers.parseEther("10"); // 10 tokens
      await propertyToken
        .connect(investor1)
        .transfer(investor2.address, transferAmount);

      expect(await propertyToken.balanceOf(investor2.address)).to.equal(
        transferAmount
      );
      expect(await propertyToken.balanceOf(investor1.address)).to.equal(
        ethers.parseEther("40")
      );
    });

    it("Should allow token approval and transferFrom", async function () {
      const approveAmount = ethers.parseEther("20");
      await propertyToken
        .connect(investor1)
        .approve(investor2.address, approveAmount);

      const allowance = await propertyToken.allowance(
        investor1.address,
        investor2.address
      );
      expect(allowance).to.equal(approveAmount);

      const transferAmount = ethers.parseEther("15");
      await propertyToken
        .connect(investor2)
        .transferFrom(investor1.address, investor3.address, transferAmount);

      expect(await propertyToken.balanceOf(investor3.address)).to.equal(
        transferAmount
      );
    });
  });

  describe("View Functions", function () {
    beforeEach(async function () {
      await propertyToken.connect(investor1).buyTokensByPercentage(30, {
        value: tokenPrice * BigInt(30),
      });
      await propertyToken.connect(investor2).buyTokensByPercentage(20, {
        value: tokenPrice * BigInt(20),
      });
    });

    it("Should return correct available tokens", async function () {
      const available = await propertyToken.getAvailableTokens();
      expect(available).to.equal(ethers.parseEther("50")); // 100 - 50 = 50
    });

    it("Should return correct available percentage", async function () {
      const availablePercentage = await propertyToken.getAvailablePercentage();
      expect(availablePercentage).to.equal(50); // 50%
    });

    it("Should return all investors", async function () {
      const investors = await propertyToken.getAllInvestors();
      expect(investors.length).to.equal(2);
      expect(investors).to.include(investor1.address);
      expect(investors).to.include(investor2.address);
    });

    it("Should return correct investor count", async function () {
      const count = await propertyToken.getInvestorCount();
      expect(count).to.equal(2);
    });
  });

  describe("Edge Cases", function () {
    it("Should not distribute if no tokens are sold", async function () {
      await expect(
        propertyManager.connect(renter).distributeRentalIncome({
          value: rentalIncome,
        })
      ).to.be.revertedWith("No tokens have been sold yet");
    });

    it("Should not allow buying more tokens than available", async function () {
      // Buy 60% first
      await propertyToken.connect(investor1).buyTokensByPercentage(60, {
        value: tokenPrice * BigInt(60),
      });

      // Try to buy 50% more (total would be 110%)
      await expect(
        propertyToken.connect(investor2).buyTokensByPercentage(50, {
          value: tokenPrice * BigInt(50),
        })
      ).to.be.revertedWith("Not enough tokens available");
    });

    it("Should handle partial token ownership correctly", async function () {
      // Investor buys only 1% (1 token)
      await propertyToken.connect(investor1).buyTokensByPercentage(1, {
        value: tokenPrice,
      });

      const initialBalance = await ethers.provider.getBalance(
        investor1.address
      );

      // Distribute 1 ETH - investor should get 1% = 0.01 ETH
      await propertyManager.connect(renter).distributeRentalIncome({
        value: rentalIncome,
      });

      const finalBalance = await ethers.provider.getBalance(investor1.address);
      const received = finalBalance - initialBalance;

      // Should receive approximately 0.01 ETH (1% of 1 ETH)
      expect(received).to.be.closeTo(
        ethers.parseEther("0.01"),
        ethers.parseEther("0.001")
      );
    });
  });
});



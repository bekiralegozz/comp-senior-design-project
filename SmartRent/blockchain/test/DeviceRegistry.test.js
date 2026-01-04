const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("RentalHub - Device Registry", function () {
  let building1122;
  let smartRentHub;
  let rentalHub;
  let owner;
  let user1;
  let user2;

  const TOKEN_ID = 1;
  const DEVICE_ID = "ESP32-ROOM-101";
  const TOTAL_SUPPLY = 1000;
  const PRICE_PER_NIGHT = ethers.parseEther("0.1"); // 0.1 POL

  beforeEach(async function () {
    [owner, user1, user2] = await ethers.getSigners();

    // Deploy Building1122
    const Building1122 = await ethers.getContractFactory("Building1122");
    building1122 = await Building1122.deploy("", owner.address);
    await building1122.waitForDeployment();

    // Deploy SmartRentHub
    const SmartRentHub = await ethers.getContractFactory("SmartRentHub");
    smartRentHub = await SmartRentHub.deploy(owner.address, owner.address);
    await smartRentHub.waitForDeployment();

    // Deploy RentalHub
    const RentalHub = await ethers.getContractFactory("RentalHub");
    rentalHub = await RentalHub.deploy(owner.address, owner.address);
    await rentalHub.waitForDeployment();

    // Connect contracts
    await building1122.setSmartRentHub(await smartRentHub.getAddress());
    await smartRentHub.setBuildingToken(await building1122.getAddress());
    await smartRentHub.setRentalHub(await rentalHub.getAddress());
    await rentalHub.setBuildingToken(await building1122.getAddress());
    await rentalHub.setSmartRentHub(await smartRentHub.getAddress());

    // Mint initial supply to user1 (makes them majority shareholder)
    await building1122.connect(user1).mintInitialSupply(
      TOKEN_ID,
      user1.address,
      TOTAL_SUPPLY,
      "ipfs://test-metadata"
    );
  });

  describe("Device Registration", function () {
    it("should allow majority shareholder to register device", async function () {
      await expect(
        rentalHub.connect(user1).registerDevice(TOKEN_ID, DEVICE_ID)
      )
        .to.emit(rentalHub, "DeviceRegistered")
        .withArgs(TOKEN_ID, DEVICE_ID, user1.address);

      expect(await rentalHub.assetToDevice(TOKEN_ID)).to.equal(DEVICE_ID);
      expect(await rentalHub.deviceToAsset(DEVICE_ID)).to.equal(TOKEN_ID);
      expect(await rentalHub.deviceRegistered(DEVICE_ID)).to.be.true;
    });

    it("should reject registration from non-shareholder", async function () {
      await expect(
        rentalHub.connect(user2).registerDevice(TOKEN_ID, DEVICE_ID)
      ).to.be.revertedWith("RentalHub: only majority shareholder can register device");
    });

    it("should reject duplicate device registration", async function () {
      await rentalHub.connect(user1).registerDevice(TOKEN_ID, DEVICE_ID);

      // Try to register same device to different asset
      await building1122.connect(user2).mintInitialSupply(2, user2.address, TOTAL_SUPPLY, "");
      
      await expect(
        rentalHub.connect(user2).registerDevice(2, DEVICE_ID)
      ).to.be.revertedWith("RentalHub: device already registered");
    });

    it("should reject if asset already has device", async function () {
      await rentalHub.connect(user1).registerDevice(TOKEN_ID, DEVICE_ID);

      await expect(
        rentalHub.connect(user1).registerDevice(TOKEN_ID, "ESP32-ROOM-102")
      ).to.be.revertedWith("RentalHub: asset already has device");
    });

    it("should reject empty deviceId", async function () {
      await expect(
        rentalHub.connect(user1).registerDevice(TOKEN_ID, "")
      ).to.be.revertedWith("RentalHub: deviceId cannot be empty");
    });
  });

  describe("Device Unregistration", function () {
    beforeEach(async function () {
      await rentalHub.connect(user1).registerDevice(TOKEN_ID, DEVICE_ID);
    });

    it("should allow majority shareholder to unregister device", async function () {
      await expect(
        rentalHub.connect(user1).unregisterDevice(TOKEN_ID)
      )
        .to.emit(rentalHub, "DeviceUnregistered")
        .withArgs(TOKEN_ID, DEVICE_ID, user1.address);

      expect(await rentalHub.assetToDevice(TOKEN_ID)).to.equal("");
      expect(await rentalHub.deviceToAsset(DEVICE_ID)).to.equal(0);
      expect(await rentalHub.deviceRegistered(DEVICE_ID)).to.be.false;
    });

    it("should allow contract owner to unregister device", async function () {
      await expect(
        rentalHub.connect(owner).unregisterDevice(TOKEN_ID)
      ).to.emit(rentalHub, "DeviceUnregistered");
    });

    it("should reject unregistration from unauthorized user", async function () {
      await expect(
        rentalHub.connect(user2).unregisterDevice(TOKEN_ID)
      ).to.be.revertedWith("RentalHub: not authorized to unregister");
    });
  });

  describe("Unlock Authorization", function () {
    beforeEach(async function () {
      // Register device
      await rentalHub.connect(user1).registerDevice(TOKEN_ID, DEVICE_ID);

      // Create rental listing
      await rentalHub.connect(user1).createRentalListing(TOKEN_ID, PRICE_PER_NIGHT);
    });

    it("should authorize unlock for active renter within dates", async function () {
      // Get current block timestamp
      const block = await ethers.provider.getBlock("latest");
      const checkInDate = block.timestamp + 1; // 1 second from now
      const checkOutDate = checkInDate + (7 * 24 * 60 * 60); // 7 days later

      // Book rental
      const totalPrice = PRICE_PER_NIGHT * 7n;
      await rentalHub.connect(user2).rentAsset(1, checkInDate, checkOutDate, {
        value: totalPrice
      });

      // Move time forward to check-in
      await ethers.provider.send("evm_setNextBlockTimestamp", [checkInDate + 100]);
      await ethers.provider.send("evm_mine");

      // Check authorization
      const [authorized, rentalId] = await rentalHub.isAuthorizedToUnlock(DEVICE_ID, user2.address);
      expect(authorized).to.be.true;
      expect(rentalId).to.equal(1);
    });

    it("should reject unlock for non-renter", async function () {
      const block = await ethers.provider.getBlock("latest");
      const checkInDate = block.timestamp + 1;
      const checkOutDate = checkInDate + (7 * 24 * 60 * 60);

      await rentalHub.connect(user2).rentAsset(1, checkInDate, checkOutDate, {
        value: PRICE_PER_NIGHT * 7n
      });

      await ethers.provider.send("evm_setNextBlockTimestamp", [checkInDate + 100]);
      await ethers.provider.send("evm_mine");

      // Check authorization for different user
      const [authorized] = await rentalHub.isAuthorizedToUnlock(DEVICE_ID, owner.address);
      expect(authorized).to.be.false;
    });

    it("should reject unlock before check-in date", async function () {
      const block = await ethers.provider.getBlock("latest");
      // Set check-in to tomorrow (next day boundary after normalization)
      const tomorrow = Math.floor(block.timestamp / 86400) * 86400 + 86400; // Next day start
      const checkInDate = tomorrow + 86400; // Day after tomorrow
      const checkOutDate = checkInDate + (7 * 24 * 60 * 60);

      await rentalHub.connect(user2).rentAsset(1, checkInDate, checkOutDate, {
        value: PRICE_PER_NIGHT * 7n
      });

      // Current time is still before normalized check-in date
      const [authorized] = await rentalHub.isAuthorizedToUnlock(DEVICE_ID, user2.address);
      expect(authorized).to.be.false;
    });

    it("should reject unlock for unregistered device", async function () {
      const [authorized] = await rentalHub.isAuthorizedToUnlock("FAKE-DEVICE", user2.address);
      expect(authorized).to.be.false;
    });
  });

  describe("View Functions", function () {
    it("should return device by asset", async function () {
      await rentalHub.connect(user1).registerDevice(TOKEN_ID, DEVICE_ID);
      expect(await rentalHub.getDeviceByAsset(TOKEN_ID)).to.equal(DEVICE_ID);
    });

    it("should return asset by device", async function () {
      await rentalHub.connect(user1).registerDevice(TOKEN_ID, DEVICE_ID);
      expect(await rentalHub.getAssetByDevice(DEVICE_ID)).to.equal(TOKEN_ID);
    });

    it("should check if device is registered", async function () {
      expect(await rentalHub.isDeviceRegistered(DEVICE_ID)).to.be.false;
      await rentalHub.connect(user1).registerDevice(TOKEN_ID, DEVICE_ID);
      expect(await rentalHub.isDeviceRegistered(DEVICE_ID)).to.be.true;
    });
  });
});

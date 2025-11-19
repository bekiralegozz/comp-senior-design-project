const BuildingRegistry = artifacts.require("BuildingRegistry");

module.exports = function (deployer) {
  // Deploy BuildingRegistry contract
  // BuildingToken contracts will be deployed automatically when buildings are created
  deployer.deploy(BuildingRegistry);
};


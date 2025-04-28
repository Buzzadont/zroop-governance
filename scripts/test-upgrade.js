const { ethers } = require("hardhat");

async function main() {
  const [deployer] = await ethers.getSigners();
  console.log("Testing upgrade with the account:", deployer.address);

  // Get the proxy contract
  const proxyAddress = "YOUR_PROXY_ADDRESS"; // Replace with actual address
  const ZroopGovernorProxy = await ethers.getContractFactory("ZroopGovernorProxy");
  const proxy = await ZroopGovernorProxy.attach(proxyAddress);

  // Get current implementation
  const currentImpl = await proxy.getImplementation();
  console.log("Current implementation:", currentImpl);

  // Deploy new implementation
  const ZroopGovernor = await ethers.getContractFactory("ZroopGovernor");
  const newImpl = await ZroopGovernor.deploy();
  await newImpl.deployed();
  console.log("New implementation deployed to:", newImpl.address);

  // Test upgrade
  console.log("Testing upgrade...");
  await proxy.upgradeTo(newImpl.address);
  console.log("Upgrade successful!");

  // Verify new implementation
  const newImplAddress = await proxy.getImplementation();
  console.log("New implementation address:", newImplAddress);
  console.log("Upgrade test completed!");
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  }); 
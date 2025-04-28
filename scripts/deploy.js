const { ethers } = require("hardhat");

async function main() {
    const [deployer] = await ethers.getSigners();
    console.log("Deploying contracts with the account:", deployer.address);

    // Deploy ZroopVotes
    const ZroopVotes = await ethers.getContractFactory("ZroopVotes");
    const zroopVotes = await ZroopVotes.deploy();
    await zroopVotes.deployed();
    console.log("ZroopVotes deployed to:", zroopVotes.address);

    // Deploy ZroopTimelock
    const minDelay = 24 * 60 * 60; // 1 day
    const proposers = [deployer.address];
    const executors = [deployer.address];
    const ZroopTimelock = await ethers.getContractFactory("ZroopTimelock");
    const zroopTimelock = await ZroopTimelock.deploy(minDelay, proposers, executors);
    await zroopTimelock.deployed();
    console.log("ZroopTimelock deployed to:", zroopTimelock.address);

    // Deploy ZroopGovernor implementation
    const ZroopGovernor = await ethers.getContractFactory("ZroopGovernor");
    const zroopGovernorImpl = await ZroopGovernor.deploy();
    await zroopGovernorImpl.deployed();
    console.log("ZroopGovernor implementation deployed to:", zroopGovernorImpl.address);

    // Deploy ZroopGovernorProxy
    const initData = ZroopGovernor.interface.encodeFunctionData("initialize", [
        zroopVotes.address,
        zroopTimelock.address,
        1, // voting delay
        7 * 24 * 60 * 60, // voting period (7 days)
        10, // quorum percentage
        zroopVotes.address, // NFT contract
        true, // isMainnet
        deployer.address // treasury
    ]);

    const ZroopGovernorProxy = await ethers.getContractFactory("ZroopGovernorProxy");
    const zroopGovernorProxy = await ZroopGovernorProxy.deploy(
        zroopGovernorImpl.address,
        initData
    );
    await zroopGovernorProxy.deployed();
    console.log("ZroopGovernorProxy deployed to:", zroopGovernorProxy.address);

    // Verify contracts
    if (network.name !== "hardhat" && network.name !== "localhost") {
        console.log("Waiting for block confirmations...");
        await zroopVotes.deployTransaction.wait(6);
        await zroopTimelock.deployTransaction.wait(6);
        await zroopGovernorImpl.deployTransaction.wait(6);
        await zroopGovernorProxy.deployTransaction.wait(6);

        console.log("Verifying contracts...");
        await hre.run("verify:verify", {
            address: zroopVotes.address,
            constructorArguments: [],
        });

        await hre.run("verify:verify", {
            address: zroopTimelock.address,
            constructorArguments: [minDelay, proposers, executors],
        });

        await hre.run("verify:verify", {
            address: zroopGovernorImpl.address,
            constructorArguments: [],
        });

        await hre.run("verify:verify", {
            address: zroopGovernorProxy.address,
            constructorArguments: [zroopGovernorImpl.address, initData],
        });
    }

    console.log("Deployment completed!");
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    }); 
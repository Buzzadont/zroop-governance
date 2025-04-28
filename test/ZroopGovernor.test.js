const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("ZroopGovernor", function () {
    let governor;
    let timelock;
    let token;
    let owner;
    let addr1;
    let addr2;

    const VOTING_DELAY = 1; // 1 block
    const VOTING_PERIOD = 50400; // 1 week
    const QUORUM_PERCENTAGE = 4; // 4%

    beforeEach(async function () {
        [owner, addr1, addr2] = await ethers.getSigners();

        // Deploy token
        const Token = await ethers.getContractFactory("ZroopVotes");
        token = await Token.deploy();
        await token.waitForDeployment();

        // Deploy timelock
        const Timelock = await ethers.getContractFactory("ZroopTimelock");
        timelock = await Timelock.deploy(
            3600, // 1 hour delay
            [], // proposers
            [], // executors
            owner.address // admin
        );
        await timelock.waitForDeployment();

        // Deploy governor
        const Governor = await ethers.getContractFactory("ZroopGovernor");
        governor = await Governor.deploy(
            token.target,
            timelock.target,
            VOTING_DELAY,
            VOTING_PERIOD,
            QUORUM_PERCENTAGE
        );
        await governor.waitForDeployment();

        // Setup roles
        const proposerRole = await timelock.PROPOSER_ROLE();
        const executorRole = await timelock.EXECUTOR_ROLE();
        const adminRole = await timelock.TIMELOCK_ADMIN_ROLE();

        await timelock.grantRole(proposerRole, governor.target);
        await timelock.grantRole(executorRole, governor.target);
        await timelock.revokeRole(adminRole, owner.address);

        // Mint tokens
        await token.safeMint(owner.address, 1);
        await token.safeMint(addr1.address, 2);
        await token.safeMint(addr2.address, 3);
    });

    describe("Deployment", function () {
        it("Should set the correct token address", async function () {
            expect(await governor.token()).to.equal(token.target);
        });

        it("Should set the correct timelock address", async function () {
            expect(await governor.timelock()).to.equal(timelock.target);
        });

        it("Should set the correct voting delay", async function () {
            expect(await governor.votingDelay()).to.equal(VOTING_DELAY);
        });

        it("Should set the correct voting period", async function () {
            expect(await governor.votingPeriod()).to.equal(VOTING_PERIOD);
        });

        it("Should set the correct quorum", async function () {
            expect(await governor.quorumNumerator()).to.equal(QUORUM_PERCENTAGE);
        });
    });

    describe("Proposal Lifecycle", function () {
        let proposalId;
        const description = "Proposal #1: Store 1 in the box";
        const encodedFunction = "0x";

        beforeEach(async function () {
            await token.delegate(owner.address);

            proposalId = await governor.propose(
                [owner.address],
                [0],
                [encodedFunction],
                description
            );
        });

        it("Should create a proposal with the correct properties", async function () {
            const state = await governor.state(proposalId);
            expect(state).to.equal(0); // Pending
        });

        it("Should move to active state after voting delay", async function () {
            await ethers.provider.send("evm_mine", []);
            const state = await governor.state(proposalId);
            expect(state).to.equal(1); // Active
        });
    });
}); 
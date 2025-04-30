# Zroop Governance System

A decentralized governance system for NFT holders, built on the Forma network.

## Overview

The Zroop Governance System allows NFT holders to participate in decision-making through a transparent and secure voting mechanism. The system consists of three main components:

1. **ZroopVotes** - Manages voting power based on NFT ownership
2. **ZroopGovernor** - Handles proposal creation, voting, and execution
3. **ZroopTimelock** - Ensures secure execution of approved proposals

## Features

- NFT-based voting power
- Proposal creation with multiple options
- Professional vote delegation system
- Proposal signing mechanism
- Timelock for secure execution
- Upgradeable contracts

## Contract Architecture

### ZroopVotes

Manages voting power based on NFT ownership:
- Voting power is calculated based on NFT balance
- Supports professional delegation system
- Implements anti-manipulation measures
- Security timelock for delegations

### ZroopGovernor

Main governance contract:
- Creates and manages proposals
- Handles voting process
- Manages proposal execution
- Supports expert delegation system
- Implements proposal signing
- Ensures secure execution through timelock

### ZroopTimelock

Ensures secure execution of proposals:
- Implements delay mechanism (1-30 days)
- Integrates with OpenZeppelin's TimelockController
- Supports operation pausing
- Enforces minimum and maximum delays
- Manages role-based access control

## Security Features

- Reentrancy protection
- Access control
- Pausable functionality
- Timelock mechanism
- Signature verification
- Anti-manipulation measures for delegation
- Protection against flash-delegation attacks

## Delegation System

The system implements a professional delegation mechanism that allows:
- NFT holders to delegate voting power to experts
- Improved governance efficiency through active participation
- Protection against voting manipulation
- Temporary vote transfer with security measures
- Maximum of 5 delegates per user
- 24-hour delegation lock period

## Usage

### Creating a Proposal

```solidity
function createProposal(
    string[] memory options,
    string memory description,
    address[] memory targets,
    uint256[] memory values,
    bytes[] memory calldatas,
    uint256 requiredSignatures
) external payable returns (uint256)
```

### Voting

```solidity
function vote(
    uint256 proposalId,
    uint256 optionIndex,
    uint8 v,
    bytes32 r,
    bytes32 s
) external
```

### Delegating Votes

```solidity
function setDelegation(
    address delegate,
    uint8 v,
    bytes32 r,
    bytes32 s
) external
```

## Network Parameters

### Testnet (Sketchpad)
- Minimum deposit: 0.1 TIA
- Voting period: 1 day
- Quorum: 4%

### Mainnet (Forma)
- Minimum deposit: 10 TIA
- Voting period: 7 days
- Quorum: 10%

## Development

### Prerequisites
- Node.js
- Hardhat
- OpenZeppelin Contracts

### Installation
```bash
npm install
```

### Testing
```bash
npx hardhat test
```

### Deployment
```bash
npx hardhat run scripts/deploy.js --network forma
```

## License

MIT 
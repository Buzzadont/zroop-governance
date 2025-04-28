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
- Vote delegation
- Proposal signing mechanism
- Timelock for secure execution
- Upgradeable contracts

## Contract Architecture

### ZroopVotes

Manages voting power based on NFT ownership:
- Voting power is calculated based on NFT balance
- Tokens can be locked for a period
- Supports vote delegation

### ZroopGovernor

Main governance contract:
- Creates and manages proposals
- Handles voting process
- Manages proposal execution
- Supports vote delegation
- Implements proposal signing

### ZroopTimelock

Ensures secure execution of proposals:
- Implements delay mechanism
- Requires multiple signatures
- Supports operation cancellation

## Security Features

- Reentrancy protection
- Access control
- Pausable functionality
- Timelock mechanism
- Signature verification

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
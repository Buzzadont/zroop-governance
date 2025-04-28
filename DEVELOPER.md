# Zroop Governance System - Developer Documentation

## System Architecture

### Core Components

1. **ZroopVotes**
   - Manages voting power based on NFT ownership
   - No direct token minting/burning
   - Voting power = NFT balance * VOTES_PER_NFT
   - Supports vote locking mechanism

2. **ZroopGovernor**
   - Main governance contract
   - Handles proposal lifecycle
   - Implements voting mechanism
   - Manages delegations
   - Integrates with Timelock

3. **ZroopTimelock**
   - Ensures secure execution
   - Minimum delay: 1 day
   - Maximum delay: 30 days
   - Supports operation cancellation

### Key Features

1. **Voting Power**
   - Based on NFT ownership
   - Can be locked for 7 days
   - Supports delegation
   - No direct token transfers

2. **Proposals**
   - Multiple options (3-10)
   - Required deposit
   - Signature mechanism
   - Timelock execution

3. **Security**
   - Reentrancy protection
   - Access control
   - Pausable functionality
   - Signature verification

## Contract Interactions

### Proposal Flow

1. **Creation**
   ```
   User -> ZroopGovernor.createProposal()
   -> Check NFT ownership
   -> Take deposit
   -> Create proposal
   -> Schedule timelock operation
   ```

2. **Voting**
   ```
   User -> ZroopGovernor.vote()
   -> Check NFT ownership
   -> Check delegation
   -> Record vote
   -> Update proposal state
   ```

3. **Execution**
   ```
   User -> ZroopGovernor.executeProposal()
   -> Check quorum
   -> Execute timelock operation
   -> Return deposit
   ```

### Delegation Flow

1. **Set Delegation**
   ```
   User -> ZroopGovernor.setDelegation()
   -> Check NFT ownership
   -> Set delegation
   -> Update delegation count
   ```

2. **Remove Delegation**
   ```
   User -> ZroopGovernor.removeDelegation()
   -> Check lock period
   -> Remove delegation
   -> Update delegation count
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

## Development Guidelines

### Contract Updates

1. **Adding New Features**
   - Use UUPS upgrade pattern
   - Maintain storage layout
   - Add new events
   - Update documentation

2. **Security Considerations**
   - Check reentrancy
   - Verify access control
   - Test edge cases
   - Audit changes

### Testing

1. **Unit Tests**
   - Test each function
   - Check edge cases
   - Verify events
   - Test access control

2. **Integration Tests**
   - Test contract interactions
   - Verify proposal flow
   - Check delegation
   - Test timelock

### Deployment

1. **Preparation**
   ```bash
   # Verify contracts
   npx hardhat run scripts/verify.js
   
   # Check gas estimates
   npx hardhat run scripts/gas.js
   ```

2. **Contract Deployment Order**
   ```javascript
   // 1. Deploy Governor Implementation
   const governorImplementation = await deploy("ZroopGovernor");
   
   // 2. Deploy Governor Proxy
   const governorProxy = await deployProxy("ZroopGovernor", [
     // initialization parameters
   ]);
   
   // 3. Deploy Timelock
   // Only requires:
   const timelock = await deployProxy("ZroopTimelock", [
     minDelay,        // operation delay (1-30 days)
     governorProxy.address  // Governor Proxy address
   ]);
   
   // 4. Set Timelock address in Governor
   await governorProxy.setTimelock(timelock.address);
   
   // Note: contract will automatically set up roles:
   // - PROPOSER_ROLE is granted only to Governor
   // - EXECUTOR_ROLE is open to everyone (address(0))
   // - CANCELLER_ROLE is also granted to Governor
   // - DEFAULT_ADMIN_ROLE is granted to timelock itself
   
   // All access logic is now controlled through NFT in Governor contract
   ```

3. **Testnet Deployment**
   ```bash
   # Deploy to Sketchpad
   npx hardhat run scripts/deploy.js --network sketchpad
   ```

4. **Mainnet Deployment**
   ```bash
   # Deploy to Forma
   npx hardhat run scripts/deploy.js --network forma
   ```

5. **Contract Initialization**
   ```javascript
   // Example of initialization
   await governor.initialize(
     tokenAddress,
     timelockAddress,
     votingDelay,
     votingPeriod,
     quorumPercentage,
     nftContractAddress,
     isMainnet,
     treasuryAddress
   );
   ```

### 4. Contract Updates

1. **Preparing for Update**
   - Create new contract version
   - Preserve storage layout
   - Add new functions
   - Update documentation

2. **Testing the Update**
   ```bash
   # Test upgrade
   npx hardhat run scripts/test-upgrade.js
   ```

3. **Testnet Update**
   ```bash
   # Update on Sketchpad
   npx hardhat run scripts/upgrade.js --network sketchpad
   ```

4. **Mainnet Update**
   ```bash
   # Update on Forma
   npx hardhat run scripts/upgrade.js --network forma
   ```

### 5. Monitoring and Maintenance

1. **Regular Checks**
   - Monitor events
   - Check proposal states
   - Verify delegations
   - Monitor timelock

2. **Parameter Updates**
   ```javascript
   // Example of parameter updates
   await governor.setVotingPeriod(newPeriod);
   await governor.setQuorum(newQuorum);
   await governor.setNFTContract(newNFTContract);
   ```

### 6. Emergency Procedures

1. **Contract Pause**
   ```javascript
   // Pause contract
   await governor.pause();
   
   // Unpause contract
   await governor.unpause();
   ```

2. **Operation Cancellation**
   ```javascript
   // Cancel proposal
   await governor.cancelProposal(proposalId);
   
   // Cancel timelock operation
   await timelock.cancel(operationId);
   ```

### 7. Common Issues and Solutions

1. **Voting Issues**
   - Check NFT ownership
   - Verify delegation
   - Check lock period
   - Verify vote weight

2. **Proposal Issues**
   - Check deposit amount
   - Verify option count
   - Check signature count
   - Verify timelock

3. **Delegation Issues**
   - Check delegation limit
   - Verify lock period
   - Check NFT ownership
   - Verify delegate address

### 8. Future Improvements

1. **Planned Features**
   - Enhanced delegation
   - Better vote tracking
   - Improved UI
   - Additional security

2. **Potential Updates**
   - New voting mechanisms
   - Additional security features
   - Better scalability
   - More flexibility

## Common Issues

1. **Voting Power**
   - Check NFT ownership
   - Verify delegation
   - Check lock period
   - Verify vote weight

2. **Proposals**
   - Check deposit amount
   - Verify option count
   - Check signature count
   - Verify timelock

3. **Delegation**
   - Check delegation limit
   - Verify lock period
   - Check NFT ownership
   - Verify delegate address

## Maintenance

1. **Regular Checks**
   - Monitor events
   - Check proposal states
   - Verify delegations
   - Monitor timelock

2. **Updates**
   - Review parameters
   - Check security
   - Update documentation
   - Test changes

## Emergency Procedures

1. **Pause Contract**
   - Call pause()
   - Monitor events
   - Notify users
   - Plan recovery

2. **Cancel Operations**
   - Cancel proposals
   - Cancel timelock
   - Return deposits
   - Update state

## Future Improvements

1. **Planned Features**
   - Enhanced delegation
   - Better vote tracking
   - Improved UI
   - More security

2. **Potential Updates**
   - New voting mechanisms
   - Additional security
   - Better scalability
   - More flexibility
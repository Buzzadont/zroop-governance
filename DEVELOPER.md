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
   // 1. Deploy ZroopVotes
   const zroopVotes = await deploy("ZroopVotes", [
     nftContractAddress  // existing NFT contract address
   ]);
   console.log("ZroopVotes deployed to:", zroopVotes.address);

   // 2. Deploy Timelock with temporary Governor
   const tempGovernorAddress = deployerAddress; 
   const timelock = await deploy("ZroopTimelock", [
     isMainnet ? (7 * 24 * 3600) : (1 * 24 * 3600), // minDelay (7 days or 1 day)
     tempGovernorAddress
   ]);
   console.log("ZroopTimelock deployed to:", timelock.address);

   // 3. Deploy Governor Implementation
   const governorImplementation = await deploy("ZroopGovernor");
   console.log("ZroopGovernor implementation deployed to:", governorImplementation.address);

   // 4. Deploy Governor Proxy
   const governorProxy = await deploy("ZroopGovernorProxy", [
     governorImplementation.address,
     encodeInitializeParams([
       zroopVotes.address,        // votes contract address
       timelock.address,          // timelock address
       0,                         // votingDelay (0 blocks)
       isMainnet ? 
         (7 * 24 * 3600) :       // votingPeriod for Forma (7 days)
         (1 * 24 * 3600),        // votingPeriod for Sketchpad (1 day)
       isMainnet ? 10 : 4,       // quorumPercentage (10% or 4%)
       nftContractAddress,        // NFT address
       isMainnet,                // network flag
       treasuryAddress          // treasury address
     ])
   ]);
   console.log("ZroopGovernorProxy deployed to:", governorProxy.address);

   // 5. Configure roles in Timelock
   await timelock.grantRole(PROPOSER_ROLE, governorProxy.address);
   await timelock.grantRole(CANCELLER_ROLE, governorProxy.address);
   await timelock.revokeRole(PROPOSER_ROLE, tempGovernorAddress);
   await timelock.revokeRole(CANCELLER_ROLE, tempGovernorAddress);
   console.log("Timelock roles configured");

   // Note: contract will automatically set up roles:
   // - PROPOSER_ROLE is granted only to Governor
   // - EXECUTOR_ROLE is open to everyone (address(0))
   // - CANCELLER_ROLE is also granted to Governor
   // - DEFAULT_ADMIN_ROLE is granted to timelock itself
   ```

3. **Post-deployment Checks**
   ```javascript
   // 1. Check Timelock roles
   const hasProposerRole = await timelock.hasRole(PROPOSER_ROLE, governorProxy.address);
   const hasCancellerRole = await timelock.hasRole(CANCELLER_ROLE, governorProxy.address);
   console.log("Governor has PROPOSER_ROLE:", hasProposerRole);
   console.log("Governor has CANCELLER_ROLE:", hasCancellerRole);

   // 2. Check Governor parameters
   const votingPeriod = await governorProxy.votingPeriod();
   const quorum = await governorProxy.quorumNumerator();
   const votingDelay = await governorProxy.votingDelay();
   console.log("Voting Period:", votingPeriod.toString());
   console.log("Quorum:", quorum.toString(), "%");
   console.log("Voting Delay:", votingDelay.toString());

   // 3. Check contract connections
   const timelockAddress = await governorProxy.timelock();
   const votesAddress = await governorProxy.token();
   const nftAddress = await governorProxy.nftContract();
   console.log("Timelock address in Governor:", timelockAddress);
   console.log("Votes address in Governor:", votesAddress);
   console.log("NFT address in Governor:", nftAddress);
   ```

4. **Contract Verification**
   ```bash
   # Verify ZroopVotes
   npx hardhat verify --network forma $ZROOP_VOTES_ADDRESS $NFT_CONTRACT_ADDRESS

   # Verify Timelock
   npx hardhat verify --network forma $TIMELOCK_ADDRESS $MIN_DELAY $TEMP_GOVERNOR_ADDRESS

   # Verify Governor Implementation
   npx hardhat verify --network forma $GOVERNOR_IMPLEMENTATION_ADDRESS

   # Verify Governor Proxy
   npx hardhat verify --network forma $GOVERNOR_PROXY_ADDRESS $IMPLEMENTATION_ADDRESS "$INITIALIZE_PARAMS"
   ```

### Delegation System

1. **Purpose**
   - Enable expert participation in governance
   - Improve governance efficiency
   - Allow representation of interests
   - Support temporary vote transfer
   - Enable professional governance management

2. **Security Measures**
   ```javascript
   const MAX_DELEGATIONS = 5;        // Maximum number of delegates per user
   const DELEGATION_LOCK_PERIOD = 1;  // Lock period in days
   ```

   These limits prevent:
   - Flash-delegation attacks
   - Mid-voting delegation changes
   - Cyclic delegation schemes

3. **Delegation Flow**
   ```javascript
   // Direct delegation
   await zroopVotes.delegate(delegateeAddress);

   // Delegation with signature
   const signature = await delegator.signMessage(
     ethers.utils.arrayify(
       ethers.utils.keccak256(
         ethers.utils.defaultAbiCoder.encode(
           ["address", "uint256", "uint256"],
           [delegatee, nonce, expiry]
         )
       )
     )
   );
   await zroopVotes.delegateBySig(delegatee, nonce, expiry, v, r, s);
   ```

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
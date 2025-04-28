// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/governance/GovernorUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/governance/extensions/GovernorSettingsUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/governance/extensions/GovernorCountingSimpleUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/governance/extensions/GovernorVotesUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/governance/extensions/GovernorVotesQuorumFractionUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/governance/extensions/GovernorTimelockControlUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts-upgradeable/utils/cryptography/EIP712Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "./ZroopTimelock.sol";

/**
 * @title ZroopGovernor
 * @dev Main governance contract that handles proposal creation, voting, and execution.
 * This contract implements a complete governance system with NFT-based voting power,
 * proposal signing, and timelock execution.
 */
contract ZroopGovernor is
    GovernorUpgradeable,
    GovernorSettingsUpgradeable,
    GovernorCountingSimpleUpgradeable,
    GovernorVotesUpgradeable,
    GovernorVotesQuorumFractionUpgradeable,
    GovernorTimelockControlUpgradeable,
    ReentrancyGuardUpgradeable,
    PausableUpgradeable,
    EIP712Upgradeable,
    Initializable,
    UUPSUpgradeable
{
    using ECDSA for bytes32;

    /**
     * @dev Structure for storing proposal information
     */
    struct Proposal {
        uint256 id;
        address proposer;
        uint256 deposit;
        string[] options;
        mapping(address => uint256) votes;
        mapping(uint256 => uint256) optionVotes;
        bool executed;
        bool depositReturned;
        bool cancelled;
        uint256 startTime;
        uint256 endTime;
        bytes32 timelockId;
        uint256 requiredSignatures;
        uint256 signatureCount;
        mapping(address => bool) signatures;
    }

    /**
     * @dev Structure for storing delegation information
     */
    struct Delegation {
        address delegate;
        uint256 timestamp;
        uint256 nonce;
    }

    // Network parameters
    uint256 public constant MIN_DEPOSIT_SKETCHPAD = 0.1e18; // 0.1 TIA
    uint256 public constant VOTING_PERIOD_SKETCHPAD = 1 days;
    uint256 public constant QUORUM_SKETCHPAD = 4; // 4%

    uint256 public constant MIN_DEPOSIT_FORMA = 10e18; // 10 TIA
    uint256 public constant VOTING_PERIOD_FORMA = 7 days;
    uint256 public constant QUORUM_FORMA = 10; // 10%

    // System parameters
    uint256 public constant MAX_PROPOSALS = 100;
    uint256 public constant MIN_OPTIONS = 3;
    uint256 public constant MAX_OPTIONS = 10;
    uint256 public constant DELEGATION_LOCK_PERIOD = 1 days;
    uint256 public constant MAX_SIGNATURES = 10;
    uint256 public constant MAX_DELEGATIONS = 5;
    
    // State variables
    mapping(uint256 => Proposal) public proposals;
    mapping(address => Delegation) public delegations;
    mapping(address => uint256) public nonces;
    mapping(address => uint256) public delegationCount;
    uint256 public proposalCount;
    IERC721 public nftContract;
    bool public isMainnet;
    address public treasury;
    ZroopTimelock public timelock;

    // EIP712 type hashes
    bytes32 private constant DELEGATION_TYPEHASH = keccak256(
        "Delegation(address delegate,uint256 nonce,uint256 expiry)"
    );
    bytes32 private constant VOTE_TYPEHASH = keccak256(
        "Vote(uint256 proposalId,uint256 optionIndex,uint256 nonce,uint256 expiry)"
    );
    bytes32 private constant PROPOSAL_TYPEHASH = keccak256(
        "Proposal(uint256 proposalId,uint256 nonce,uint256 expiry)"
    );

    // Events
    event ProposalCreated(uint256 indexed proposalId, address indexed proposer, string[] options, uint256 deposit);
    event Voted(uint256 indexed proposalId, address indexed voter, uint256 optionIndex, uint256 weight);
    event DepositReturned(uint256 indexed proposalId, address indexed proposer, uint256 amount);
    event DepositForfeited(uint256 indexed proposalId, address indexed proposer, uint256 amount);
    event VotingPeriodChanged(uint256 newPeriod);
    event NetworkChanged(bool isMainnet);
    event QuorumChanged(uint256 newQuorum);
    event NFTContractChanged(address newNFTContract);
    event DelegationSet(address indexed delegator, address indexed delegate);
    event DelegationRemoved(address indexed delegator);
    event ProposalCancelled(uint256 indexed proposalId, address indexed proposer);
    event ContractPaused(address indexed by);
    event ContractUnpaused(address indexed by);
    event TimelockOperationScheduled(uint256 indexed proposalId, bytes32 indexed timelockId);
    event TimelockOperationExecuted(uint256 indexed proposalId, bytes32 indexed timelockId);
    event ProposalSigned(uint256 indexed proposalId, address indexed signer);
    event RequiredSignaturesChanged(uint256 indexed proposalId, uint256 oldRequired, uint256 newRequired);
    event VoteCancelled(uint256 indexed proposalId, address indexed voter);
    event ProposalVetoed(uint256 indexed proposalId, address indexed vetoer);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /**
     * @dev Initializes the contract with required parameters
     * @param _token The voting token contract
     * @param _timelock The timelock contract
     * @param _votingDelay The delay before voting starts
     * @param _votingPeriod The duration of the voting period
     * @param _quorumPercentage The percentage of votes required for quorum
     * @param _nftContract The NFT contract for voting power
     * @param _isMainnet Whether the contract is deployed on mainnet
     * @param _treasury The treasury address for deposits
     */
    function initialize(
        IVotesUpgradeable _token,
        ZroopTimelock _timelock,
        uint48 _votingDelay,
        uint32 _votingPeriod,
        uint256 _quorumPercentage,
        address _nftContract,
        bool _isMainnet,
        address _treasury
    ) public initializer {
        require(_nftContract != address(0), "NFT contract address cannot be zero");
        require(_treasury != address(0), "Treasury address cannot be zero");

        __Governor_init("ZroopGovernor");
        __GovernorSettings_init(_votingDelay, _votingPeriod, 0);
        __GovernorVotes_init(_token);
        __GovernorVotesQuorumFraction_init(_quorumPercentage);
        __GovernorTimelockControl_init(_timelock);
        __EIP712_init("ZroopGovernor", "1");
        __UUPSUpgradeable_init();

        nftContract = IERC721(_nftContract);
        isMainnet = _isMainnet;
        treasury = _treasury;
        timelock = _timelock;
    }

    /**
     * @dev Authorizes contract upgrades
     * @param newImplementation The address of the new implementation
     */
    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

    /**
     * @dev Gets the minimum deposit required for proposals
     * @return The minimum deposit amount
     */
    function getMinDeposit() public view returns (uint256) {
        return isMainnet ? MIN_DEPOSIT_FORMA : MIN_DEPOSIT_SKETCHPAD;
    }

    /**
     * @dev Gets the voting period duration
     * @return The voting period in seconds
     */
    function getVotingPeriod() public view returns (uint256) {
        return isMainnet ? VOTING_PERIOD_FORMA : VOTING_PERIOD_SKETCHPAD;
    }

    /**
     * @dev Gets the quorum percentage
     * @return The quorum percentage
     */
    function getQuorumPercentage() public view returns (uint256) {
        return isMainnet ? QUORUM_FORMA : QUORUM_SKETCHPAD;
    }

    /**
     * @dev Creates a new proposal
     * @param options Array of voting options
     * @param description Description of the proposal
     * @param targets Array of target addresses for execution
     * @param values Array of values to send with execution
     * @param calldatas Array of calldata for execution
     * @param requiredSignatures Number of required signatures
     * @return The ID of the created proposal
     */
    function createProposal(
        string[] memory options,
        string memory description,
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        uint256 requiredSignatures
    ) external payable nonReentrant whenNotPaused returns (uint256) {
        require(msg.value >= getMinDeposit(), "Deposit too low");
        require(options.length >= MIN_OPTIONS && options.length <= MAX_OPTIONS, "Invalid options count");
        require(nftContract.balanceOf(msg.sender) > 0, "Must own NFT to create proposal");
        require(proposalCount < MAX_PROPOSALS, "Max proposals reached");
        require(targets.length == values.length && targets.length == calldatas.length, "Invalid proposal parameters");
        require(requiredSignatures > 0 && requiredSignatures <= MAX_SIGNATURES, "Invalid required signatures");

        uint256 proposalId = proposalCount++;
        Proposal storage proposal = proposals[proposalId];
        proposal.id = proposalId;
        proposal.proposer = msg.sender;
        proposal.deposit = msg.value;
        proposal.options = options;
        proposal.executed = false;
        proposal.depositReturned = false;
        proposal.cancelled = false;
        proposal.startTime = block.timestamp;
        proposal.endTime = block.timestamp + getVotingPeriod();
        proposal.requiredSignatures = requiredSignatures;

        bytes32 timelockId = timelock.hashOperation(
            targets[0],
            values[0],
            calldatas[0],
            bytes32(0),
            bytes32(proposalId)
        );
        proposal.timelockId = timelockId;

        emit ProposalCreated(proposalId, msg.sender, options, msg.value);
        emit TimelockOperationScheduled(proposalId, timelockId);

        return proposalId;
    }

    /**
     * @dev Casts a vote on a proposal
     * @param proposalId The ID of the proposal
     * @param optionIndex The index of the selected option
     * @param v The v parameter of the signature
     * @param r The r parameter of the signature
     * @param s The s parameter of the signature
     */
    function vote(
        uint256 proposalId,
        uint256 optionIndex,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external nonReentrant whenNotPaused {
        require(optionIndex < proposals[proposalId].options.length, "Invalid option");
        require(!proposals[proposalId].executed, "Proposal already executed");
        require(!proposals[proposalId].cancelled, "Proposal was cancelled");
        require(block.timestamp <= proposals[proposalId].endTime, "Voting period ended");

        address voter = msg.sender;
        if (v != 0 || r != bytes32(0) || s != bytes32(0)) {
            bytes32 structHash = keccak256(
                abi.encode(
                    VOTE_TYPEHASH,
                    proposalId,
                    optionIndex,
                    nonces[msg.sender]++,
                    block.timestamp + 1 hours
                )
            );
            bytes32 hash = _hashTypedDataV4(structHash);
            voter = ECDSA.recover(hash, v, r, s);
            require(nftContract.balanceOf(voter) > 0, "Signer must own NFT");
        } else {
            require(nftContract.balanceOf(voter) > 0, "Must own NFT to vote");
        }

        if (delegations[voter].delegate != address(0)) {
            voter = delegations[voter].delegate;
        }

        uint256 weight = nftContract.balanceOf(voter);
        proposals[proposalId].votes[voter] = weight;
        proposals[proposalId].optionVotes[optionIndex] += weight;

        emit Voted(proposalId, voter, optionIndex, weight);
    }

    /**
     * @dev Executes a proposal after voting period
     * @param proposalId The ID of the proposal to execute
     */
    function executeProposal(uint256 proposalId) external nonReentrant whenNotPaused {
        Proposal storage proposal = proposals[proposalId];
        require(!proposal.executed, "Proposal already executed");
        require(!proposal.cancelled, "Proposal was cancelled");
        require(block.timestamp > proposal.endTime, "Voting period not ended");

        uint256 totalVotes = 0;
        for (uint256 i = 0; i < proposal.options.length; i++) {
            totalVotes += proposal.optionVotes[i];
        }

        proposal.executed = true;

        if (totalVotes >= quorum(block.number)) {
            (bool success, ) = proposal.proposer.call{value: proposal.deposit}("");
            require(success, "Deposit return failed");
            proposal.depositReturned = true;
            emit DepositReturned(proposalId, proposal.proposer, proposal.deposit);

            timelock.execute(
                address(this),
                0,
                abi.encodeWithSignature("execute(uint256)", proposalId),
                bytes32(0),
                bytes32(proposalId)
            );
            emit TimelockOperationExecuted(proposalId, proposal.timelockId);
        } else {
            (bool success, ) = treasury.call{value: proposal.deposit}("");
            require(success, "Deposit transfer failed");
            emit DepositForfeited(proposalId, proposal.proposer, proposal.deposit);
        }
    }

    /**
     * @dev Cancels a proposal
     * @param proposalId The ID of the proposal to cancel
     */
    function cancelProposal(uint256 proposalId) external nonReentrant whenNotPaused {
        Proposal storage proposal = proposals[proposalId];
        require(msg.sender == proposal.proposer, "Only proposer can cancel");
        require(!proposal.executed, "Proposal already executed");
        require(!proposal.cancelled, "Proposal already cancelled");
        require(block.timestamp <= proposal.endTime, "Voting period ended");

        proposal.cancelled = true;
        (bool success, ) = proposal.proposer.call{value: proposal.deposit}("");
        require(success, "Deposit return failed");
        proposal.depositReturned = true;

        timelock.cancel(proposal.timelockId);

        emit ProposalCancelled(proposalId, proposal.proposer);
        emit DepositReturned(proposalId, proposal.proposer, proposal.deposit);
    }

    /**
     * @dev Sets a delegation for voting
     * @param delegate The address to delegate votes to
     * @param v The v parameter of the signature
     * @param r The r parameter of the signature
     * @param s The s parameter of the signature
     */
    function setDelegation(
        address delegate,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external whenNotPaused {
        require(delegate != address(0), "Invalid delegate address");
        require(delegate != msg.sender, "Cannot delegate to self");
        require(delegationCount[msg.sender] < MAX_DELEGATIONS, "Max delegations reached");

        address delegator = msg.sender;
        if (v != 0 || r != bytes32(0) || s != bytes32(0)) {
            bytes32 structHash = keccak256(
                abi.encode(
                    DELEGATION_TYPEHASH,
                    delegate,
                    nonces[msg.sender]++,
                    block.timestamp + 1 hours
                )
            );
            bytes32 hash = _hashTypedDataV4(structHash);
            delegator = ECDSA.recover(hash, v, r, s);
            require(nftContract.balanceOf(delegator) > 0, "Signer must own NFT");
        } else {
            require(nftContract.balanceOf(delegator) > 0, "Must own NFT to delegate");
        }

        delegations[delegator] = Delegation({
            delegate: delegate,
            timestamp: block.timestamp,
            nonce: nonces[delegator]
        });
        delegationCount[delegator]++;

        emit DelegationSet(delegator, delegate);
    }

    /**
     * @dev Removes a delegation
     */
    function removeDelegation() external whenNotPaused {
        require(delegations[msg.sender].delegate != address(0), "No delegation set");
        require(block.timestamp >= delegations[msg.sender].timestamp + DELEGATION_LOCK_PERIOD, "Delegation locked");

        delete delegations[msg.sender];
        delegationCount[msg.sender]--;
        emit DelegationRemoved(msg.sender);
    }

    /**
     * @dev Signs a proposal
     * @param proposalId The ID of the proposal to sign
     * @param v The v parameter of the signature
     * @param r The r parameter of the signature
     * @param s The s parameter of the signature
     */
    function signProposal(
        uint256 proposalId,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external nonReentrant whenNotPaused {
        Proposal storage proposal = proposals[proposalId];
        require(!proposal.executed, "Proposal already executed");
        require(!proposal.cancelled, "Proposal was cancelled");
        require(proposal.signatureCount < MAX_SIGNATURES, "Max signatures reached");

        address signer = msg.sender;
        if (v != 0 || r != bytes32(0) || s != bytes32(0)) {
            bytes32 structHash = keccak256(
                abi.encode(
                    PROPOSAL_TYPEHASH,
                    proposalId,
                    nonces[msg.sender]++,
                    block.timestamp + 1 hours
                )
            );
            bytes32 hash = _hashTypedDataV4(structHash);
            signer = ECDSA.recover(hash, v, r, s);
            require(nftContract.balanceOf(signer) > 0, "Signer must own NFT");
        } else {
            require(nftContract.balanceOf(signer) > 0, "Must own NFT to sign");
        }

        require(!proposal.signatures[signer], "Already signed");
        proposal.signatures[signer] = true;
        proposal.signatureCount++;

        emit ProposalSigned(proposalId, signer);
    }

    /**
     * @dev Sets the voting period
     * @param newPeriod The new voting period in seconds
     */
    function setVotingPeriod(uint256 newPeriod) external onlyOwner {
        require(newPeriod > 0, "Invalid voting period");
        _setVotingPeriod(newPeriod);
        emit VotingPeriodChanged(newPeriod);
    }

    /**
     * @dev Sets the quorum percentage
     * @param newQuorum The new quorum percentage
     */
    function setQuorum(uint256 newQuorum) external onlyOwner {
        require(newQuorum > 0 && newQuorum <= 100, "Invalid quorum percentage");
        _setQuorumNumerator(newQuorum);
        emit QuorumChanged(newQuorum);
    }

    /**
     * @dev Sets the NFT contract
     * @param newNFTContract The address of the new NFT contract
     */
    function setNFTContract(address newNFTContract) external onlyOwner {
        require(newNFTContract != address(0), "Invalid NFT contract address");
        nftContract = IERC721(newNFTContract);
        emit NFTContractChanged(newNFTContract);
    }

    /**
     * @dev Sets the network type
     * @param _isMainnet Whether the contract is on mainnet
     */
    function setNetwork(bool _isMainnet) external onlyOwner {
        isMainnet = _isMainnet;
        emit NetworkChanged(_isMainnet);
    }

    /**
     * @dev Sets the treasury address
     * @param newTreasury The address of the new treasury
     */
    function setTreasury(address newTreasury) external onlyOwner {
        require(newTreasury != address(0), "Invalid treasury address");
        treasury = newTreasury;
    }

    /**
     * @dev Pauses the contract
     */
    function pause() external onlyOwner {
        _pause();
        emit ContractPaused(msg.sender);
    }

    /**
     * @dev Unpauses the contract
     */
    function unpause() external onlyOwner {
        _unpause();
        emit ContractUnpaused(msg.sender);
    }

    /**
     * @dev Gets information about a proposal
     * @param proposalId The ID of the proposal
     * @return id The proposal ID
     * @return proposer The address of the proposer
     * @return deposit The deposit amount
     * @return options Array of voting options
     * @return executed Whether the proposal is executed
     * @return depositReturned Whether the deposit is returned
     * @return cancelled Whether the proposal is cancelled
     * @return startTime The start time of the proposal
     * @return endTime The end time of the proposal
     * @return timelockId The timelock operation ID
     * @return requiredSignatures The number of required signatures
     * @return signatureCount The number of signatures received
     * @return votes Array of votes for each option
     * @return signers Array of signers
     */
    function getProposalInfo(uint256 proposalId) external view returns (
        uint256 id,
        address proposer,
        uint256 deposit,
        string[] memory options,
        bool executed,
        bool depositReturned,
        bool cancelled,
        uint256 startTime,
        uint256 endTime,
        bytes32 timelockId,
        uint256 requiredSignatures,
        uint256 signatureCount,
        uint256[] memory votes,
        address[] memory signers
    ) {
        Proposal storage proposal = proposals[proposalId];
        votes = new uint256[](proposal.options.length);
        for (uint256 i = 0; i < proposal.options.length; i++) {
            votes[i] = proposal.optionVotes[i];
        }

        signers = new address[](proposal.signatureCount);
        uint256 count = 0;
        for (uint256 i = 0; i < MAX_SIGNATURES; i++) {
            if (proposal.signatures[signers[i]]) {
                signers[count] = signers[i];
                count++;
            }
        }

        return (
            proposal.id,
            proposal.proposer,
            proposal.deposit,
            proposal.options,
            proposal.executed,
            proposal.depositReturned,
            proposal.cancelled,
            proposal.startTime,
            proposal.endTime,
            proposal.timelockId,
            proposal.requiredSignatures,
            proposal.signatureCount,
            votes,
            signers
        );
    }

    /**
     * @dev Gets information about a delegation
     * @param delegator The address of the delegator
     * @return delegate The address of the delegate
     * @return timestamp The timestamp of the delegation
     */
    function getDelegationInfo(address delegator) external view returns (address delegate, uint256 timestamp) {
        Delegation storage delegation = delegations[delegator];
        return (delegation.delegate, delegation.timestamp);
    }

    /**
     * @dev Cancels a vote on a proposal
     * @param proposalId The ID of the proposal
     */
    function cancelVote(uint256 proposalId) external nonReentrant whenNotPaused {
        Proposal storage proposal = proposals[proposalId];
        require(!proposal.executed, "Proposal already executed");
        require(!proposal.cancelled, "Proposal was cancelled");
        require(block.timestamp <= proposal.endTime, "Voting period ended");
        require(proposal.votes[msg.sender] > 0, "No vote to cancel");

        uint256 voteWeight = proposal.votes[msg.sender];
        proposal.votes[msg.sender] = 0;
        proposal.optionVotes[proposal.votes[msg.sender]] -= voteWeight;

        emit VoteCancelled(proposalId, msg.sender);
    }

    /**
     * @dev Vetoes a proposal
     * @param proposalId The ID of the proposal to veto
     */
    function vetoProposal(uint256 proposalId) external onlyOwner {
        Proposal storage proposal = proposals[proposalId];
        require(!proposal.executed, "Proposal already executed");
        require(!proposal.cancelled, "Proposal was cancelled");
        require(block.timestamp <= proposal.endTime, "Voting period ended");

        proposal.cancelled = true;
        (bool success, ) = proposal.proposer.call{value: proposal.deposit}("");
        require(success, "Deposit return failed");
        proposal.depositReturned = true;

        timelock.cancel(proposal.timelockId);

        emit ProposalVetoed(proposalId, msg.sender);
        emit DepositReturned(proposalId, proposal.proposer, proposal.deposit);
    }

    // Override existing functions
    function votingDelay()
        public
        view
        override(GovernorUpgradeable, GovernorSettingsUpgradeable)
        returns (uint256)
    {
        return super.votingDelay();
    }

    function votingPeriod()
        public
        view
        override(GovernorUpgradeable, GovernorSettingsUpgradeable)
        returns (uint256)
    {
        return super.votingPeriod();
    }

    function quorum(uint256 blockNumber)
        public
        view
        override(GovernorUpgradeable, GovernorVotesQuorumFractionUpgradeable)
        returns (uint256)
    {
        return super.quorum(blockNumber);
    }

    function state(uint256 proposalId)
        public
        view
        override(GovernorUpgradeable, GovernorTimelockControlUpgradeable)
        returns (ProposalState)
    {
        return super.state(proposalId);
    }

    function _execute(
        uint256 proposalId,
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    ) internal override(GovernorUpgradeable, GovernorTimelockControlUpgradeable) {
        super._execute(proposalId, targets, values, calldatas, descriptionHash);
    }

    function _cancel(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    ) internal override(GovernorUpgradeable, GovernorTimelockControlUpgradeable) returns (uint256) {
        return super._cancel(targets, values, calldatas, descriptionHash);
    }

    function _executor()
        internal
        view
        override(GovernorUpgradeable, GovernorTimelockControlUpgradeable)
        returns (address)
    {
        return super._executor();
    }
} 
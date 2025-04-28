// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

/**
 * @title ZroopVotes
 * @dev Manages voting power based on NFT ownership. This contract calculates voting power
 * based on the number of NFTs owned by an address and allows locking of voting power
 * for a specified period.
 */
contract ZroopVotes is Ownable, Pausable {
    /**
     * @dev Emitted when voting power is locked
     * @param account The address that locked voting power
     * @param amount The amount of voting power locked
     * @param unlockTime The timestamp when voting power can be unlocked
     */
    event VotingPowerLocked(address indexed account, uint256 amount, uint256 unlockTime);

    /**
     * @dev Emitted when voting power is unlocked
     * @param account The address that unlocked voting power
     * @param amount The amount of voting power unlocked
     */
    event VotingPowerUnlocked(address indexed account, uint256 amount);

    /**
     * @dev Emitted when the NFT contract is set
     * @param nftContract The address of the NFT contract
     */
    event NFTContractSet(address indexed nftContract);

    /// @dev The NFT contract that determines voting power
    IERC721 public nftContract;

    /// @dev Mapping of locked voting power per address
    mapping(address => uint256) public lockedVotingPower;

    /// @dev Mapping of unlock timestamps per address
    mapping(address => uint256) public unlockTimes;

    /// @dev The period for which voting power is locked
    uint256 public constant LOCK_PERIOD = 7 days;

    /// @dev The amount of voting power per NFT
    uint256 public constant VOTES_PER_NFT = 1e18; // 1 vote per NFT

    /**
     * @dev Constructor initializes the contract with the owner
     */
    constructor() Ownable(msg.sender) {}

    /**
     * @dev Sets the NFT contract address
     * @param _nftContract The address of the NFT contract
     */
    function setNFTContract(address _nftContract) external onlyOwner {
        require(_nftContract != address(0), "Invalid NFT contract address");
        nftContract = IERC721(_nftContract);
        emit NFTContractSet(_nftContract);
    }

    /**
     * @dev Calculates the voting power of an address based on NFT ownership
     * @param account The address to check
     * @return The voting power of the address
     */
    function getVotingPower(address account) external view returns (uint256) {
        if (address(nftContract) == address(0)) return 0;
        return nftContract.balanceOf(account) * VOTES_PER_NFT;
    }

    /**
     * @dev Calculates the available voting power of an address
     * @param account The address to check
     * @return The available voting power
     */
    function getAvailableVotingPower(address account) external view returns (uint256) {
        uint256 totalPower = getVotingPower(account);
        uint256 locked = lockedVotingPower[account];
        return totalPower > locked ? totalPower - locked : 0;
    }

    /**
     * @dev Locks voting power for a period
     * @param amount The amount of voting power to lock
     */
    function lockVotingPower(uint256 amount) external whenNotPaused {
        require(amount > 0, "Amount must be greater than 0");
        require(getAvailableVotingPower(msg.sender) >= amount, "Insufficient voting power");
        
        lockedVotingPower[msg.sender] += amount;
        unlockTimes[msg.sender] = block.timestamp + LOCK_PERIOD;
        
        emit VotingPowerLocked(msg.sender, amount, unlockTimes[msg.sender]);
    }

    /**
     * @dev Unlocks voting power after the lock period
     */
    function unlockVotingPower() external whenNotPaused {
        require(lockedVotingPower[msg.sender] > 0, "No locked voting power");
        require(block.timestamp >= unlockTimes[msg.sender], "Voting power still locked");
        
        uint256 amount = lockedVotingPower[msg.sender];
        lockedVotingPower[msg.sender] = 0;
        unlockTimes[msg.sender] = 0;
        
        emit VotingPowerUnlocked(msg.sender, amount);
    }

    /**
     * @dev Gets information about locked voting power
     * @param account The address to check
     * @return locked The amount of locked voting power
     * @return unlockTime The timestamp when voting power can be unlocked
     */
    function getLockInfo(address account) external view returns (uint256 locked, uint256 unlockTime) {
        return (lockedVotingPower[account], unlockTimes[account]);
    }

    /**
     * @dev Pauses the contract
     */
    function pause() external onlyOwner {
        _pause();
    }

    /**
     * @dev Unpauses the contract
     */
    function unpause() external onlyOwner {
        _unpause();
    }
} 
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/governance/TimelockController.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";

/**
 * @title ZroopTimelock
 * @notice Timelock contract for managing delayed execution of governance proposals
 * @dev Extends TimelockController with pause functionality and delay constraints
 *
 * Key features:
 * - Fixed minimum (1 day) and maximum (30 days) delays for operations
 * - Ability to pause operations through pause mechanism
 * - Integration with Governor contract for proposal management
 * - Role distribution between Governor and executors
 */
contract ZroopTimelock is TimelockController, Pausable {
    // Constants for time delay constraints
    uint256 public constant MIN_DELAY = 1 days;    // Minimum delay - 1 day
    uint256 public constant MAX_DELAY = 30 days;   // Maximum delay - 30 days

    /**
     * @notice Initializes the contract with specified parameters
     * @dev Sets up base parameters and distributes roles
     * @param minDelay Minimum delay for operations (must be between MIN_DELAY and MAX_DELAY)
     * @param governorAddress Address of the Governor contract that will have PROPOSER role
     */
    constructor(
        uint256 minDelay,
        address governorAddress
    ) TimelockController(
        minDelay,
        new address[](0), // proposers will be set in initialize
        new address[](0), // executors will be set in initialize
        address(this)     // admin is the timelock itself
    ) {
        require(minDelay >= MIN_DELAY, "Delay too short");
        require(minDelay <= MAX_DELAY, "Delay too long");
        
        // Setup roles
        _grantRole(PROPOSER_ROLE, governorAddress);    // Only Governor can propose
        _grantRole(EXECUTOR_ROLE, address(0));         // Anyone can execute
        _grantRole(CANCELLER_ROLE, governorAddress);   // Only Governor can cancel
    }

    /**
     * @notice Schedules execution of a single operation
     * @dev Checks that contract is not paused and delay is within bounds
     */
    function schedule(
        address target,
        uint256 value,
        bytes calldata data,
        bytes32 predecessor,
        bytes32 salt,
        uint256 delay
    ) public virtual override whenNotPaused {
        require(delay >= MIN_DELAY, "Delay too short");
        require(delay <= MAX_DELAY, "Delay too long");
        super.schedule(target, value, data, predecessor, salt, delay);
    }

    /**
     * @notice Schedules execution of a batch of operations
     * @dev Checks that contract is not paused and delay is within bounds
     */
    function scheduleBatch(
        address[] calldata targets,
        uint256[] calldata values,
        bytes[] calldata payloads,
        bytes32 predecessor,
        bytes32 salt,
        uint256 delay
    ) public virtual override whenNotPaused {
        require(delay >= MIN_DELAY, "Delay too short");
        require(delay <= MAX_DELAY, "Delay too long");
        super.scheduleBatch(targets, values, payloads, predecessor, salt, delay);
    }

    /**
     * @notice Executes a scheduled operation
     * @dev Checks that contract is not paused
     */
    function execute(
        address target,
        uint256 value,
        bytes calldata payload,
        bytes32 predecessor,
        bytes32 salt
    ) public payable virtual override whenNotPaused {
        super.execute(target, value, payload, predecessor, salt);
    }

    /**
     * @notice Executes a scheduled batch of operations
     * @dev Checks that contract is not paused
     */
    function executeBatch(
        address[] calldata targets,
        uint256[] calldata values,
        bytes[] calldata payloads,
        bytes32 predecessor,
        bytes32 salt
    ) public payable virtual override whenNotPaused {
        super.executeBatch(targets, values, payloads, predecessor, salt);
    }

    /**
     * @notice Pauses the contract
     * @dev Can only be called by admin
     */
    function pause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _pause();
    }

    /**
     * @notice Unpauses the contract
     * @dev Can only be called by admin
     */
    function unpause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _unpause();
    }
} 
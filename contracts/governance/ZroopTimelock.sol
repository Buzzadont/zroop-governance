// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/governance/TimelockController.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

/**
 * @title ZroopTimelock
 * @dev Implements a timelock mechanism for secure execution of governance proposals.
 * This contract ensures that approved proposals are not executed immediately,
 * providing time for review and potential cancellation.
 */
contract ZroopTimelock is TimelockController, ReentrancyGuard, EIP712, Pausable {
    using ECDSA for bytes32;

    bytes32 public constant PROPOSER_ROLE = keccak256("PROPOSER_ROLE");
    bytes32 public constant EXECUTOR_ROLE = keccak256("EXECUTOR_ROLE");
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

    // Minimum delay for operations
    uint256 public constant MIN_DELAY = 1 days;
    // Maximum delay for operations
    uint256 public constant MAX_DELAY = 30 days;
    // Default delay for operations
    uint256 public constant DEFAULT_DELAY = 24 hours;

    // Mapping of operation hashes to their timestamps
    mapping(bytes32 => uint256) public operationTimestamps;
    // Mapping of operation hashes to their delays
    mapping(bytes32 => uint256) public operationDelays;
    // Mapping of operation hashes to their status
    mapping(bytes32 => bool) public operationExecuted;
    // Mapping of operation hashes to their signatures
    mapping(bytes32 => mapping(address => bool)) public operationSignatures;
    // Mapping of operation hashes to their required signatures
    mapping(bytes32 => uint256) public operationRequiredSignatures;

    // EIP712 type hashes
    bytes32 private constant OPERATION_TYPEHASH = keccak256(
        "Operation(address target,uint256 value,bytes data,bytes32 predecessor,bytes32 salt,uint256 delay)"
    );

    /**
     * @dev Emitted when an operation is cancelled
     * @param operationId The ID of the cancelled operation
     * @param canceller The address that cancelled the operation
     */
    event OperationCancelled(bytes32 indexed operationId, address indexed canceller);

    /**
     * @dev Emitted when an operation is executed
     * @param operationId The ID of the executed operation
     * @param executor The address that executed the operation
     */
    event OperationExecuted(bytes32 indexed operationId, address indexed executor);

    /**
     * @dev Emitted when an operation is scheduled
     * @param operationId The ID of the scheduled operation
     * @param scheduler The address that scheduled the operation
     */
    event OperationScheduled(bytes32 indexed operationId, address indexed scheduler);

    event DelayChanged(
        bytes32 indexed operationId,
        uint256 oldDelay,
        uint256 newDelay
    );
    event OperationSigned(
        bytes32 indexed operationId,
        address indexed signer
    );
    event RequiredSignaturesChanged(
        bytes32 indexed operationId,
        uint256 oldRequired,
        uint256 newRequired
    );

    /**
     * @dev Constructor initializes the timelock with minimum delay and roles
     * @param minDelay The minimum delay for operations
     * @param proposers Array of addresses that can propose operations
     * @param executors Array of addresses that can execute operations
     */
    constructor(
        uint256 minDelay,
        address[] memory proposers,
        address[] memory executors
    )
        TimelockController(minDelay, proposers, executors)
        EIP712("ZroopTimelock", "1")
    {
        require(minDelay >= MIN_DELAY, "Delay too short");
        require(minDelay <= MAX_DELAY, "Delay too long");
    }

    /**
     * @dev Schedules an operation for execution after a delay
     * @param target The target address for the operation
     * @param value The value to send with the operation
     * @param data The calldata for the operation
     * @param predecessor The predecessor operation
     * @param salt The salt for the operation
     * @param delay The delay before execution
     */
    function schedule(
        address target,
        uint256 value,
        bytes calldata data,
        bytes32 predecessor,
        bytes32 salt,
        uint256 delay
    ) public override whenNotPaused {
        require(delay >= MIN_DELAY, "Delay too short");
        require(delay <= MAX_DELAY, "Delay too long");
        super.schedule(target, value, data, predecessor, salt, delay);
        emit OperationScheduled(salt, msg.sender);
    }

    /**
     * @dev Executes a scheduled operation
     * @param target The target address for the operation
     * @param value The value to send with the operation
     * @param data The calldata for the operation
     * @param predecessor The predecessor operation
     * @param salt The salt for the operation
     */
    function execute(
        address target,
        uint256 value,
        bytes calldata data,
        bytes32 predecessor,
        bytes32 salt
    ) public payable override whenNotPaused {
        super.execute(target, value, data, predecessor, salt);
        emit OperationExecuted(salt, msg.sender);
    }

    /**
     * @dev Cancels a scheduled operation
     * @param id The ID of the operation to cancel
     */
    function cancel(bytes32 id) public override whenNotPaused {
        super.cancel(id);
        emit OperationCancelled(id, msg.sender);
    }

    function changeDelay(
        bytes32 operationId,
        uint256 newDelay
    ) public onlyRole(ADMIN_ROLE) nonReentrant {
        require(operationTimestamps[operationId] > 0, "Operation not scheduled");
        require(!operationExecuted[operationId], "Operation already executed");
        require(newDelay >= MIN_DELAY, "Delay too short");
        require(newDelay <= MAX_DELAY, "Delay too long");

        uint256 oldDelay = operationDelays[operationId];
        operationDelays[operationId] = newDelay;
        operationTimestamps[operationId] = block.timestamp + newDelay;

        emit DelayChanged(operationId, oldDelay, newDelay);
    }

    function signOperation(
        bytes32 operationId
    ) public onlyRole(PROPOSER_ROLE) nonReentrant {
        require(operationTimestamps[operationId] > 0, "Operation not scheduled");
        require(!operationExecuted[operationId], "Operation already executed");
        require(!operationSignatures[operationId][msg.sender], "Already signed");

        operationSignatures[operationId][msg.sender] = true;
        emit OperationSigned(operationId, msg.sender);
    }

    function signOperationBySig(
        bytes32 operationId,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) public nonReentrant {
        require(operationTimestamps[operationId] > 0, "Operation not scheduled");
        require(!operationExecuted[operationId], "Operation already executed");

        bytes32 structHash = keccak256(
            abi.encode(
                OPERATION_TYPEHASH,
                operationId
            )
        );
        bytes32 hash = _hashTypedDataV4(structHash);
        address signer = ECDSA.recover(hash, v, r, s);
        require(hasRole(PROPOSER_ROLE, signer), "Invalid signer");
        require(!operationSignatures[operationId][signer], "Already signed");

        operationSignatures[operationId][signer] = true;
        emit OperationSigned(operationId, signer);
    }

    function setRequiredSignatures(
        bytes32 operationId,
        uint256 newRequired
    ) public onlyRole(ADMIN_ROLE) nonReentrant {
        require(operationTimestamps[operationId] > 0, "Operation not scheduled");
        require(!operationExecuted[operationId], "Operation already executed");
        require(newRequired > 0, "Invalid required signatures");

        uint256 oldRequired = operationRequiredSignatures[operationId];
        operationRequiredSignatures[operationId] = newRequired;

        emit RequiredSignaturesChanged(operationId, oldRequired, newRequired);
    }

    function getOperationStatus(
        bytes32 operationId
    ) public view returns (
        bool scheduled,
        bool executed,
        uint256 timestamp,
        uint256 delay,
        uint256 requiredSignatures,
        uint256 currentSignatures
    ) {
        uint256 signatureCount = 0;
        for (uint256 i = 0; i < getRoleMemberCount(PROPOSER_ROLE); i++) {
            if (operationSignatures[operationId][getRoleMember(PROPOSER_ROLE, i)]) {
                signatureCount++;
            }
        }

        return (
            operationTimestamps[operationId] > 0,
            operationExecuted[operationId],
            operationTimestamps[operationId],
            operationDelays[operationId],
            operationRequiredSignatures[operationId],
            signatureCount
        );
    }

    function getMinDelay() public view returns (uint256) {
        return MIN_DELAY;
    }

    function getMaxDelay() public view returns (uint256) {
        return MAX_DELAY;
    }

    function getDefaultDelay() public view returns (uint256) {
        return DEFAULT_DELAY;
    }

    /**
     * @dev Pauses the contract
     */
    function pause() external onlyRole(TIMELOCK_ADMIN_ROLE) {
        _pause();
    }

    /**
     * @dev Unpauses the contract
     */
    function unpause() external onlyRole(TIMELOCK_ADMIN_ROLE) {
        _unpause();
    }

    /**
     * @dev Gets information about an operation
     * @param id The ID of the operation
     * @return ready Whether the operation is ready for execution
     * @return done Whether the operation has been executed
     * @return timestamp The timestamp when the operation was scheduled
     * @return delay The delay before execution
     */
    function getOperationInfo(bytes32 id) external view returns (
        bool ready,
        bool done,
        uint256 timestamp,
        uint256 delay
    ) {
        return (
            isOperationReady(id),
            isOperationDone(id),
            getTimestamp(id),
            getMinDelay()
        );
    }
} 
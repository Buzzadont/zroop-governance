// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IZroopersFragments {
    function balanceOf(address owner) external view returns (uint256);
    function getVotes(address account) external view returns (uint256);
    function delegates(address delegator) external view returns (address);
    function delegate(address delegatee) external;
    function delegateBySig(
        address delegatee,
        uint256 nonce,
        uint256 expiry,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external;
} 
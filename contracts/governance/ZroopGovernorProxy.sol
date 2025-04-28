// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract ZroopGovernorProxy is ERC1967Proxy, Ownable {
    event ImplementationUpgraded(address indexed oldImplementation, address indexed newImplementation);
    event AdminChanged(address indexed oldAdmin, address indexed newAdmin);

    constructor(
        address _implementation,
        bytes memory _data
    ) ERC1967Proxy(_implementation, _data) Ownable(msg.sender) {}

    function upgradeTo(address newImplementation) external onlyOwner {
        address oldImplementation = _getImplementation();
        _upgradeTo(newImplementation);
        emit ImplementationUpgraded(oldImplementation, newImplementation);
    }

    function upgradeToAndCall(
        address newImplementation,
        bytes memory data
    ) external onlyOwner {
        address oldImplementation = _getImplementation();
        _upgradeToAndCall(newImplementation, data, true);
        emit ImplementationUpgraded(oldImplementation, newImplementation);
    }

    function changeAdmin(address newAdmin) external onlyOwner {
        address oldAdmin = _getAdmin();
        _changeAdmin(newAdmin);
        emit AdminChanged(oldAdmin, newAdmin);
    }

    function getImplementation() external view returns (address) {
        return _getImplementation();
    }

    function getAdmin() external view returns (address) {
        return _getAdmin();
    }
} 
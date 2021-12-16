// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

contract Shine is Initializable, ERC20Upgradeable, UUPSUpgradeable, OwnableUpgradeable {
    function initialize() public initializer {
        __ERC20_init("Shine", "SHINE");
        __Ownable_init();

        _mint(msg.sender, 10000000000 * 10 ** decimals());
    }

    function _authorizeUpgrade(address newImplementation) internal
        override
        onlyOwner {}
}

contract ShineV2 is Shine {
    function version() pure public returns (string memory) {
        return "v1.0.0";
    }
}
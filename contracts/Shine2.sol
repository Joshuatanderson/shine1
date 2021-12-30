// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "./Shine.sol";

contract ShineV2 is Shine {
    function version() pure public returns (string memory) {
        return "v1.0.1";
    }
}
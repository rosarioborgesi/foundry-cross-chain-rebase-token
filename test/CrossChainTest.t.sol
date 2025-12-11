// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Test, console} from "forge-std/Test.sol";
import {RebaseToken} from "../src/RebaseToken.sol";
import {RebaseTokenPool} from "../src/RebaseTokenPool.sol";
import {Vault} from "../src/Vault.sol";
import {IRebaseToken} from "../src/interfaces/IRebaseToken.sol";

contract CrossChainTest is Test {
    uint256 sepoliaFork;
    uint256 arbSepoliaFork;
    function setUp() public {
        sepoliaFork = vm.createSelectFork(vm.envString("SEPOLIA_RPC_URL"));
        arbSepoliaFork = vm.createFork(vm.envString("ARBITRUM_SEPOLIA_RPC_URL"));
    }
}
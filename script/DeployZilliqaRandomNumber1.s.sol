// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Script} from "forge-std/Script.sol";
import {ZilliqaRandomNumber1} from "src/ZilliqaRandomNumber1.sol";
import {console} from "forge-std/console.sol";

contract DeployZilliqaRandomNumber is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address owner = vm.addr(deployerPrivateKey);
        console.log("Deployer is %s", owner);

        // Start broadcast without EIP-1559 fees
        vm.startBroadcast(deployerPrivateKey);

        // Deploy implementation
        ZilliqaRandomNumber1 implementation = new ZilliqaRandomNumber1();
        console.log("Implementation deployed at: %s", address(implementation));

        vm.stopBroadcast();
    }
}
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Script} from "forge-std/Script.sol";
import {ZilliqaRandomNumber2} from "src/ZilliqaRandomNumber2.sol";
import {console} from "forge-std/console.sol";

contract DeployZilliqaRandomNumber2 is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address owner = vm.addr(deployerPrivateKey);
        console.log("Deployer is %s", owner);

        // Start broadcast without EIP-1559 fees
        vm.startBroadcast(deployerPrivateKey);

        // Deploy implementation
        ZilliqaRandomNumber2 implementation = new ZilliqaRandomNumber2();
        console.log("Implementation deployed at: %s", address(implementation));

        vm.stopBroadcast();
    }
}
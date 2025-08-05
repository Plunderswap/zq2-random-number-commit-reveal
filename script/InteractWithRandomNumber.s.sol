// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Script.sol";
import "forge-std/console2.sol";
import "forge-std/Vm.sol";
import "../src/ZilliqaRandomNumber1.sol";
import "../src/ZilliqaRandomNumber2.sol";

contract InteractWithRandomNumber is Script {
    function commitToRNG1(address contractAddress) public {
        ZilliqaRandomNumber1 rng = ZilliqaRandomNumber1(contractAddress);
        
        uint256 futureBlock = block.number + 20; // MIN_BLOCKS_DELAY + 20
        
        rng.commit(futureBlock);
        console2.log("\n=== RNG1 Commit Results ===");
        console2.log("Target block:", futureBlock);
        console2.log("Commitment successful! Wait for target block, then call reveal()");
    }

    function revealRNG1(address contractAddress) public {
        ZilliqaRandomNumber1 rng = ZilliqaRandomNumber1(contractAddress);
        
        console2.log("\n=== RNG1 Reveal ===");
        console2.log("Contract:", contractAddress);
        
        // Do the reveal
        rng.reveal();
        
        console2.log("\n=== RNG1 Reveal Completed ===");
        console2.log("Transaction submitted successfully!");
        console2.log("To see the random number results, check the transaction receipt:");
        console2.log("cast receipt <tx_hash> --rpc-url https://api.testnet.zilliqa.com");
        console2.log("");
        console2.log("The RandomnessRevealed event contains:");
        console2.log("- randomNumber (full 256-bit entropy)");
        console2.log("- prevrandao, blockhash");
    }

    function commitToRNG2(address contractAddress, uint256 minRandom, uint256 maxRandom) public {
        ZilliqaRandomNumber2 rng = ZilliqaRandomNumber2(contractAddress);
        
        uint256 futureBlock = block.number + 20; // MIN_BLOCKS_DELAY + 20
        
        rng.commit(futureBlock, minRandom, maxRandom);
        console2.log("\n=== RNG2 Commit Results ===");
        console2.log("Target block:", futureBlock);
        console2.log("Min Random:", minRandom);
        console2.log("Max Random:", maxRandom);
        console2.log("Commitment successful! Wait for target block, then call reveal()");
    }

    function revealRNG2(address contractAddress) public {
        ZilliqaRandomNumber2 rng = ZilliqaRandomNumber2(contractAddress);
        
        console2.log("\n=== RNG2 Reveal ===");
        console2.log("Contract:", contractAddress);
        
        // Do the reveal
        rng.reveal();
        
        console2.log("\n=== RNG2 Reveal Completed ===");
        console2.log("Transaction submitted successfully!");
        console2.log("To see the random number results, check the transaction receipt:");
        console2.log("cast receipt <tx_hash> --rpc-url https://api.testnet.zilliqa.com");
        console2.log("");
        console2.log("The RandomnessRevealed event contains:");
        console2.log("- randomNumber (full 256-bit entropy)");
        console2.log("- constrainedRandomNumber (within your range)");
        console2.log("- prevrandao, blockhash");
        console2.log("- minRandom, maxRandom");
    }

    function cancelCommitment(address contractAddress, bool isRNG2) public {
        if (isRNG2) {
            ZilliqaRandomNumber2 rng = ZilliqaRandomNumber2(contractAddress);
            rng.cancelCommitment();
            console2.log("Cancelled commitment for RNG2");
        } else {
            ZilliqaRandomNumber1 rng = ZilliqaRandomNumber1(contractAddress);
            rng.cancelCommitment();
            console2.log("Cancelled commitment for RNG1");
        }
    }

    function run() external {
        // Get environment variables
        uint256 privateKey = vm.envUint("PRIVATE_KEY");
        address contractAddress = vm.envAddress("CONTRACT_ADDRESS");
        string memory action = vm.envString("ACTION");
        
        bool isRNG2 = false;
        try vm.envBool("IS_RNG2") returns (bool _isRNG2) {
            isRNG2 = _isRNG2;
        } catch {}

        // Get min/max random for RNG2 (with defaults if not provided)
        uint256 minRandom = 1;
        uint256 maxRandom = 10000;
        
        if (isRNG2) {
            try vm.envUint("MIN_RANDOM") returns (uint256 min) {
                minRandom = min;
            } catch {}
            
            try vm.envUint("MAX_RANDOM") returns (uint256 max) {
                maxRandom = max;
            } catch {}
        }

        console2.log("\n=== Input Values ===");
        console2.log("Contract:", contractAddress);
        console2.log("Action:", action);
        
        if (isRNG2) {
            console2.log("Contract Type: RNG2");
            console2.log("Min Random:", minRandom);
            console2.log("Max Random:", maxRandom);
        } else {
            console2.log("Contract Type: RNG1");
        }

        vm.startBroadcast(privateKey);

        if (keccak256(abi.encodePacked(action)) == keccak256(abi.encodePacked("commit"))) {
            if (isRNG2) {
                commitToRNG2(contractAddress, minRandom, maxRandom);
            } else {
                commitToRNG1(contractAddress);
            }
        } else if (keccak256(abi.encodePacked(action)) == keccak256(abi.encodePacked("reveal"))) {
            if (isRNG2) {
                revealRNG2(contractAddress);
            } else {
                revealRNG1(contractAddress);
            }
        } else if (keccak256(abi.encodePacked(action)) == keccak256(abi.encodePacked("cancel"))) {
            cancelCommitment(contractAddress, isRNG2);
        }

        vm.stopBroadcast();
    }
} 
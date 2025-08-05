// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Script.sol";
import "forge-std/console2.sol";

contract DecodeRandomReveal is Script {
    
    // Helper function to extract substring
    function substring(string memory str, uint startIndex, uint endIndex) internal pure returns (string memory) {
        bytes memory strBytes = bytes(str);
        bytes memory result = new bytes(endIndex - startIndex);
        for (uint i = startIndex; i < endIndex; i++) {
            result[i - startIndex] = strBytes[i];
        }
        return string(result);
    }
    
    function decodeRNG1Event(bytes memory eventData) public pure returns (
        uint256 randomNumber,
        bytes32 salt, // Will be bytes32(0) in new version
        uint256 prevrandao,
        bytes32 blockHash
    ) {
        // Note: user address is indexed, so it's in topics not data
        (
            randomNumber,
            salt,
            prevrandao,
            blockHash
        ) = abi.decode(
            eventData,
            (uint256, bytes32, uint256, bytes32)
        );
    }
    
    function decodeRNG2Event(bytes memory eventData) public pure returns (
        uint256 randomNumber,
        uint256 constrainedRandomNumber,
        bytes32 salt, // Will be bytes32(0) in new version
        uint256 prevrandao,
        bytes32 blockHash,
        uint256 minRandom,
        uint256 maxRandom
    ) {
        // Note: user address is indexed, so it's in topics not data
        (
            randomNumber,
            constrainedRandomNumber,
            salt,
            prevrandao,
            blockHash,
            minRandom,
            maxRandom
        ) = abi.decode(
            eventData,
            (uint256, uint256, bytes32, uint256, bytes32, uint256, uint256)
        );
    }
    
    function verifyRandomCalculation(
        address user,
        uint256 prevrandao,
        bytes32 blockHash
    ) public pure returns (uint256) {
        // Match the updated contract calculation (user address replaces salt)
        return uint256(
            keccak256(
                abi.encodePacked(
                    user,
                    prevrandao,
                    blockHash
                )
            )
        );
    }
    
    function decodeFromTxHash() external {
        // Get environment variables
        string memory txHash = vm.envString("TX_HASH");
        
        bool isRNG2 = false;
        try vm.envBool("IS_RNG2") returns (bool _isRNG2) {
            isRNG2 = _isRNG2;
        } catch {}
        
        string memory rpcUrl = "https://api.testnet.zilliqa.com";
        try vm.envString("RPC_URL") returns (string memory _rpcUrl) {
            rpcUrl = _rpcUrl;
        } catch {}
        
        address walletAddress = address(0);
        try vm.envAddress("WALLET_ADDRESS") returns (address _walletAddress) {
            walletAddress = _walletAddress;
        } catch {}
        
        console2.log("\n=== Decoding Transaction ===");
        console2.log("TX Hash:", txHash);
        console2.log("RPC URL:", rpcUrl);
        console2.log("Contract Type:", isRNG2 ? "RNG2" : "RNG1");
        if (walletAddress != address(0)) {
            console2.log("Wallet Address:", walletAddress);
        } else {
            console2.log("Wallet Address: Not provided (verification will be skipped)");
        }
        
        // Use FFI to get transaction receipt
        string[] memory inputs = new string[](6);
        inputs[0] = "cast";
        inputs[1] = "receipt";
        inputs[2] = txHash;
        inputs[3] = "--rpc-url";
        inputs[4] = rpcUrl;
        inputs[5] = "--json";
        
        bytes memory receiptData = vm.ffi(inputs);
        
        console2.log("\n=== Raw Receipt Data (first 200 chars) ===");
        console2.log(substring(string(receiptData), 0, 200));
        
        // Parse the actual event data from the JSON response  
        bytes memory actualLogData = abi.decode(vm.parseJson(string(receiptData), ".logs[0].data"), (bytes));
        console2.log("\n=== Actual Event Data from Transaction ===");
        console2.log("Actual data length:", actualLogData.length);
        
        if (isRNG2) {
            decodeAndDisplayRNG2(actualLogData, walletAddress);
        } else {
            decodeAndDisplayRNG1(actualLogData, walletAddress);
        }
    }
    
    function decodeAndDisplayRNG1(bytes memory logData, address walletAddress) internal {
        (
            uint256 randomNumber,
            bytes32 salt,
            uint256 prevrandao,
            bytes32 blockHash
        ) = decodeRNG1Event(logData);
        
        console2.log("\n=== RNG1 Transaction Values ===");
        console2.log("Random Number:", randomNumber);
        console2.log("Prevrandao:", prevrandao);
        console2.log("Block Hash:");
        console2.logBytes32(blockHash);
        
        console2.log("\n=== Verification ===");
        if (walletAddress != address(0)) {
            uint256 calculatedRandom = verifyRandomCalculation(walletAddress, prevrandao, blockHash);
            console2.log("Calculated Random:", calculatedRandom);
            console2.log("Expected Random:", randomNumber);
            console2.log("Verification:", calculatedRandom == randomNumber ? "PASSED" : "FAILED");
            
            if (calculatedRandom != randomNumber) {
                console2.log("WARNING: Random number verification failed!");
                console2.log("This could indicate:");
                console2.log("- Wrong wallet address provided");
                console2.log("- Transaction data corruption");
                console2.log("- Contract implementation mismatch");
            }
        } else {
            console2.log("Wallet address not provided");
            console2.log("To verify: export WALLET_ADDRESS=0x... and run again");
            console2.log("Formula: keccak256(userAddress, prevrandao, blockHash)");
        }
        
        // Display entropy analysis
        console2.log("\n=== Entropy Analysis ===");
        console2.log("User Address: HIGH (user-specific entropy)");
        console2.log("Prevrandao:", prevrandao == 0 ? "ZERO (no entropy)" : "NON-ZERO (good entropy)");
        console2.log("Block Hash: HIGH (unpredictable past block hash)");
        console2.log("TOTAL: 3 optimized entropy sources");
    }
    
    function decodeAndDisplayRNG2(bytes memory logData, address walletAddress) internal {
        console2.log("\n=== Starting RNG2 Decode ===");
        console2.log("Data length:", logData.length);
        
        if (logData.length == 224) {
            console2.log("This is the standard RNG2 format");
            
            (
                uint256 randomNumber,
                uint256 constrainedRandomNumber,
                bytes32 salt,
                uint256 prevrandao,
                bytes32 blockHash,
                uint256 minRandom,
                uint256 maxRandom
            ) = abi.decode(
                logData,
                (uint256, uint256, bytes32, uint256, bytes32, uint256, uint256)
            );
            
            console2.log("\n=== RNG2 Values ===");
            console2.log("Random Number:", randomNumber);
            console2.log("Constrained Number:", constrainedRandomNumber);
            console2.log("Prevrandao:", prevrandao);
            console2.log("Block Hash:");
            console2.logBytes32(blockHash);
            console2.log("Min Random:", minRandom);
            console2.log("Max Random:", maxRandom);
            
            console2.log("\n=== Verification ===");
            if (walletAddress != address(0)) {
                uint256 calculatedRandom = verifyRandomCalculation(walletAddress, prevrandao, blockHash);
                uint256 range = maxRandom - minRandom + 1;
                uint256 calculatedConstrained = (calculatedRandom % range) + minRandom;
                
                console2.log("Calculated Raw Random:", calculatedRandom);
                console2.log("Expected Raw Random:", randomNumber);
                console2.log("Calculated Constrained:", calculatedConstrained);
                console2.log("Expected Constrained:", constrainedRandomNumber);
                
                bool rawMatch = calculatedRandom == randomNumber;
                bool constrainedMatch = calculatedConstrained == constrainedRandomNumber;
                
                console2.log("Raw Random Verification:", rawMatch ? "PASSED" : "FAILED");
                console2.log("Constrained Random Verification:", constrainedMatch ? "PASSED" : "FAILED");
                
                if (!rawMatch || !constrainedMatch) {
                    console2.log("WARNING: Random number verification failed!");
                    console2.log("This could indicate:");
                    console2.log("- Wrong wallet address provided");
                    console2.log("- Transaction data corruption");
                    console2.log("- Contract implementation mismatch");
                    console2.log("- Range calculation error");
                }
            } else {
                console2.log("Wallet address not provided");
                console2.log("To verify: export WALLET_ADDRESS=0x... and run again");
                console2.log("Formula: keccak256(userAddress, prevrandao, blockHash)");
            }
            
            // Display entropy analysis
            console2.log("\n=== Entropy Analysis ===");
            console2.log("User Address: HIGH (user-specific entropy)");
            console2.log("Prevrandao:", prevrandao == 0 ? "ZERO (no entropy)" : "NON-ZERO (good entropy)");
            console2.log("Block Hash: HIGH (unpredictable past block hash)");
            console2.log("TOTAL: 3 optimized entropy sources");
            
            // Range analysis
            console2.log("\n=== Range Analysis ===");
            uint256 range = maxRandom - minRandom + 1;
            console2.log("Range Size:", range);
            console2.log("Range Coverage: ", minRandom, "to", maxRandom);
            if (range > 1000000000) { // 1 billion
                console2.log("Large range: bias negligible");
            } else if (range > 1000000) { // 1 million
                console2.log("Medium range: bias very small");
            } else {
                console2.log("Small range: bias still negligible for cryptographic hash");
            }
            return;
        }
        
        console2.log("ERROR: Unexpected event data length");
        console2.log("Expected 224 bytes for RNG2, got:", logData.length);
    }
}
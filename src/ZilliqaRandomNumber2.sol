// SPDX-License-Identifier: CC-BY-NC-4.0
pragma solidity ^0.8.0;

/**
 * @title ZilliqaRandomNumber2
 * @notice Commit-reveal random number generation contract with range constraints
 * @dev This contract is licensed under Creative Commons Attribution-NonCommercial 4.0 International (CC BY-NC 4.0)
 * 
 * License Summary:
 * - You are free to share and adapt this material for non-commercial purposes
 * - You must give appropriate credit and indicate if changes were made
 * - Commercial use requires a separate license - contact the licensor for commercial licensing
 * 
 * Full license: https://creativecommons.org/licenses/by-nc/4.0/
 * License text: See LICENSE file in the project root
 * 
 * For commercial licensing inquiries, please contact: info (at) plunderswap.com
 */

contract ZilliqaRandomNumber2 {
    struct Commitment {
        uint256 targetBlock;
        uint256 minRandom;
        uint256 maxRandom;
        bool revealed;
    }
    
    // Constants for block limits
    uint256 public constant MIN_BLOCKS_DELAY = 5;
    uint256 public constant MAX_BLOCKS_DELAY = 1000;
    
    // Maximum allowed range for random numbers (2 billion)
    uint256 public constant MAX_RANDOM_LIMIT = 2_000_000_000;
    
    mapping(address => Commitment) public commitments;
    
    // Events
    event CommitSubmitted(address indexed user, uint256 targetBlock, uint256 minRandom, uint256 maxRandom);
    event RandomnessRevealed(
        address indexed user,
        uint256 randomNumber,
        uint256 constrainedRandomNumber,
        bytes32 salt,
        uint256 prevrandao,
        bytes32 blockhash,
        uint256 minRandom,
        uint256 maxRandom
    );
    
    function commit(uint256 futureBlockNumber, uint256 minRandom, uint256 maxRandom) external {
        // Safety checks
        require(futureBlockNumber > block.number + MIN_BLOCKS_DELAY, "Need minimum 5 blocks");
        require(futureBlockNumber < block.number + MAX_BLOCKS_DELAY, "Too far in future");
        require(commitments[msg.sender].targetBlock == 0, "Existing commitment found");
        
        // Validate random number range
        require(minRandom > 0, "Min random must be greater than 0");
        require(maxRandom <= MAX_RANDOM_LIMIT, "Max random exceeds limit");
        require(minRandom <= maxRandom, "Min random cannot be greater than max random");
        
        commitments[msg.sender] = Commitment({
            targetBlock: futureBlockNumber,
            minRandom: minRandom,
            maxRandom: maxRandom,
            revealed: false
        });
        
        emit CommitSubmitted(msg.sender, futureBlockNumber, minRandom, maxRandom);
    }
    
    function reveal() external {
        Commitment storage commitment = commitments[msg.sender];
        require(commitment.targetBlock != 0, "No commitment found");
        require(block.number >= commitment.targetBlock, "Too early");
        require(!commitment.revealed, "Already revealed");

        // Generate random number using multiple sources
        uint256 randomNumber = uint256(
            keccak256(
                abi.encodePacked(
                    msg.sender,
                    block.prevrandao,
                    blockhash(block.number - 1)
                )
            )
        );
        
        // Generate a fair random number within the range
        uint256 constrainedRandomNumber = generateRandomNumber(randomNumber, commitment.minRandom, commitment.maxRandom);
        
        // Store min/max before deleting commitment
        uint256 minRandom = commitment.minRandom;
        uint256 maxRandom = commitment.maxRandom;
        
        commitment.revealed = true;
        delete commitments[msg.sender];
        
        emit RandomnessRevealed(
            msg.sender,
            randomNumber,
            constrainedRandomNumber,
            bytes32(0), // No salt needed
            block.prevrandao,
            blockhash(block.number - 1),
            minRandom,
            maxRandom
        );
    }
    
    function generateRandomNumber(uint256 randomNumber, uint256 minRandom, uint256 maxRandom) internal pure returns (uint256) {
        uint256 range = maxRandom - minRandom + 1;
        return (randomNumber % range) + minRandom;
    }
    
    // Allow users to cancel unrevealed commitments after max delay
    function cancelCommitment() external {
        Commitment storage commitment = commitments[msg.sender];
        require(commitment.targetBlock != 0, "No commitment found");
        require(!commitment.revealed, "Already revealed");
        require(block.number > commitment.targetBlock + MAX_BLOCKS_DELAY, "Too early to cancel");
        
        delete commitments[msg.sender];
    }
}
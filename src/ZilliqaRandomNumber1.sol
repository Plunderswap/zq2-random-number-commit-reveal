// SPDX-License-Identifier: CC-BY-NC-4.0
pragma solidity ^0.8.0;

/**
 * @title ZilliqaRandomNumber1
 * @notice Commit-reveal random number generation contract
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

contract ZilliqaRandomNumber1 {
    struct Commitment {
        uint256 targetBlock;
        bool revealed;
    }
    
    // Constants for block limits
    uint256 public constant MIN_BLOCKS_DELAY = 5;
    uint256 public constant MAX_BLOCKS_DELAY = 1000;
    
    mapping(address => Commitment) public commitments;
    
    // Events
    event CommitSubmitted(address indexed user, uint256 targetBlock);
    event RandomnessRevealed(address indexed user, uint256 randomNumber, bytes32 salt, uint256 prevrandao, bytes32 blockhash);
    
    function commit(uint256 futureBlockNumber) external {
        // Safety checks
        require(futureBlockNumber > block.number + MIN_BLOCKS_DELAY, "Need minimum 5 blocks");
        require(futureBlockNumber < block.number + MAX_BLOCKS_DELAY, "Too far in future");
        require(commitments[msg.sender].targetBlock == 0, "Existing commitment found");
        
        commitments[msg.sender] = Commitment({
            targetBlock: futureBlockNumber,
            revealed: false
        });
        
        emit CommitSubmitted(msg.sender, futureBlockNumber);
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
        
        commitment.revealed = true;
        delete commitments[msg.sender];
        
        emit RandomnessRevealed(
            msg.sender,
            randomNumber,
            bytes32(0), // No salt needed
            block.prevrandao,
            blockhash(block.number - 1)
        );
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
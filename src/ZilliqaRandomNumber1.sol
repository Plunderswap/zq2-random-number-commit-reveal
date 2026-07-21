// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/// @title ZilliqaRandomNumber1
/// @notice Commit-reveal random number generator returning the full unconstrained value.
/// @dev A commitment pins a future target block. The random value is derived from that
///      block's hash once it has been produced, so the outcome is fixed independently of
///      when (or by whom) the reveal is submitted.
contract ZilliqaRandomNumber1 {
    struct Commitment {
        uint256 targetBlock;
        bool revealed;
    }

    /// @notice Minimum blocks between commit and the target block.
    uint256 public constant MIN_BLOCKS_DELAY = 5;

    /// @notice Maximum blocks between commit and the target block.
    uint256 public constant MAX_BLOCKS_DELAY = 1000;

    /// @notice Blocks after the target block during which its hash remains readable.
    uint256 public constant REVEAL_WINDOW = 256;

    mapping(address => Commitment) public commitments;

    event CommitSubmitted(address indexed user, uint256 targetBlock);
    event RandomnessRevealed(address indexed user, uint256 randomNumber, uint256 targetBlock, bytes32 targetBlockHash);

    function commit(uint256 futureBlockNumber) external {
        require(futureBlockNumber > block.number + MIN_BLOCKS_DELAY, "Need minimum 5 blocks");
        require(futureBlockNumber < block.number + MAX_BLOCKS_DELAY, "Too far in future");
        require(commitments[msg.sender].targetBlock == 0, "Existing commitment found");

        commitments[msg.sender] = Commitment({targetBlock: futureBlockNumber, revealed: false});

        emit CommitSubmitted(msg.sender, futureBlockNumber);
    }

    function reveal() external {
        Commitment storage commitment = commitments[msg.sender];
        uint256 targetBlock = commitment.targetBlock;
        require(targetBlock != 0, "No commitment found");
        require(!commitment.revealed, "Already revealed");
        require(block.number > targetBlock, "Too early");

        bytes32 targetBlockHash = blockhash(targetBlock);
        require(targetBlockHash != bytes32(0), "Reveal window expired");

        uint256 randomNumber = uint256(keccak256(abi.encodePacked(msg.sender, targetBlockHash)));

        delete commitments[msg.sender];

        emit RandomnessRevealed(msg.sender, randomNumber, targetBlock, targetBlockHash);
    }

    /// @notice Reclaim a commitment slot after the reveal window has closed.
    function cancelCommitment() external {
        Commitment storage commitment = commitments[msg.sender];
        require(commitment.targetBlock != 0, "No commitment found");
        require(!commitment.revealed, "Already revealed");
        require(block.number > commitment.targetBlock + REVEAL_WINDOW, "Too early to cancel");

        delete commitments[msg.sender];
    }
}

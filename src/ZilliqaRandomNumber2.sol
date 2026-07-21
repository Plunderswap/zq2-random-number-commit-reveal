// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/// @title ZilliqaRandomNumber2
/// @notice Commit-reveal random number generator constrained to a user-specified range.
/// @dev A commitment pins a future target block and the desired range. The random value is
///      derived from that block's hash once it has been produced, so the outcome is fixed
///      independently of when (or by whom) the reveal is submitted.
contract ZilliqaRandomNumber2 {
    struct Commitment {
        uint256 targetBlock;
        uint256 minRandom;
        uint256 maxRandom;
        bool revealed;
    }

    /// @notice Minimum blocks between commit and the target block.
    uint256 public constant MIN_BLOCKS_DELAY = 5;

    /// @notice Maximum blocks between commit and the target block.
    uint256 public constant MAX_BLOCKS_DELAY = 1000;

    /// @notice Blocks after the target block during which its hash remains readable.
    uint256 public constant REVEAL_WINDOW = 256;

    /// @notice Maximum allowed range for random numbers (2 billion).
    uint256 public constant MAX_RANDOM_LIMIT = 2_000_000_000;

    mapping(address => Commitment) public commitments;

    event CommitSubmitted(address indexed user, uint256 targetBlock, uint256 minRandom, uint256 maxRandom);
    event RandomnessRevealed(
        address indexed user,
        uint256 randomNumber,
        uint256 constrainedRandomNumber,
        uint256 targetBlock,
        bytes32 targetBlockHash,
        uint256 minRandom,
        uint256 maxRandom
    );

    function commit(uint256 futureBlockNumber, uint256 minRandom, uint256 maxRandom) external {
        require(futureBlockNumber > block.number + MIN_BLOCKS_DELAY, "Need minimum 5 blocks");
        require(futureBlockNumber < block.number + MAX_BLOCKS_DELAY, "Too far in future");
        require(commitments[msg.sender].targetBlock == 0, "Existing commitment found");

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
        uint256 targetBlock = commitment.targetBlock;
        require(targetBlock != 0, "No commitment found");
        require(!commitment.revealed, "Already revealed");
        require(block.number > targetBlock, "Too early");

        bytes32 targetBlockHash = blockhash(targetBlock);
        require(targetBlockHash != bytes32(0), "Reveal window expired");

        uint256 randomNumber = uint256(keccak256(abi.encodePacked(msg.sender, targetBlockHash)));

        uint256 minRandom = commitment.minRandom;
        uint256 maxRandom = commitment.maxRandom;
        uint256 constrainedRandomNumber = generateRandomNumber(randomNumber, minRandom, maxRandom);

        delete commitments[msg.sender];

        emit RandomnessRevealed(
            msg.sender, randomNumber, constrainedRandomNumber, targetBlock, targetBlockHash, minRandom, maxRandom
        );
    }

    function generateRandomNumber(uint256 randomNumber, uint256 minRandom, uint256 maxRandom)
        internal
        pure
        returns (uint256)
    {
        uint256 range = maxRandom - minRandom + 1;
        return (randomNumber % range) + minRandom;
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

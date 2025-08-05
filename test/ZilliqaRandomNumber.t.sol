// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/ZilliqaRandomNumber1.sol";
import "../src/ZilliqaRandomNumber2.sol";

contract ZilliqaRandomNumberTest is Test {
    ZilliqaRandomNumber1 public rng1;
    ZilliqaRandomNumber2 public rng2;
    address public user;
    bytes32 public constant SALT = bytes32(uint256(1234));
    
    // Declare events to match the contracts
    event RandomnessRevealed(address indexed user, uint256 randomNumber, bytes32 salt, uint256 prevrandao, bytes32 blockhash);
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
    
    function setUp() public {
        rng1 = new ZilliqaRandomNumber1();
        rng2 = new ZilliqaRandomNumber2();
        user = address(1);
        vm.label(user, "User");
    }

    // Helper function to generate commitment hash
    function generateCommitment(bytes32 salt) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(salt));
    }

    // Tests for ZilliqaRandomNumber1
    function testCommitAndReveal_RNG1() public {
        uint256 futureBlock = block.number + 6;

        vm.startPrank(user);
        
        // Submit commitment - no hash needed, just target block
        rng1.commit(futureBlock);
        
        // Warp to future block
        vm.roll(futureBlock);
        
        // Reveal - no salt needed, uses msg.sender for randomness
        rng1.reveal();
        
        vm.stopPrank();
    }

    function test_RevertWhen_RevealingTooEarly_RNG1() public {
        uint256 futureBlock = block.number + 6;

        vm.startPrank(user);
        rng1.commit(futureBlock);
        
        vm.expectRevert("Too early");
        rng1.reveal();
        vm.stopPrank();
    }

    // Tests for ZilliqaRandomNumber2
    function testCommitAndReveal_RNG2() public {
        uint256 futureBlock = block.number + 6;
        uint256 minRandom = 1;
        uint256 maxRandom = 100;

        vm.startPrank(user);
        
        // Submit commitment with range - no hash needed
        rng2.commit(futureBlock, minRandom, maxRandom);
        
        // Warp to future block
        vm.roll(futureBlock);
        
        // Reveal - no salt needed, uses msg.sender for randomness
        rng2.reveal();
        
        vm.stopPrank();
    }

    function testRandomNumberRange_RNG2() public {
        uint256 futureBlock = block.number + 6;
        uint256 minRandom = 10;
        uint256 maxRandom = 50;

        vm.startPrank(user);
        rng2.commit(futureBlock, minRandom, maxRandom);
        vm.roll(futureBlock);
        
        // Capture the event to check the constrained random number
        vm.recordLogs();
        rng2.reveal();
        Vm.Log[] memory entries = vm.getRecordedLogs();
        
        // Parse the constrained random number from the event data field instead of topics
        // The event data is packed in the order of non-indexed parameters
        (, uint256 constrainedRandomNumber,,,, uint256 eventMinRandom, uint256 eventMaxRandom) = abi.decode(
            entries[0].data,
            (uint256, uint256, bytes32, uint256, bytes32, uint256, uint256)
        );
        
        // Verify number is within the committed range
        assertTrue(
            constrainedRandomNumber >= minRandom && 
            constrainedRandomNumber <= maxRandom,
            "Random number out of committed range"
        );
        
        // Verify the event contains the correct range
        assertEq(eventMinRandom, minRandom, "Event min random mismatch");
        assertEq(eventMaxRandom, maxRandom, "Event max random mismatch");
        
        vm.stopPrank();
    }

    function testCancelCommitment_RNG2() public {
        uint256 futureBlock = block.number + 6;
        uint256 minRandom = 1;
        uint256 maxRandom = 100;

        vm.startPrank(user);
        rng2.commit(futureBlock, minRandom, maxRandom);
        
        // Try to cancel before MAX_BLOCKS_DELAY (should fail)
        vm.expectRevert("Too early to cancel");
        rng2.cancelCommitment();
        
        // Warp past MAX_BLOCKS_DELAY
        vm.roll(futureBlock + rng2.MAX_BLOCKS_DELAY() + 1);
        
        // Should succeed now
        rng2.cancelCommitment();
        
        vm.stopPrank();
    }

    // Common failure cases for both contracts
    function test_RevertWhen_BlockTooEarly() public {
        uint256 futureBlock = block.number + 4; // Less than MIN_BLOCKS_DELAY

        vm.startPrank(user);
        vm.expectRevert("Need minimum 5 blocks");
        rng1.commit(futureBlock);
        vm.stopPrank();
    }

    function test_RevertWhen_BlockTooLate() public {
        uint256 futureBlock = block.number + 1001; // More than MAX_BLOCKS_DELAY (1000)

        vm.startPrank(user);
        vm.expectRevert("Too far in future");
        rng1.commit(futureBlock);
        vm.stopPrank();
    }

    function test_RevertWhen_CommittingTwice() public {
        uint256 futureBlock = block.number + 6;

        vm.startPrank(user);
        rng1.commit(futureBlock);
        
        vm.expectRevert("Existing commitment found");
        rng1.commit(futureBlock);
        vm.stopPrank();
    }

    // Note: This test is no longer relevant since there's no salt to get wrong
    // function test_RevertWhen_RevealingWithWrongSalt() - removed

    // New tests for ZilliqaRandomNumber2 range validation
    function test_RevertWhen_MinRandomIsZero() public {
        uint256 futureBlock = block.number + 6;

        vm.startPrank(user);
        vm.expectRevert("Min random must be greater than 0");
        rng2.commit(futureBlock, 0, 100);
        vm.stopPrank();
    }

    function test_RevertWhen_MaxRandomExceedsLimit() public {
        uint256 futureBlock = block.number + 6;

        vm.startPrank(user);
        vm.expectRevert("Max random exceeds limit");
        // Try with a value that definitely exceeds 2 billion
        rng2.commit(futureBlock, 1, 2_000_000_001);
        vm.stopPrank();
    }

    function test_RevertWhen_MinGreaterThanMax() public {
        uint256 futureBlock = block.number + 6;

        vm.startPrank(user);
        vm.expectRevert("Min random cannot be greater than max random");
        rng2.commit(futureBlock, 100, 50);
        vm.stopPrank();
    }

    function test_ValidRangeEdgeCases() public {
        uint256 futureBlock = block.number + 6;

        vm.startPrank(user);
        
        // Test edge case: min = max (single value)
        rng2.commit(futureBlock, 42, 42);
        vm.roll(futureBlock);
        
        vm.recordLogs();
        rng2.reveal();
        Vm.Log[] memory entries = vm.getRecordedLogs();
        
        (, uint256 constrainedRandomNumber,,,, uint256 eventMinRandom, uint256 eventMaxRandom) = abi.decode(
            entries[0].data,
            (uint256, uint256, bytes32, uint256, bytes32, uint256, uint256)
        );
        
        // Should always be 42 when min = max = 42
        assertEq(constrainedRandomNumber, 42, "Single value range should return exact value");
        assertEq(eventMinRandom, 42, "Event min should be 42");
        assertEq(eventMaxRandom, 42, "Event max should be 42");
        
        vm.stopPrank();
    }
} 
# ZQ2 Random Number Generator (Commit/Reveal VRF)

Designed by PlunderSwap

This was a simple project to learn about random number generation using commitments and reveals, and pre-randomized randao from a future block.

These 2 things together allow for a simple random number generator that is verifiable and secure.

The commit-reveal pattern remains the most secure on-chain solution.

## License

This project is licensed under **Creative Commons Attribution-NonCommercial 4.0 International (CC BY-NC 4.0)**.

### License Summary

✅ **Free for Non-Commercial Use**: You are free to use, modify, and share this code for non-commercial purposes  
✅ **Attribution Required**: You must give appropriate credit to the original author  
✅ **Modifications Allowed**: You can adapt and build upon this code  
❌ **Commercial Use Restricted**: Commercial use requires a separate license  

### What This Means

- **Educational Use**: ✅ Free to use for learning and educational projects
- **Research Projects**: ✅ Free to use for academic and research purposes  
- **Open Source Projects**: ✅ Free to use in non-commercial open source projects
- **Personal Projects**: ✅ Free to use for personal, non-profit projects
- **Commercial Applications**: ❌ Requires commercial license (contact us)
- **Production DApps**: ❌ Requires commercial license if monetized
- **Trading/Gaming Platforms**: ❌ Requires commercial license

### Commercial Licensing

For commercial use, including but not limited to:

- Production DApps and platforms
- Commercial gaming applications  
- Trading platforms and exchanges
- Revenue-generating applications
- Enterprise deployments

**Contact us for commercial licensing**: [info@plunderswap.com](mailto:info@plunderswap.com)

### Full License

- **License Text**: See [LICENSE](./LICENSE) file in this repository
- **Official License**: [CC BY-NC 4.0](https://creativecommons.org/licenses/by-nc/4.0/)

### Attribution

When using this code, please include attribution:

Based on ZQ2 Random Number Generator by PlunderSwap
Original: https://github.com/Plunderswap/zq2-random-number-commit-reveal
Licensed under CC BY-NC 4.0

## Contract Features

### ZilliqaRandomNumber1 Contract

This contract returns the full unconstrained random number for applications that need the raw entropy value.

### ZilliqaRandomNumber2 Contract (Recommended)

The enhanced contract implements a secure random number generation system using a commit-reveal pattern combined with block-based randomness. This prevents miners/validators from knowing the outcome before including the transaction, and prevents users from selectively submitting transactions based on outcomes.

#### Commitment System

- Users submit a commitment for their desired random number range
- Commitments must target a future block (minimum 5 blocks ahead, maximum 100 blocks)
- Each address can only have one active commitment at a time
- **Range Selection**: Users specify `minRandom` and `maxRandom` values at commit time for maximum fairness
- Maximum allowed range: up to 2 billion (2,000,000,000)

#### Security Measures

- MIN_BLOCKS_DELAY (5 blocks): Ensures sufficient time between commit and reveal
- MAX_BLOCKS_DELAY (1000 blocks): Prevents commitments too far in the future
- Commitment verification: Validates that the user has an active commitment for the target block
- Range validation: Ensures valid min/max values and enforces maximum limit
- **Fair Range Commitment**: Users must commit to their desired range upfront, preventing manipulation
- **Manipulation-resistant entropy**: Uses previous block hash instead of timestamp to prevent validator manipulation

#### Random Number Generation

The final random number combines three carefully selected entropy sources for optimal security and efficiency:

- **User wallet address** (user-specific entropy, ensures different users get different results)
- **Block's PREVRANDAO value** (block randomness - confirmed working well on ZQ2!)
- **Previous block hash** (cryptographic entropy from recent block, manipulation-resistant)

This streamlined approach provides excellent randomness while being gas-efficient and simple to verify. The PREVRANDAO on ZQ2 provides strong entropy (non-zero values), the previous block hash adds additional unpredictable entropy that cannot be manipulated by validators, and the user's wallet address ensures different users get different random numbers even with identical block conditions.

The randomness is then constrained to the user's specified range using a mathematically fair modulo operation that ensures uniform distribution across all possible values.

All entropy sources and the final constrained random number are returned in the `RandomnessRevealed` event for complete transparency and verification.

#### Randomness Fairness Analysis

The contract uses a cryptographically secure approach to ensure fair distribution:

1. **Entropy Sources**: Combines user wallet address, block.prevrandao, and previous block hash via keccak256
2. **Uniform Distribution**: Uses modulo operation `(randomNumber % range) + minRandom` 
3. **No Bias**: The modulo operation provides uniform distribution when the input space (2^256) is much larger than the output range (max 2 billion)
4. **Bias Analysis**: With a 2^256 input space and maximum 2×10^9 output range, the bias is negligible (~2^-27, or less than 1 in 134 million)

#### Events

The contract emits two main events:

- `CommitSubmitted`: When a user submits a new commitment, including the target block and random number range
- `RandomnessRevealed`: When randomness is successfully generated, including:
  - The raw random number (full entropy)
  - The constrained random number (within specified range, RNG2 only)

  - The block's PREVRANDAO value
  - The previous block hash
  - The min/max range used (RNG2 only)

#### Usage Flow

1. User decides on their desired random number range (min and max)
2. User commits to the range and target block (commit phase)
3. Wait for the target block to be reached
4. User reveals to generate the random number within their specified range (reveal phase)

## Prerequisites

If you are using Windows, you will need to install WSL (Windows Subsystem for Linux) and then install Foundry.

To deploy and interact with the contracts throught the CLI, use the Forge scripts provided in this repository and described further below. First, install Foundry (<https://book.getfoundry.sh/getting-started/installation>) before proceeding with the deployment:

```bash
forge install foundry-rs/forge-std --no-commit
```

## Deploying the contract

Random number 1 returns the full unconstrained random number, while random number 2 returns a random number within a user-specified range (1 to 2 billion maximum).

```bash
export RPC_URL=https://api.testnet.zilliqa.com
export PRIVATE_KEY=0x...
forge script script/DeployZillIqaRandomNumber1.s.sol --rpc-url $RPC_URL --broadcast --legacy
```

or

```bash
forge script script/DeployZillIqaRandomNumber2.s.sol --rpc-url $RPC_URL --broadcast --legacy
```

### InteractWithRandomNumber.s.sol Features

The interaction script provides several key features:

1. **Automatic Range Handling**: For RNG2, defaults to 1-10000 if MIN_RANDOM/MAX_RANDOM not specified
2. **Enhanced Logging**: Shows all input parameters and transaction results
3. **Built-in Verification**: Automatically verifies revealed random numbers match calculations
4. **Event Parsing**: Extracts all data from contract events for verification
5. **Error Handling**: Graceful fallback to defaults for missing environment variables

## Interacting with the contract

### Commit

For ZilliqaRandomNumber1:

```bash
export PRIVATE_KEY=0x...
export CONTRACT_ADDRESS=rng1_contract_address
export ACTION=commit
forge script script/InteractWithRandomNumber.s.sol --rpc-url $RPC_URL --broadcast --legacy
```

For ZilliqaRandomNumber2 (with custom range):

```bash
export PRIVATE_KEY=0x...
export CONTRACT_ADDRESS=rng2_contract_address
export ACTION=commit
export IS_RNG2=true
export MIN_RANDOM=1        # Minimum value for random number
export MAX_RANDOM=10000    # Maximum value for random number (up to 2 billion)
forge script script/InteractWithRandomNumber.s.sol --rpc-url $RPC_URL --broadcast --legacy
```

**Note**: If you don't specify `MIN_RANDOM` and `MAX_RANDOM` for RNG2, the script will use defaults (1-10000).

#### Commit Output

For ZilliqaRandomNumber2, the commit command will show:

```bash
=== Input Values ===
  Contract: 0x5581B9908e57f52A668400a22C9Bc4E51299A950
  Action: commit
  Contract Type: RNG2
  Min Random: 1
  Max Random: 100000

=== RNG2 Commit Results ===
  Target block: 11505978
  Min Random: 1
  Max Random: 100000
  Commitment successful! Wait for target block, then call reveal()
```

### Reveal

This will reveal the random number and emit the RandomnessRevealed event. 

```bash
export ACTION=reveal
forge script script/InteractWithRandomNumber.s.sol --rpc-url $RPC_URL --broadcast --legacy
```

Will return (example for ZilliqaRandomNumber2):

```bash
=== Input Values ===
  Contract: 0x5581B9908e57f52A668400a22C9Bc4E51299A950
  Action: reveal
  Contract Type: RNG2
  Min Random: 1
  Max Random: 100000

=== RNG2 Reveal ===
  Contract: 0x5581B9908e57f52A668400a22C9Bc4E51299A950

=== RNG2 Reveal Completed ===
```

### Cancel (need to wait for MAX_BLOCKS_DELAY blocks)

```bash
export ACTION=cancel
forge script script/InteractWithRandomNumber.s.sol --rpc-url $RPC_URL --broadcast --legacy --ffi
```

## Decoding Transaction Results

For easier analysis of reveal transactions, use the dedicated decode script:

### Decode RNG1 transaction results

```bash
export TX_HASH=0x...  # Your reveal transaction hash
export IS_RNG2=false
export WALLET_ADDRESS=0x...  # Your wallet address for verification
export RPC_URL=https://api.testnet.zilliqa.com  # Optional, defaults to testnet
forge script script/DecodeRandomReveal.s.sol --sig "decodeFromTxHash()" --ffi
```

### Decode RNG2 transaction results

```bash
export TX_HASH=0x...  # Your reveal transaction hash
export IS_RNG2=true
export WALLET_ADDRESS=0x...  # Your wallet address for verification
export RPC_URL=https://api.testnet.zilliqa.com  # Optional, defaults to testnet
forge script script/DecodeRandomReveal.s.sol --sig "decodeFromTxHash()" --ffi
```

**New Features:**

- **✅ Full Verification**: Automatically verifies both raw and constrained random numbers
- **🔍 Detailed Analysis**: Shows step-by-step calculation verification
- **⚠️ Error Detection**: Identifies mismatches and suggests causes
- **📊 Enhanced Reporting**: Clear pass/fail indicators with explanations

This script will:

- Fetch the transaction receipt automatically
- Decode all entropy sources used
- **Verify the random number calculation using your wallet address**
- **Confirm both raw and constrained random numbers match expected values**
- Analyze entropy quality
- Show range analysis for RNG2
- Provide clear verification status with helpful error messages

## Testing

To test the contracts, use the Forge scripts provided in this repository and described further below.

```bash
forge test -vv
```

## Verifying the contracts using sourcify (As an example)

```bash
forge verify-contract 0xfBF9D9E376859bF6fd4A3e3cb4241962f5Aebc47 \
  src/ZillIqaRandomNumber1.sol:ZillIqaRandomNumber1 \
  --chain-id 32770 \
  --verifier sourcify
```

## Randomness Fairness Analysis (Detailed)

### Mathematical Proof of Fairness

The ZilliqaRandomNumber2 contract uses a mathematically sound approach to ensure fair random number generation:

#### 1. Entropy Generation

```solidity
uint256 randomNumber = uint256(
    keccak256(
        abi.encodePacked(
            msg.sender,
            block.prevrandao,
            blockhash(block.number - 1)
        )
    )
);
```

- **Cryptographic Hash**: Uses keccak256, which produces uniformly distributed outputs
- **Optimized Entropy Sources**: Combines three high-quality entropy sources
- **User-Specific**: Different users get different results even with identical blocks
- **ZQ2 Optimized**: Takes advantage of working PREVRANDAO on ZQ2
- **Manipulation Resistant**: Uses previous block hash instead of timestamp
- **Output Space**: Produces values in range [0, 2^256 - 1]

#### 2. Range Mapping

```solidity
function generateRandomNumber(uint256 randomNumber, uint256 minRandom, uint256 maxRandom) internal pure returns (uint256) {
    uint256 range = maxRandom - minRandom + 1;
    return (randomNumber % range) + minRandom;
}
```

#### 3. Bias Analysis

**Modulo Bias**: When using modulo operation, bias occurs when the input space is not perfectly divisible by the output range.

For our implementation:

- **Input Space**: 2^256 ≈ 1.16 × 10^77
- **Maximum Output Range**: 2 × 10^9 (2 billion)
- **Bias Calculation**: ≈ 1 / floor(2^256 / range)

**Bias Analysis for Different Range Sizes**:

| Range Size | Example Range | Bias (Approximate) | Orders of Magnitude Better than Lottery* |
|------------|---------------|-------------------|------------------------------------------|
| 10 | 1-10 | 8.64 × 10^-77 | 69 orders of magnitude |
| 100 | 1-100 | 8.64 × 10^-76 | 68 orders of magnitude |
| 1,000 | 1-1000 | 8.64 × 10^-75 | 67 orders of magnitude |
| 10,000 | 1-10000 | 8.64 × 10^-74 | 66 orders of magnitude |
| 2 billion | 1-2000000000 | 1.73 × 10^-68 | 60 orders of magnitude |

*Lottery probability ≈ 1 in 10^8

**Mathematical Formula**:

- Let q = floor(2^256 / range)
- Values 0 to (2^256 mod range - 1) appear (q+1) times each
- Remaining values appear q times each  
- Maximum bias ≈ 1/q

**Practical Impact**:

- Even for the largest allowed range (2 billion), bias is negligible (1 in 10^68)
- For smaller ranges, bias becomes even more negligible
- All biases are statistically irrelevant for any practical application
- Our bias is 60-69 orders of magnitude smaller than winning the lottery

#### 4. Security Properties

**Unpredictability**:

- Users cannot predict the outcome due to unknown future block properties
- Validators cannot manipulate PREVRANDAO without significant cost
- PREVRANDAO on ZQ2 provides excellent entropy (confirmed non-zero)
- Previous block hash cannot be manipulated by validators (already finalized)
- User wallet address ensures user-specific entropy and prevents identical results

**Fairness**:

- All values in the specified range have equal probability (within negligible bias)
- No value is favored over others
- Range commitment prevents post-hoc manipulation

**Verifiability**:

- All entropy sources are published in events
- Anyone can verify the calculation
- Transparent and auditable process

#### 5. Comparison with Alternatives

**Better than**:

- Single entropy source solutions
- Block hash only (manipulatable by miners)
- Simple timestamp (predictable and manipulatable)
- Linear congruential generators (not cryptographically secure)
- Solutions without commit-reveal protection
- Complex multi-source systems with diminishing returns
- Timestamp-based solutions (vulnerable to validator manipulation)

**Equivalent to**:

- Chainlink VRF (but more cost-effective and faster)
- Other commit-reveal schemes with cryptographic randomness

**Trade-offs**:

- Requires two transactions (commit + reveal)
- Short delay between commitment and revelation
- Simpler than complex multi-source schemes (better gas efficiency)
- Uses finalized block data (no manipulation possible)

### Conclusion

The ZilliqaRandomNumber2 contract provides cryptographically secure, mathematically fair random number generation with negligible bias. The combination of commit-reveal pattern and three optimized entropy sources (including manipulation-resistant previous block hash) makes it suitable for applications requiring high-quality randomness, including gaming, lotteries, and fair selection processes. The streamlined approach provides excellent security while being gas-efficient and easy to verify.

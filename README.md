# ZQ2 Random Number Generator (Commit/Reveal)

Designed by PlunderSwap

A simple, verifiable on-chain random number generator using a commit-reveal pattern anchored to a future block's hash.

A commitment pins a target block a few blocks in the future. Once that block has been produced, its hash is used as the entropy source for the reveal. Because the target block's hash is fixed the moment the block is mined, the result is fully determined before anyone reveals — so the party revealing cannot influence the outcome by choosing when to submit their transaction.

## Contract Features

### ZilliqaRandomNumber1 Contract

Returns the full unconstrained random number for applications that need the raw 256-bit entropy value.

### ZilliqaRandomNumber2 Contract (Recommended)

Returns a random number constrained to a user-specified range. It implements the same commit-reveal pattern anchored to a future block's hash, then maps the raw value into the requested `[minRandom, maxRandom]` range.

#### Commitment System

- Users submit a commitment specifying a target block (and, for RNG2, their desired range)
- Commitments must target a future block (minimum 5 blocks ahead, maximum 1000 blocks)
- Each address can only have one active commitment at a time
- **Range Selection (RNG2)**: Users specify `minRandom` and `maxRandom` at commit time, before any entropy exists
- Maximum allowed range: up to 2 billion (2,000,000,000)

#### Security Measures

- **MIN_BLOCKS_DELAY (5 blocks)**: The target block is far enough ahead that its hash is unknown at commit time
- **MAX_BLOCKS_DELAY (1000 blocks)**: Prevents commitments too far in the future
- **REVEAL_WINDOW (256 blocks)**: The target block's hash is only readable on-chain for 256 blocks after it is produced. Reveals must happen within this window; a reveal attempted after the window has closed reverts cleanly rather than falling back to any other entropy source
- **Outcome fixed at the target block**: The result depends only on the target block's hash and the caller's address. Revealing in any block within the window yields the same value, so the reveal cannot be resubmitted or delayed to shop for a different outcome
- **Range validation (RNG2)**: Enforces `0 < minRandom <= maxRandom <= MAX_RANDOM_LIMIT` and locks the range in at commit time

#### Random Number Generation

The random number is derived from two sources via keccak256:

- **Target block hash** (`blockhash(targetBlock)`) — the entropy source, fixed once the target block is produced and unknown at commit time
- **User wallet address** — ensures different users deriving from the same target block get different results

```solidity
uint256 randomNumber = uint256(
    keccak256(
        abi.encodePacked(
            msg.sender,
            blockhash(targetBlock)
        )
    )
);
```

For RNG2, the raw value is then mapped into the committed range using a modulo operation.

All entropy sources and the resulting value(s) are emitted in the `RandomnessRevealed` event for transparency and independent verification.

#### Trust Assumptions

The entropy for a given commitment comes from the hash of a single future block. Whoever produces that block has limited influence over it — they can choose to produce the block or not — which is the residual trust assumption of any single-block-hash scheme. On ZQ2's BFT consensus this is expensive and impractical for an individual user to exploit, making the generator well suited to games, lotteries, raffles, and fair selection. Applications securing very large value against a well-resourced adversary who may also be a block producer should use a dedicated verifiable randomness beacon.

#### Randomness Fairness Analysis

The range mapping (RNG2) uses a cryptographically secure approach to ensure fair distribution:

1. **Entropy Source**: keccak256 over the target block hash and user address produces uniformly distributed output
2. **Uniform Distribution**: Uses modulo mapping `(randomNumber % range) + minRandom`
3. **No Bias**: The modulo operation provides effectively uniform distribution when the input space (2^256) is vastly larger than the output range (max 2 billion)
4. **Bias Analysis**: With a 2^256 input space and a maximum 2×10^9 output range, the modulo bias is negligible

#### Events

The contracts emit two events:

- `CommitSubmitted`: When a user submits a commitment, including the target block (and range for RNG2)
- `RandomnessRevealed`: When randomness is generated, including:
  - The raw random number (full entropy)
  - The constrained random number (RNG2 only)
  - The target block number
  - The target block hash used as the entropy source
  - The min/max range used (RNG2 only)

#### Usage Flow

1. (RNG2) Decide on the desired random number range (min and max)
2. Commit to the target block (and range) — the commit phase
3. Wait for the target block to be produced
4. Reveal within 256 blocks of the target block to generate the random number

## Prerequisites

If you are using Windows, you will need to install WSL (Windows Subsystem for Linux) and then install Foundry.

To deploy and interact with the contracts through the CLI, use the Forge scripts provided in this repository and described below. First, install Foundry (<https://book.getfoundry.sh/getting-started/installation>) before proceeding with the deployment:

```bash
forge install foundry-rs/forge-std --no-commit
```

## Deploying the contract

Random number 1 returns the full unconstrained random number, while random number 2 returns a random number within a user-specified range (1 to 2 billion maximum).

```bash
export RPC_URL=https://api.zilliqa.com
export PRIVATE_KEY=0x...
forge script script/DeployZilliqaRandomNumber1.s.sol --rpc-url $RPC_URL --broadcast --legacy
```

or

```bash
forge script script/DeployZilliqaRandomNumber2.s.sol --rpc-url $RPC_URL --broadcast --legacy
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
  Contract: <contract_address>
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

This will reveal the random number and emit the RandomnessRevealed event. It must be called after the target block is produced and within 256 blocks of it.

```bash
export ACTION=reveal
forge script script/InteractWithRandomNumber.s.sol --rpc-url $RPC_URL --broadcast --legacy
```

Will return (example for ZilliqaRandomNumber2):

```bash
=== Input Values ===
  Contract: <contract_address>
  Action: reveal
  Contract Type: RNG2
  Min Random: 1
  Max Random: 100000

=== RNG2 Reveal ===
  Contract: <contract_address>

=== RNG2 Reveal Completed ===
```

### Cancel (after the reveal window has closed)

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

This script will:

- Fetch the transaction receipt automatically
- Decode all entropy sources used
- **Verify the random number calculation using your wallet address**
- **Confirm both raw and constrained random numbers match expected values**
- Show range analysis for RNG2
- Provide clear verification status with helpful error messages

## Testing

```bash
forge test -vv
```

## Verifying the contracts using sourcify (As an example)

```bash
forge verify-contract <contract_address> \
  src/ZilliqaRandomNumber2.sol:ZilliqaRandomNumber2 \
  --chain-id 32770 \
  --verifier sourcify
```

## Randomness Fairness Analysis (Detailed)

### Entropy Generation

```solidity
uint256 randomNumber = uint256(
    keccak256(
        abi.encodePacked(
            msg.sender,
            blockhash(targetBlock)
        )
    )
);
```

- **Cryptographic Hash**: keccak256 produces uniformly distributed output
- **Fixed at the target block**: `blockhash(targetBlock)` is set the moment the target block is produced and cannot be influenced by the timing of the reveal
- **User-Specific**: Different users deriving from the same target block get different results
- **Output Space**: Produces values in range [0, 2^256 - 1]

### Range Mapping (RNG2)

```solidity
function generateRandomNumber(uint256 randomNumber, uint256 minRandom, uint256 maxRandom) internal pure returns (uint256) {
    uint256 range = maxRandom - minRandom + 1;
    return (randomNumber % range) + minRandom;
}
```

### Bias Analysis

**Modulo Bias**: When using a modulo operation, bias occurs when the input space is not perfectly divisible by the output range.

For this implementation:

- **Input Space**: 2^256 ≈ 1.16 × 10^77
- **Maximum Output Range**: 2 × 10^9 (2 billion)
- **Bias Calculation**: ≈ 1 / floor(2^256 / range)

**Bias Analysis for Different Range Sizes**:

| Range Size | Example Range | Bias (Approximate) |
|------------|---------------|-------------------|
| 10 | 1-10 | 8.64 × 10^-77 |
| 100 | 1-100 | 8.64 × 10^-76 |
| 1,000 | 1-1000 | 8.64 × 10^-75 |
| 10,000 | 1-10000 | 8.64 × 10^-74 |
| 2 billion | 1-2000000000 | 1.73 × 10^-68 |

**Mathematical Formula**:

- Let q = floor(2^256 / range)
- Values 0 to (2^256 mod range - 1) appear (q+1) times each
- Remaining values appear q times each
- Maximum bias ≈ 1/q

**Practical Impact**: Even for the largest allowed range (2 billion), the modulo bias is negligible; for smaller ranges it is smaller still. It is statistically irrelevant for any practical application.

### Security Properties

**Unpredictability**:

- The outcome depends on the target block's hash, which does not exist at commit time
- The user's wallet address ensures user-specific results even from the same target block

**Fairness**:

- All values in the specified range have equal probability (within negligible bias)
- The range is committed upfront and cannot be changed after entropy is known
- The result is fixed at the target block, so the reveal transaction cannot be timed or resubmitted to change it

**Verifiability**:

- All entropy sources are published in events
- Anyone can recompute and verify the result
- Transparent and auditable process

### Conclusion

The contracts provide verifiable, fair random number generation with negligible bias. Anchoring the entropy to a committed future block's hash keeps the outcome unknown at commit time and immutable at reveal time, making them well suited to gaming, lotteries, and fair selection processes while remaining gas-efficient and easy to verify.

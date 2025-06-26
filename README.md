# ShuffleStake - Foundry/Forge Boilerplate

A complete Foundry/Forge project boilerplate featuring a lottery token that distributes 5 tokens to 5 random users each epoch using Chainlink VRF for provably fair randomness.

## Features

- **LotteryToken Contract**: A lottery system that distributes tokens to random winners each epoch
- **Chainlink VRF Integration**: Provably fair randomness using Chainlink VRF
- **Epoch-based Distribution**: New winners selected every Ethereum epoch (384 seconds)
- **Dynamic Balance Calculation**: Balances calculated on-the-fly using shuffle-or-not algorithm
- **Efficient User Management**: O(1) insertion and removal of users
- **Comprehensive Tests**: Unit tests, integration tests, and gas tests
- **Deployment Scripts**: Ready-to-use deployment scripts with VRF configuration

## Contract Features

### LotteryToken.sol
- **Epoch-based Lottery**: Distributes 5 tokens to 5 random users each epoch
- **Chainlink VRF**: Uses Chainlink VRF for provably fair randomness
- **Dynamic Balances**: Balances calculated dynamically without storage
- **User Management**: Add/remove users with efficient array operations
- **Shuffle-or-not Algorithm**: Deterministic winner selection based on random seed
- **Access Control**: Only owner can add/remove users and request randomness

## Project Structure

```
├── src/
│   └── ShuffleStakeToken.sol    # Main lottery token contract
├── test/
│   ├── ShuffleStakeToken.t.sol  # Comprehensive test suite
│   └── ShuffleStakeToken.invariant.t.sol  # Invariant tests
├── script/
│   ├── Deploy.s.sol             # Deployment script
│   └── Interact.s.sol           # Interaction script
├── foundry.toml                 # Foundry configuration
├── remappings.txt               # Import remappings
├── .gitignore                   # Git ignore file
├── Makefile                     # Common commands
├── env.example                  # Environment variables template
└── README.md                    # This file
```

## Prerequisites

- [Foundry](https://getfoundry.sh/) - Ethereum development toolkit
- Git
- Chainlink VRF Subscription (for mainnet/testnet deployment)

## Installation

1. **Install Foundry** (if not already installed):
   ```bash
   curl -L https://foundry.paradigm.xyz | bash
   foundryup
   ```

2. **Clone and setup the project**:
   ```bash
   git clone <your-repo-url>
   cd shuffle-stake
   forge install
   ```

3. **Install dependencies**:
   ```bash
   forge install OpenZeppelin/openzeppelin-contracts
   forge install foundry-rs/forge-std
   forge install smartcontractkit/chainlink
   ```

## Usage

### Compile Contracts
```bash
forge build
```

### Run Tests
```bash
# Run all tests
forge test

# Run tests with verbose output
forge test -vv

# Run tests with gas reporting
forge test --gas-report

# Run specific test
forge test --match-test test_AddUser

# Run fuzz tests
forge test --match-test testFuzz
```

### Run Tests with Coverage
```bash
forge coverage
```

### Deploy Contract

1. **Set up environment variables**:
   ```bash
   export PRIVATE_KEY=your_private_key_here
   export RPC_URL=your_rpc_url_here
   export VRF_COORDINATOR=your_vrf_coordinator_address
   export SUBSCRIPTION_ID=your_subscription_id
   export GAS_LANE=your_gas_lane_key_hash
   export CALLBACK_GAS_LIMIT=500000
   ```

2. **Deploy to local network**:
   ```bash
   # Start local node
   anvil
   
   # In another terminal, deploy
   forge script script/Deploy.s.sol --rpc-url http://localhost:8545 --broadcast
   ```

3. **Deploy to testnet/mainnet**:
   ```bash
   forge script script/Deploy.s.sol --rpc-url $RPC_URL --broadcast --verify
   ```

### Verify Contract
```bash
forge verify-contract <contract_address> src/ShuffleStakeToken.sol:LotteryToken --chain-id <chain_id>
```

## Contract Functions

### Public Functions
- `name()` - Returns token name ("LotteryToken")
- `symbol()` - Returns token symbol ("LOTTO")
- `decimals()` - Returns token decimals (0)
- `totalSupply()` - Returns total supply (always 5)
- `balanceOf(address user)` - Returns user's balance (0 or 1)
- `getCurrentEpoch()` - Returns current epoch number
- `getAllUsers()` - Returns array of all users
- `getUserCount()` - Returns number of users
- `isRandomnessAvailable()` - Returns if randomness is available
- `isWinner(address user)` - Returns if user is a winner
- `getWinners()` - Returns array of current winners

### Owner Functions
- `addUser(address user)` - Adds user to lottery
- `removeUser(address user)` - Removes user from lottery
- `forceRequestRandomness()` - Forces randomness request (for testing)
- `transferOwnership(address newOwner)` - Transfers ownership

### Constants
- `TOTAL_SUPPLY` - 5 tokens
- `WINNERS_PER_EPOCH` - 5 winners per epoch
- `EPOCH_DURATION` - 384 seconds (12 * 32)

## Lottery Mechanics

### Epoch System
- Each epoch lasts 384 seconds (Ethereum epoch duration)
- At the start of each epoch, new randomness is requested from Chainlink VRF
- Winners are selected based on the random seed and remain constant throughout the epoch

### Winner Selection
- Uses a deterministic shuffle-or-not algorithm
- Each user's position is shuffled based on the random seed
- Top 5 shuffled positions become winners
- Winners receive 1 token each, others receive 0

### User Management
- Users can be added/removed by the contract owner
- Efficient O(1) removal using array swapping
- User indices are tracked for quick lookups

## Test Coverage

The test suite includes:

- **Constructor Tests**: Verify initial state and VRF configuration
- **User Management Tests**: Test adding/removing users
- **Epoch Management Tests**: Test epoch changes and randomness requests
- **Winner Selection Tests**: Test winner determination logic
- **Balance Calculation Tests**: Test dynamic balance calculation
- **Integration Tests**: End-to-end lottery workflow
- **Gas Tests**: Gas usage measurement
- **Edge Cases**: Various edge cases and error conditions

## Development

### Adding New Tests
1. Create test functions in `test/ShuffleStakeToken.t.sol`
2. Use `forge test --match-test <test_name>` to run specific tests
3. Use `forge test -vv` for verbose output

### Adding New Contracts
1. Create contract in `src/` directory
2. Add tests in `test/` directory
3. Update `foundry.toml` if needed
4. Update `remappings.txt` for new dependencies

### Code Style
- Follow Solidity style guide
- Use NatSpec comments for public functions
- Include comprehensive tests for all functions
- Use meaningful variable and function names

## Security Considerations

- **Access Control**: Only owner can add/remove users and request randomness
- **Randomness**: Uses Chainlink VRF for provably fair randomness
- **Deterministic Selection**: Winner selection is deterministic within each epoch
- **Gas Efficiency**: Dynamic balance calculation avoids storage costs
- **Input Validation**: All inputs are validated
- **Reentrancy**: Uses OpenZeppelin's secure implementations

## Chainlink VRF Setup

### For Testing
- Use VRFCoordinatorV2Mock for local testing
- No subscription required for mock

### For Testnet/Mainnet
1. Create a Chainlink VRF subscription
2. Fund the subscription with LINK tokens
3. Add your contract as a consumer
4. Configure environment variables with your subscription details

### Network-specific VRF Addresses
- **Mainnet**: `0x271682DEB8C4E0901D1a1550aD2e64D568E69909`
- **Sepolia**: `0x6090F6A2884B1bEa31a3B8D6C5C5aC3c7401B5e9`
- **Mumbai**: `0x7a1BaC17Ccc5b313516C5E16fb24f7659aA5ebed`

## License

MIT License - see LICENSE file for details

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests for new functionality
5. Run the test suite
6. Submit a pull request

## Support

For questions and support:
- Create an issue in the repository
- Check the Foundry documentation: https://book.getfoundry.sh/
- Check the OpenZeppelin documentation: https://docs.openzeppelin.com/
- Check the Chainlink VRF documentation: https://docs.chain.link/vrf/v2/introduction

.PHONY: help build test test-verbose test-gas coverage clean deploy-local deploy-testnet install-deps format snapshot

# Default target
help:
	@echo "Available commands:"
	@echo "  build          - Compile contracts"
	@echo "  test           - Run tests"
	@echo "  test-verbose   - Run tests with verbose output"
	@echo "  test-gas       - Run tests with gas reporting"
	@echo "  coverage       - Run tests with coverage"
	@echo "  clean          - Clean build artifacts"
	@echo "  deploy-local   - Deploy to local network"
	@echo "  deploy-testnet - Deploy to testnet (requires env vars)"
	@echo "  install-deps   - Install dependencies"
	@echo "  format         - Format code"
	@echo "  snapshot       - Create gas snapshot"

# Build contracts
build:
	forge build

# Run tests
test:
	forge test

# Run tests with verbose output
test-verbose:
	forge test -vv

# Run tests with gas reporting
test-gas:
	forge test --gas-report

# Run tests with coverage
coverage:
	forge coverage

# Clean build artifacts
clean:
	forge clean

# Deploy to local network
deploy-local:
	@echo "Starting local network..."
	@echo "Run 'anvil' in another terminal, then execute:"
	@echo "forge script script/Deploy.s.sol --rpc-url http://localhost:8545 --broadcast"

# Deploy to testnet (requires PRIVATE_KEY and RPC_URL env vars)
deploy-testnet:
	@if [ -z "$$PRIVATE_KEY" ]; then \
		echo "Error: PRIVATE_KEY environment variable not set"; \
		exit 1; \
	fi
	@if [ -z "$$RPC_URL" ]; then \
		echo "Error: RPC_URL environment variable not set"; \
		exit 1; \
	fi
	@if [ -z "$$VRF_COORDINATOR" ]; then \
		echo "Error: VRF_COORDINATOR environment variable not set"; \
		exit 1; \
	fi
	@if [ -z "$$SUBSCRIPTION_ID" ]; then \
		echo "Error: SUBSCRIPTION_ID environment variable not set"; \
		exit 1; \
	fi
	forge script script/Deploy.s.sol --rpc-url $$RPC_URL --broadcast --verify

# Install dependencies
install-deps:
	forge install OpenZeppelin/openzeppelin-contracts
	forge install foundry-rs/forge-std
	forge install smartcontractkit/chainlink

# Format code
format:
	forge fmt

# Create gas snapshot
snapshot:
	forge snapshot

# Run specific test
test-specific:
	@if [ -z "$(TEST)" ]; then \
		echo "Usage: make test-specific TEST=test_name"; \
		exit 1; \
	fi
	forge test --match-test $(TEST)

# Run fuzz tests
test-fuzz:
	forge test --match-test testFuzz

# Run integration tests
test-integration:
	forge test --match-test test_CompleteLotteryWorkflow

# Run user management tests
test-user-management:
	forge test --match-test test_AddUser --match-test test_RemoveUser

# Run epoch tests
test-epoch:
	forge test --match-test test_GetCurrentEpoch --match-test test_CheckEpochChange

# Run winner selection tests
test-winners:
	forge test --match-test test_IsWinner --match-test test_GetWinners

# Start local node
anvil:
	anvil

# Verify contract (requires CONTRACT_ADDRESS and CHAIN_ID env vars)
verify:
	@if [ -z "$$CONTRACT_ADDRESS" ]; then \
		echo "Error: CONTRACT_ADDRESS environment variable not set"; \
		exit 1; \
	fi
	@if [ -z "$$CHAIN_ID" ]; then \
		echo "Error: CHAIN_ID environment variable not set"; \
		exit 1; \
	fi
	forge verify-contract $$CONTRACT_ADDRESS src/ShuffleStakeToken.sol:ShuffleToken --chain-id $$CHAIN_ID

# Run interaction script
interact:
	@if [ -z "$$PRIVATE_KEY" ]; then \
		echo "Error: PRIVATE_KEY environment variable not set"; \
		exit 1; \
	fi
	forge script script/Interact.s.sol --rpc-url http://localhost:8545 --broadcast

# Run interaction script on testnet
interact-testnet:
	@if [ -z "$$PRIVATE_KEY" ]; then \
		echo "Error: PRIVATE_KEY environment variable not set"; \
		exit 1; \
	fi
	@if [ -z "$$RPC_URL" ]; then \
		echo "Error: RPC_URL environment variable not set"; \
		exit 1; \
	fi
	forge script script/Interact.s.sol --rpc-url $$RPC_URL --broadcast 
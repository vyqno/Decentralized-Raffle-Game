.PHONY: all test clean install update build format coverage snapshot help

# Default target
all: clean install update build test

# Help
help:
	@echo "Usage:"
	@echo "  make install    - Install dependencies"
	@echo "  make update     - Update dependencies"
	@echo "  make build      - Build the project"
	@echo "  make test       - Run all tests"
	@echo "  make test-unit  - Run unit tests only"
	@echo "  make test-integration - Run integration tests only"
	@echo "  make coverage   - Generate coverage report"
	@echo "  make snapshot   - Update gas snapshots"
	@echo "  make format     - Format code"
	@echo "  make clean      - Clean build artifacts"

# Install dependencies
install:
	@echo "Installing dependencies..."
	forge install

# Update dependencies
update:
	@echo "Updating dependencies..."
	forge update

# Build the project
build:
	@echo "Building project..."
	forge build

# Run all tests
test:
	@echo "Running all tests..."
	forge test -vvv

# Run unit tests only
test-unit:
	@echo "Running unit tests..."
	forge test --match-path "test/unit/*.sol" -vvv

# Run integration tests only
test-integration:
	@echo "Running integration tests..."
	forge test --match-path "test/integration/*.sol" -vvv

# Run specific test
test-contract:
	@echo "Running tests for specific contract..."
	forge test --match-contract $(filter-out $@,$(MAKECMDGOALS)) -vvv

# Generate coverage report
coverage:
	@echo "Generating coverage report..."
	forge coverage --report lcov
	@echo "Coverage report generated!"
	@echo "To view detailed coverage:"
	@echo "  forge coverage --report summary"

# Coverage with summary
coverage-summary:
	@echo "Generating coverage summary..."
	forge coverage --report summary

# Coverage report in detail
coverage-detail:
	@echo "Generating detailed coverage..."
	forge coverage

# Update gas snapshots
snapshot:
	@echo "Updating gas snapshots..."
	forge snapshot

# Format code
format:
	@echo "Formatting code..."
	forge fmt

# Check code formatting
format-check:
	@echo "Checking code formatting..."
	forge fmt --check

# Clean build artifacts
clean:
	@echo "Cleaning build artifacts..."
	forge clean

# Deploy to local Anvil
deploy-local:
	@echo "Deploying to local Anvil..."
	forge script script/DeployRaffle.s.sol --rpc-url http://127.0.0.1:8545 --broadcast

# Deploy to Sepolia
deploy-sepolia:
	@echo "Deploying to Sepolia..."
	forge script script/DeployRaffle.s.sol --rpc-url $(SEPOLIA_RPC_URL) --broadcast --verify --etherscan-api-key $(ETHERSCAN_API_KEY)

# Run slither static analysis (if installed)
slither:
	@echo "Running Slither analysis..."
	slither .

# Catch-all target for flexibility
%:
	@:

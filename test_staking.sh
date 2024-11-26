#!/bin/bash

# Get RPC from existing configuration
if [ ! -f ".trader_runner/rpc.txt" ]; then
    echo "Error: RPC configuration not found in .trader_runner/rpc.txt"
    exit 1
fi

# Initialize variables
GNOSIS_RPC=$(cat .trader_runner/rpc.txt)
FORK_RPC="http://localhost:8545"
TEST_STORE=".trader_runner_test"
OLAS_TOKEN="0xcE11e14225575945b8E6Dc0D4F2dD4C570f79d9f"  # OLAS token on Gnosis
STAKING_CONTRACT="0x5344B7DD311e5d3DdDd46A4f71481bD7b05AAA3e"  # Example staking contract
MINT_AMOUNT="1000000000000000000000"  # 1000 OLAS

echo "Using RPC from configuration: $GNOSIS_RPC"

# Create test directory structure
setup_test_environment() {
    echo "Setting up test environment..."
    
    # Create test directory mirroring production
    if [ -d "$TEST_STORE" ]; then
        echo "Cleaning up existing test environment..."
        rm -rf "$TEST_STORE"
    fi
    
    # Copy production files to test environment
    if [ -d ".trader_runner" ]; then
        echo "Copying configuration from production environment..."
        cp -r .trader_runner "$TEST_STORE"
        
        # Update RPC in test environment
        echo "$FORK_RPC" > "$TEST_STORE/rpc.txt"
        
        # Update .env file to point to test staking program
        echo "STAKING_PROGRAM=quickstart_beta_expert" >> "$TEST_STORE/.env"
        echo "USE_STAKING=true" >> "$TEST_STORE/.env"
        echo "CUSTOM_STAKING_ADDRESS=$STAKING_CONTRACT" >> "$TEST_STORE/.env"
        echo "CUSTOM_OLAS_ADDRESS=$OLAS_TOKEN" >> "$TEST_STORE/.env"
        
        # Create test keys if needed
        echo "Setting up test keys..."
        cd trader
        poetry run autonomy generate-key -n1 ethereum
        mv keys.json "../$TEST_STORE/operator_keys.json"
        poetry run autonomy generate-key -n1 ethereum
        mv keys.json "../$TEST_STORE/keys.json"
        cd ..
    else
        echo "Error: Production environment not found. Please run run_service.sh first."
        exit 1
    fi
}

# Start local Ganache fork with verbose output
start_fork() {
    echo "Starting Ganache fork of Gnosis Chain..."
    echo "Using RPC: $GNOSIS_RPC"
    
    # Kill any existing Ganache instance
    pkill -f "ganache" || true
    
    # Start Ganache with forking enabled
    ganache \
        --fork.url "$GNOSIS_RPC" \
        --fork.blockNumber "latest" \
        --miner.blockTime 1 \
        --chain.chainId 100 \
        --server.port 8545 \
        --server.host "0.0.0.0" \
        --miner.defaultGasLimit 12000000 \
        --wallet.unlockedAccounts "$OLAS_TOKEN" \
        --wallet.deterministic \
        --wallet.accounts="0x$(cat $TEST_STORE/operator_pkey.txt),100000000000000000000"
    
    # Wait for Ganache to start
    sleep 5
    
    # Check if Ganache is running
    if ! curl -s -X POST -H "Content-Type: application/json" \
        --data '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' \
        "$FORK_RPC" > /dev/null; then
        echo "Error: Failed to start Ganache fork"
        exit 1
    fi
    
    echo "Ganache fork running at $FORK_RPC"
}


# Setup test tokens
setup_test_tokens() {
    echo "Setting up test tokens..."
    
    # Get operator address
    local operator_address=$(python3 -c "import json; print(json.load(open('$TEST_STORE/operator_keys.json'))[0]['address'])")
    
    # Create and run script to mint tokens
    cat > mint_tokens.js <<EOL
const Web3 = require('web3');
const web3 = new Web3('${FORK_RPC}');

const OLAS_ABI = [{"inputs":[{"internalType":"address","name":"account","type":"address"},{"internalType":"uint256","name":"amount","type":"uint256"}],"name":"mint","outputs":[],"stateMutability":"nonpayable","type":"function"}];

async function mintTokens() {
    const olasContract = new web3.eth.Contract(OLAS_ABI, '${OLAS_TOKEN}');
    
    // Mint OLAS tokens to operator
    await olasContract.methods.mint('${operator_address}', '${MINT_AMOUNT}').send({
        from: '${OLAS_TOKEN}',
        gas: 200000
    });
    
    console.log('Minted ${MINT_AMOUNT} OLAS to ${operator_address}');
}

mintTokens().then(() => process.exit(0)).catch(console.error);
EOL

    # Run the minting script
    node mint_tokens.js
    rm mint_tokens.js
}

# Test quick staking functionality
test_quick_stake() {
    echo "Testing quick stake functionality..."
    
    # Backup original .trader_runner
    if [ -d ".trader_runner" ]; then
        mv .trader_runner .trader_runner_backup
    fi
    
    # Use test environment
    mv "$TEST_STORE" .trader_runner
    
    # Run quick stake
    ./quick_stake.sh
    result=$?
    
    # Restore original .trader_runner
    rm -rf .trader_runner
    if [ -d ".trader_runner_backup" ]; then
        mv .trader_runner_backup .trader_runner
    fi
    
    return $result
}

install_dependencies() {
    echo "Installing dependencies..."
    
    # Check if ganache is installed
    if ! command -v ganache &> /dev/null; then
        echo "Installing ganache..."
        npm install -g ganache
    fi
    
    # Install web3 for token minting
    npm install web3
}


# Main test flow
main() {
    echo "Starting staking test environment..."
    
    install_dependencies
    setup_test_environment
    start_fork
    setup_test_tokens
    
    echo "Test environment ready. Running tests..."
    test_quick_stake
    
    if [ $? -eq 0 ]; then
        echo "Test completed successfully!"
    else
        echo "Test failed!"
    fi
    
    # Cleanup
    pkill -f "ganache"
    rm -rf "$TEST_STORE"
    rm ganache.log
}

# Run main function
main
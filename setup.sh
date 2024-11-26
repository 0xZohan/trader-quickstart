#!/bin/bash

# 1. Install system dependencies
sudo apt-get update
sudo apt-get install -y \
    python3 \
    python3-pip \
    nodejs \
    npm \
    git \
    curl

# 2. Install Python packages
curl -sSL https://install.python-poetry.org | python3 -
export PATH="/root/.local/bin:$PATH"  # Add Poetry to path

# 3. Install Node.js packages
npm install -g ganache-cli web3

# 4. Get the subgraph API key from existing .trader_runner
if [ -f ".trader_runner/.env" ]; then
    SUBGRAPH_API_KEY=$(grep SUBGRAPH_API_KEY .trader_runner/.env | cut -d '=' -f2)
    echo "Found existing SUBGRAPH_API_KEY: $SUBGRAPH_API_KEY"
else
    echo "Error: No .trader_runner/.env found with SUBGRAPH_API_KEY"
    exit 1
fi

# 5. Clone and set up trader repository (required by run_service.sh)
git clone https://github.com/valory-xyz/trader.git
cd trader
poetry install
poetry run autonomy packages sync
poetry run autonomy init --reset --author valory --remote --ipfs --ipfs-node "/dns/registry.autonolas.tech/tcp/443/https"
poetry add tqdm cryptography==42.0.8
cd ..

# 6. Set non-interactive mode
export ATTENDED=false
export GNOSIS_CHAIN_RPC="https://rpc.gnosischain.com"
export SUBGRAPH_API_KEY="$SUBGRAPH_API_KEY"

# 7. Run the service to ensure everything is set up
./run_service.sh --attended=false

# 8. Stop all docker containers
docker stop $(docker ps -aq)
docker rm $(docker ps -aq)

# 9. Run test environment
./test_staking.sh

echo "Setup and test complete."
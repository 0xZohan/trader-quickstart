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

# 4. Clone the repository and set up
git clone https://github.com/your-fork/trader.git  # Replace with your fork
cd trader

# 5. Install Python dependencies
poetry install
poetry run autonomy packages sync
poetry run autonomy init --reset --author valory --remote --ipfs --ipfs-node "/dns/registry.autonolas.tech/tcp/443/https"
poetry add tqdm cryptography==42.0.8

# 6. Set non-interactive mode
export ATTENDED=false
export GNOSIS_CHAIN_RPC="https://rpc.gnosischain.com"
export SUBGRAPH_API_KEY="YOUR_SUBGRAPH_API_KEY"  # Replace this

# 7. Run the service to set up .trader_runner
./run_service.sh --attended=false

# 8. Stop all docker containers
docker stop $(docker ps -aq)
docker rm $(docker ps -aq)

# 9. Run test environment
./test_staking.sh

echo "Setup and test complete."
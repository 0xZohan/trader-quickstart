#!/bin/bash

# 1. Install dependencies for Python installation
sudo apt-get update
sudo apt-get install -y \
    wget \
    build-essential \
    libssl-dev \
    zlib1g-dev \
    libbz2-dev \
    libreadline-dev \
    libsqlite3-dev \
    curl \
    libncursesw5-dev \
    xz-utils \
    tk-dev \
    libxml2-dev \
    libxmlsec1-dev \
    libffi-dev \
    liblzma-dev \
    git \
    nodejs \
    npm

# 2. Install Python 3.10
if ! command -v python3.10 &> /dev/null; then
    echo "Installing Python 3.10..."
    wget https://www.python.org/ftp/python/3.10.12/Python-3.10.12.tgz
    tar xzf Python-3.10.12.tgz
    cd Python-3.10.12
    ./configure --enable-optimizations
    make -j $(nproc)
    sudo make altinstall
    cd ..
    rm -rf Python-3.10.12 Python-3.10.12.tgz
    
    # Create python3 symlink to python3.10
    sudo update-alternatives --install /usr/bin/python3 python3 /usr/local/bin/python3.10 1
    sudo update-alternatives --set python3 /usr/local/bin/python3.10
    
    # Install pip for Python 3.10
    curl -sS https://bootstrap.pypa.io/get-pip.py | python3.10
fi

# Verify Python version
python3 --version
if ! python3 --version | grep -q "3.10"; then
    echo "Error: Python 3.10 is required but not installed correctly"
    exit 1
fi

# 3. Install Node.js packages
npm install -g ganache-cli web3

# 4. Install Poetry for Python 3.10
curl -sSL https://install.python-poetry.org | python3.10 -
export PATH="/root/.local/bin:$PATH"  # Add Poetry to path

# Verify Poetry is using Python 3.10
poetry --version
poetry config virtualenvs.create true
poetry config virtualenvs.in-project true
poetry env use python3.10

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

# 7. Run the service to create .trader_runner and set up environment
./run_service.sh --attended=false

# 8. Verify subgraph API key exists after run_service.sh
if [ ! -f ".trader_runner/.env" ]; then
    echo "Error: .trader_runner/.env not found after running service"
    exit 1
fi

SUBGRAPH_API_KEY=$(grep SUBGRAPH_API_KEY .trader_runner/.env | cut -d '=' -f2)
if [ -z "$SUBGRAPH_API_KEY" ]; then
    echo "Error: SUBGRAPH_API_KEY not found in .trader_runner/.env after running service"
    exit 1
fi

echo "Found SUBGRAPH_API_KEY after service setup: $SUBGRAPH_API_KEY"
export SUBGRAPH_API_KEY="$SUBGRAPH_API_KEY"

# 9. Stop all docker containers
docker stop $(docker ps -aq)
docker rm $(docker ps -aq)

# 10. Run test environment
./test_staking.sh

echo "Setup and test complete."
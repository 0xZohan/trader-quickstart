#!/bin/bash

# Initialize repo and version variables
store=".trader_runner"
path_to_store="$PWD/$store/"
env_file_path="$store/.env"
rpc_path="$store/rpc.txt"
operator_keys_file="$store/operator_keys.json"
operator_pkey_path="$store/operator_pkey.txt"
keys_json="keys.json"
keys_json_path="$store/$keys_json"
agent_pkey_path="$store/agent_pkey.txt"
agent_address_path="$store/agent_address.txt"
service_id_path="$store/service_id.txt"
use_password=false
password_argument=""

# Function to export dotenv variables
export_dotenv() {
    local dotenv_path="$1"
    unamestr=$(uname)
    # Mac
    if [ "$unamestr" = 'FreeBSD' ] || [ "$unamestr" = 'Darwin' ]; then
        export $(grep -v '^#' $dotenv_path | xargs -0)
    # Linux, WSL, MinGW
    else
        export $(grep -v '^#' $dotenv_path | xargs -d '\n')
    fi
}


# Get the private key from a keys.json file
get_private_key() {
    local keys_json_path="$1"

    if [ ! -f "$keys_json_path" ]; then
        echo "Error: $keys_json_path does not exist."
        return 1
    fi

    private_key=$($PYTHON_CMD -c 'import json; print(json.load(open("'"$keys_json_path"'"))[0]["private_key"])')
    private_key="${private_key#0x}"

    echo -n "$private_key"
}

# Set up Python command
if command -v python3 >/dev/null 2>&1; then
    PYTHON_CMD="python3"
elif command -v python >/dev/null 2>&1; then
    PYTHON_CMD="python"
else
    echo >&2 "Python is not installed!"
    exit 1
fi

echo ""
echo "-----------------"
echo " Quick Staker"
echo "-----------------"
echo ""

# Check if .trader_runner exists
if [ ! -d $store ]; then
    echo "Error: $store directory not found. Please run run_service.sh first to set up the environment."
    exit 1
fi

# Load environment variables
if [ -f "$env_file_path" ]; then
    source "$env_file_path"
    export_dotenv "$env_file_path"
else
    echo "Error: Environment file not found at $env_file_path"
    exit 1
fi

# Load RPC
if [ -f "$rpc_path" ]; then
    rpc=$(cat $rpc_path)
else
    echo "Error: RPC file not found at $rpc_path"
    exit 1
fi

# Load service ID
if [ -f "$service_id_path" ]; then
    service_id=$(cat $service_id_path)
else
    echo "Error: Service ID file not found at $service_id_path"
    exit 1
fi

# Export necessary environment variables
export CUSTOM_CHAIN_RPC="$rpc"
export ON_CHAIN_SERVICE_ID="$service_id"

echo "Attempting to stake service $service_id..."
echo "Using RPC: $rpc"
echo ""

cd trader

# Attempt staking
poetry run python "../scripts/staking.py" \
    "$service_id" \
    "$CUSTOM_SERVICE_REGISTRY_ADDRESS" \
    "$CUSTOM_STAKING_ADDRESS" \
    "../$operator_pkey_path" \
    "$rpc" \
    "false"

result=$?

if [ $result -eq 0 ]; then
    echo "Staking operation completed for service $service_id"
    exit 0
else
    echo "Staking operation failed for service $service_id"
    exit 1
fi
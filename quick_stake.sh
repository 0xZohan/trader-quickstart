#!/bin/bash

# Initialize variables
store=".trader_runner"
env_file_path="$store/.env"
rpc_path="$store/rpc.txt"
operator_pkey_path="$store/operator_pkey.txt"
service_id_path="$store/service_id.txt"

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
if [ ! -d "$store" ]; then
    echo "Error: $store directory not found. Please run run_service.sh first to set up the environment."
    exit 1
fi

# Load environment variables
if [ -f "$env_file_path" ]; then
    set -o allexport
    source "$env_file_path"
    set +o allexport
else
    echo "Error: Environment file not found at $env_file_path"
    exit 1
fi

# Load RPC
if [ -f "$rpc_path" ]; then
    rpc=$(cat "$rpc_path")
else
    echo "Error: RPC file not found at $rpc_path"
    exit 1
fi

# Load service ID
if [ -f "$service_id_path" ]; then
    service_id=$(cat "$service_id_path")
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

# Optional debug statements (you can remove these if not needed)
echo "CUSTOM_SERVICE_REGISTRY_ADDRESS is $CUSTOM_SERVICE_REGISTRY_ADDRESS"
echo "CUSTOM_STAKING_ADDRESS is $CUSTOM_STAKING_ADDRESS"
echo ""

cd trader

# Attempt staking by passing an empty string as the unstake argument
poetry run python "../scripts/staking.py" \
    "$service_id" \
    "$CUSTOM_SERVICE_REGISTRY_ADDRESS" \
    "$CUSTOM_STAKING_ADDRESS" \
    "../$operator_pkey_path" \
    "$rpc" \
    ""

result=$?

if [ $result -eq 0 ]; then
    echo "Staking operation completed for service $service_id"
    exit 0
else
    echo "Staking operation failed for service $service_id"
    exit 1
fi

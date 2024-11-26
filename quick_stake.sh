#!/bin/bash

store=".trader_runner"
env_file_path="$store/.env"
rpc_path="$store/rpc.txt"
operator_pkey_path="$store/operator_pkey.txt"
service_id_path="$store/service_id.txt"

# Set up Python command
if command -v python3 >/dev/null 2>&1; then
    PYTHON_CMD="python3"
else
    PYTHON_CMD="python"
fi

# Verify store exists and load files
[ ! -d "$store" ] && echo "Error: $store directory not found. Run run_service.sh first." && exit 1
[ -f "$env_file_path" ] && source "$env_file_path" || { echo "Error: Environment file not found"; exit 1; }
[ -f "$rpc_path" ] && rpc=$(cat "$rpc_path") || { echo "Error: RPC file not found"; exit 1; }
[ -f "$service_id_path" ] && service_id=$(cat "$service_id_path") || { echo "Error: Service ID file not found"; exit 1; }

# Export necessary environment variables
export CUSTOM_CHAIN_RPC="$rpc"
export CUSTOM_CHAIN_ID=100
export ON_CHAIN_SERVICE_ID="$service_id"
export RPC_RETRIES=40
export RPC_TIMEOUT_SECONDS=120

# Check service state
service_state=$(cd trader && poetry run autonomy service --use-custom-chain info "$service_id" | \
    awk '/Service State/ {sub(/\|[ \t]*Service State[ \t]*\|[ \t]*/, ""); sub(/[ \t]*\|[ \t]*/, ""); print}')

[ "$service_state" != "DEPLOYED" ] && echo "Service $service_id not in DEPLOYED state. Current state: $service_state" && exit 1

# Attempt staking
cd trader && poetry run python "../scripts/staking.py" \
    "$service_id" \
    "$CUSTOM_SERVICE_REGISTRY_ADDRESS" \
    "$CUSTOM_STAKING_ADDRESS" \
    "../$operator_pkey_path" \
    "$rpc" \
    ""

[ $? -eq 0 ] && echo "Staking successful for service $service_id" || { echo "Staking failed for service $service_id"; exit 1; }
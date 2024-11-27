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
else
    PYTHON_CMD="python"
fi

# Load environment and files
[ ! -d "$store" ] && echo "Error: $store directory not found. Run run_service.sh first." && exit 1
[ -f "$env_file_path" ] && source "$env_file_path" || { echo "Error: Environment file not found"; exit 1; }
[ -f "$rpc_path" ] && rpc=$(cat "$rpc_path") || { echo "Error: RPC file not found"; exit 1; }
[ -f "$service_id_path" ] && service_id=$(cat "$service_id_path") || { echo "Error: Service ID file not found"; exit 1; }

# Export necessary environment variables
export CUSTOM_CHAIN_RPC="$rpc"
export CUSTOM_CHAIN_ID=100
export ON_CHAIN_SERVICE_ID="$service_id"
export ATTENDED=false
export RPC_RETRIES=40
export RPC_TIMEOUT_SECONDS=120

# Required contract addresses
export CUSTOM_SERVICE_MANAGER_ADDRESS="0x04b0007b2aFb398015B76e5f22993a1fddF83644"
export CUSTOM_GNOSIS_SAFE_PROXY_FACTORY_ADDRESS="0x3C1fF68f5aa342D296d4DEe4Bb1cACCA912D95fE"
export CUSTOM_GNOSIS_SAFE_SAME_ADDRESS_MULTISIG_ADDRESS="0x6e7f594f680f7aBad18b7a63de50F0FeE47dfD06"
export CUSTOM_MULTISEND_ADDRESS="0x40A2aCCbd92BCA938b02010E17A5b8929b49130D"
export WXDAI_ADDRESS="0xe91D153E0b41518A2Ce8Dd3D7944Fa863463a97d"
export OPEN_AUTONOMY_SUBGRAPH_URL="https://subgraph.autonolas.tech/subgraphs/name/autonolas-staging"

# Required for contract queries
export CUSTOM_SERVICE_REGISTRY_ADDRESS="${CUSTOM_SERVICE_REGISTRY_ADDRESS:-0x9338b5153AE39BB89f50468E608eD9d764B755fD}"

cd trader

echo "Checking service state..."

# Verify service is in DEPLOYED state before attempting to stake
service_state=$(poetry run autonomy service --use-custom-chain info "$service_id" | \
    awk '/Service State/ {sub(/\|[ \t]*Service State[ \t]*\|[ \t]*/, ""); sub(/[ \t]*\|[ \t]*/, ""); print}')

[ "$service_state" != "DEPLOYED" ] && echo "Service $service_id not in DEPLOYED state (Current: $service_state)" && exit 1

echo "Attempting to stake service $service_id..."
echo "Using RPC: $rpc"

# Attempt staking
poetry run python "../scripts/staking.py" \
    "$service_id" \
    "$CUSTOM_SERVICE_REGISTRY_ADDRESS" \
    "$CUSTOM_STAKING_ADDRESS" \
    "../$operator_pkey_path" \
    "$rpc" \
    ""

[ $? -eq 0 ] && echo "Staking successful for service $service_id" || { echo "Staking failed for service $service_id"; exit 1; }
#!/bin/bash

# Define constants 
AMOUNT=100000

BASE_SEPOLIA_CHAIN_SELECTOR="10344971235874465080"
BASE_SEPOLIA_REBASE_TOKEN_ADDRESS="0xBf95126CC7000c3b195dd99fa304Bd7849515F2D"
BASE_SEPOLIA_POOL_ADDRESS="0x8d90AA3930520665d5E5da93F3F3eF231D589FB4"

SEPOLIA_CHAIN_SELECTOR="16015286601757825753"
SEPOLIA_REBASE_TOKEN_ADDRESS="0xEeab69045dA330C5813A9b4417125B9f6D291c5a"
SEPOLIA_POOL_ADDRESS="0xd4652005c4BdA2D2514670F8EBd5262Fb400919c"
VAULT_ADDRESS="0x4c5EDE68e450A71c9F0DDB61953b7654BCF10B77"

SEPOLIA_ROUTER="0x0BF3dE8c5D3e8A2B34D2BEeB17ABfCeBaf363A59"
SEPOLIA_LINK_ADDRESS="0x779877A7B0D9E8603169DdbD7836e478b4624789"


source .env

#1. Base Sepolia

echo "Running the script to deploy the contracts on Base Sepolia..."
output=$(forge script ./script/Deployer.s.sol:TokenAndPoolDeployer --rpc-url ${BASE_SEPOLIA_RPC_URL} --account default --broadcast)
echo "Contracts deployed and permission set on Sepolia"

# Extract the addresses from the output
BASE_SEPOLIA_REBASE_TOKEN_ADDRESS=$(echo "$output" | grep 'token: contract RebaseToken' | awk '{print $4}')
BASE_SEPOLIA_POOL_ADDRESS=$(echo "$output" | grep 'pool: contract RebaseTokenPool' | awk '{print $4}')

echo "Base Sepolia rebase token address: $BASE_SEPOLIA_REBASE_TOKEN_ADDRESS"
echo "Base Sepolia pool address: $BASE_SEPOLIA_POOL_ADDRESS"


# 2. Sepolia

echo "Running the script to deploy the contracts on Sepolia..."
output=$(forge script ./script/Deployer.s.sol:TokenAndPoolDeployer --rpc-url ${SEPOLIA_RPC_URL} --account default --broadcast)
echo "Contracts deployed and permission set on Sepolia"

# Extract the addresses from the output
SEPOLIA_REBASE_TOKEN_ADDRESS=$(echo "$output" | grep 'token: contract RebaseToken' | awk '{print $4}')
SEPOLIA_POOL_ADDRESS=$(echo "$output" | grep 'pool: contract RebaseTokenPool' | awk '{print $4}')

echo "Sepolia rebase token address: $SEPOLIA_REBASE_TOKEN_ADDRESS"
echo "Sepolia pool address: $SEPOLIA_POOL_ADDRESS"

# Deploy the vault 
echo "Deploying the vault on Sepolia..."
VAULT_ADDRESS=$(forge script ./script/Deployer.s.sol:VaultDeployer --rpc-url ${SEPOLIA_RPC_URL} --account default --broadcast --sig "run(address)" ${SEPOLIA_REBASE_TOKEN_ADDRESS} | grep 'vault: contract Vault' | awk '{print $NF}')
echo "Vault address: $VAULT_ADDRESS"

Configure the pool on Sepolia
echo "Configuring the pool on Sepolia..."
forge script ./script/ConfigurePool.s.sol:ConfigurePoolScript --rpc-url ${SEPOLIA_RPC_URL} --account default --broadcast --sig "run(address,uint64,address,address,bool,uint128,uint128,bool,uint128,uint128)" ${SEPOLIA_POOL_ADDRESS} ${BASE_SEPOLIA_CHAIN_SELECTOR} ${BASE_SEPOLIA_POOL_ADDRESS} ${BASE_SEPOLIA_REBASE_TOKEN_ADDRESS} false 0 0 false 0 0

# Deposit funds to the vault
echo "Depositing funds to the vault on Sepolia..."
cast send ${VAULT_ADDRESS} --value ${AMOUNT} --rpc-url ${SEPOLIA_RPC_URL} --account default "deposit()"

# Wait a beat for some interest to accrue

# Configure the pool on Base Sepolia
echo "Configuring the pool on Base Sepolia..."
forge script ./script/ConfigurePool.s.sol:ConfigurePoolScript --rpc-url ${BASE_SEPOLIA_RPC_URL} --account default --broadcast --sig "run(address,uint64,address,address,bool,uint128,uint128,bool,uint128,uint128)" ${BASE_SEPOLIA_POOL_ADDRESS} ${SEPOLIA_CHAIN_SELECTOR} ${SEPOLIA_POOL_ADDRESS} ${SEPOLIA_REBASE_TOKEN_ADDRESS} false 0 0 false 0 0

# Bridge the funds using the script to Base Sepolia 
echo "Bridging the funds using the script to Base Sepolia..."
SEPOLIA_BALANCE_BEFORE=$(cast balance $(cast wallet address --account default) --erc20 ${SEPOLIA_REBASE_TOKEN_ADDRESS} --rpc-url ${SEPOLIA_RPC_URL})
echo "Sepolia balance before bridging: $SEPOLIA_BALANCE_BEFORE"
forge script ./script/BridgeTokens.s.sol:BridgeTokensScript --rpc-url ${SEPOLIA_RPC_URL} --account default --broadcast --sig "run(address,uint64,address,uint256,address,address)" $(cast wallet address --account default) ${BASE_SEPOLIA_CHAIN_SELECTOR} ${SEPOLIA_REBASE_TOKEN_ADDRESS} ${AMOUNT} ${SEPOLIA_LINK_ADDRESS} ${SEPOLIA_ROUTER}
echo "Funds bridged to Base Sepolia"
SEPOLIA_BALANCE_AFTER=$(cast balance $(cast wallet address --account default) --erc20 ${SEPOLIA_REBASE_TOKEN_ADDRESS} --rpc-url ${SEPOLIA_RPC_URL})
echo "Sepolia balance after bridging: $SEPOLIA_BALANCE_AFTER"

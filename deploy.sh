#!/bin/bash

set -e # Exit on error

echo "🐱 Far Meow Deployment Script"
echo "=============================="
echo ""

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Step 1: Clean soldeer artifacts
echo -e "${YELLOW}Step 1: Removing soldeer artifacts...${NC}"
rm -rf dependencies
rm -f soldeer.lock
rm -f .gitmodules
rm -rf lib

echo -e "${GREEN}✓ Cleaned soldeer artifacts${NC}"
echo ""

# Step 2: Clean forge cache
echo -e "${YELLOW}Step 2: Cleaning forge cache...${NC}"
forge clean

echo -e "${GREEN}✓ Forge cache cleaned${NC}"
echo ""

# Step 3: Initialize git if needed
if [ ! -d ".git" ]; then
    echo -e "${YELLOW}Step 3: Initializing git...${NC}"
    git init
else
    echo -e "${YELLOW}Step 3: Git already initialized${NC}"
fi

echo ""

# Step 4: Commit changes
echo -e "${YELLOW}Step 4: Committing changes to git...${NC}"
git add -A
git commit -m "Clean slate for Far Meow deployment" || echo "Nothing to commit"

echo -e "${GREEN}✓ Changes committed${NC}"
echo ""

# Step 5: Install dependencies
echo -e "${YELLOW}Step 5: Installing forge dependencies...${NC}"
forge install foundry-rs/forge-std
forge install OpenZeppelin/openzeppelin-contracts@v4.9.3
forge install OpenZeppelin/openzeppelin-contracts-upgradeable@v4.9.3

echo -e "${GREEN}✓ Dependencies installed${NC}"
echo ""

# Step 6: Verify installation
echo -e "${YELLOW}Step 6: Verifying installation...${NC}"
ls lib/

echo -e "${GREEN}✓ lib/ folder contents listed above${NC}"
echo ""

# Step 7: Set environment variables
echo -e "${YELLOW}Step 7: Setting environment variables...${NC}"
export USDC_ADDRESS=0x036CbD53842c5426634e7929541eC2318f3dCF7e
export GAME_SERVER=0x02fa354994135aaD836d45a083B819e5f51af0Ff
export BASE_SEPOLIA_RPC_URL=https://sepolia.base.org
export BASESCAN_API_KEY=BUN66BQZ9W4WTM4WZKJSK6FVAHE9222CMG

echo -e "${GREEN}✓ Environment variables set${NC}"
echo ""

# Step 8: Deploy
echo -e "${YELLOW}Step 8: Deploying contract to Base Sepolia...${NC}"
echo ""
echo "You will be prompted for your keystore password."
echo ""

forge script script/Deploy.s.sol \
  --rpc-url $BASE_SEPOLIA_RPC_URL \
  --account testnet-deployer \
  --sender 0xd28ff38975c982dbd5338d086cce2ccf71dc3e9e \
  --broadcast \
  --verify \
  --etherscan-api-key $BASESCAN_API_KEY \
  -vvv

echo ""
echo -e "${GREEN}=============================="
echo "✓ Deployment Complete!"
echo "==============================${NC}"
echo ""
echo "Next steps:"
echo "1. Copy the Proxy Address from the output above"
echo "2. Update App.html with: VAULT_CONTRACT: '0xYourProxyAddress'"
echo "3. Deploy your frontend to Vercel/Cloudflare"
echo ""

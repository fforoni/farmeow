#!/bin/bash

# Far Meow Quick Start Script
# Run this to set up the development environment

set -e

echo "🐱 Far Meow Setup Script"
echo "========================"
echo ""

# Check Node.js
if ! command -v node &> /dev/null; then
    echo "❌ Node.js not found. Please install Node.js 18+ first."
    exit 1
fi

echo "✅ Node.js version: $(node --version)"
echo ""

# Install root dependencies
echo "📦 Installing frontend dependencies..."
npm install
echo ""

# Install backend dependencies
echo "📦 Installing backend dependencies..."
cd backend
npm install
cd ..
echo ""

# Create .env files
echo "📝 Creating environment files..."

if [ ! -f .env ]; then
    cat > .env << 'EOF'
# Smart Contract Deployment
PRIVATE_KEY=your_deployer_private_key_here
BASE_RPC_URL=https://mainnet.base.org
BASESCAN_API_KEY=your_basescan_api_key_here
EOF
    echo "✅ Created .env (root)"
else
    echo "⚠️  .env already exists (root)"
fi

if [ ! -f backend/.env ]; then
    cat > backend/.env << 'EOF'
# Backend Configuration
NEYNAR_API_KEY=your_neynar_api_key_here
BASE_RPC_URL=https://mainnet.base.org
VAULT_CONTRACT_ADDRESS=0x_deploy_contract_first
GAME_SERVER_PRIVATE_KEY=0x_your_game_server_key_here
PORT=3000
MIN_ACCOUNT_AGE_DAYS=7
MIN_FOLLOWERS=5
EOF
    echo "✅ Created backend/.env"
else
    echo "⚠️  backend/.env already exists"
fi

echo ""
echo "🎯 Setup Complete!"
echo ""
echo "Next steps:"
echo "==========="
echo ""
echo "1. Get a Neynar API key from https://neynar.com"
echo "   Add it to backend/.env"
echo ""
echo "2. Deploy the smart contract:"
echo "   - Add your private key to .env"
echo "   - Run: npm run deploy:contract"
echo ""
echo "3. Update App.html with your contract address"
echo "   - Find CONFIG object around line 175"
echo "   - Update VAULT_CONTRACT address"
echo ""
echo "4. Start the backend:"
echo "   - cd backend && npm start"
echo ""
echo "5. Start the frontend:"
echo "   - npm run dev"
echo ""
echo "6. Open http://localhost:3000 in your browser"
echo ""
echo "📖 See DEPLOYMENT.md for full deployment guide"
echo "🔒 See SECURITY.md for security checklist"
echo "📋 See PROJECT_SUMMARY.md for complete overview"
echo ""
echo "🚀 Ready to build Far Meow!"

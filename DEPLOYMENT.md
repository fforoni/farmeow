# Far Meow Deployment Guide 🚀

Complete step-by-step guide to deploy Far Meow to production.

## Prerequisites

- [x] Node.js 18+ installed
- [x] Neynar API key from https://neynar.com
- [x] Base network wallet with ETH for gas
- [x] USDC on Base for testing
- [x] Domain name (e.g., far-meow.app)
- [x] Hosting provider (Vercel, Netlify, or similar)

## Step 1: Clone and Setup

```bash
git clone https://github.com/yourusername/far-meow.git
cd far-meow
npm install
cd backend
npm install
cd ..
```

## Step 2: Deploy Smart Contract

### 2.1 Configure Environment

Create `.env` in root:

```bash
PRIVATE_KEY=your_deployer_private_key
BASE_RPC_URL=https://mainnet.base.org
BASESCAN_API_KEY=your_basescan_api_key
```

### 2.2 Deploy to Base

```bash
npm run deploy:contract
```

Save the deployed contract address! You'll need it for the next steps.

### 2.3 Verify Contract

Contract should auto-verify, but if needed:

```bash
npx hardhat verify --network base <CONTRACT_ADDRESS> 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913 <YOUR_ADDRESS>
```

## Step 3: Configure Frontend

Update `App.html` line ~175:

```javascript
const CONFIG = {
    NEYNAR_API_KEY: 'YOUR_NEYNAR_API_KEY', // Get from neynar.com
    VAULT_CONTRACT: '0xYOUR_DEPLOYED_CONTRACT_ADDRESS',
    USDC_ADDRESS: '0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913',
    BASE_CHAIN_ID: 8453,
    API_ENDPOINT: 'https://api.far-meow.app' // Your backend URL
};
```

## Step 4: Deploy Backend

### 4.1 Configure Backend

Create `backend/.env`:

```bash
NEYNAR_API_KEY=your_neynar_api_key
BASE_RPC_URL=https://mainnet.base.org
VAULT_CONTRACT_ADDRESS=0xYOUR_DEPLOYED_CONTRACT
GAME_SERVER_PRIVATE_KEY=0xYOUR_GAME_SERVER_KEY
PORT=3000
MIN_ACCOUNT_AGE_DAYS=7
MIN_FOLLOWERS=5
```

### 4.2 Deploy Backend to Production

**Option A: Deploy to Railway**

1. Go to https://railway.app
2. Click "New Project" → "Deploy from GitHub"
3. Select your repository
4. Set root directory to `/backend`
5. Add environment variables from `.env`
6. Deploy!

**Option B: Deploy to Render**

1. Go to https://render.com
2. New → Web Service
3. Connect GitHub repository
4. Root directory: `backend`
5. Build: `npm install`
6. Start: `npm start`
7. Add environment variables
8. Deploy!

**Option C: Deploy to Your Own Server**

```bash
# On your server
git clone <your-repo>
cd far-meow/backend
npm install
npm install -g pm2

# Start with PM2
pm2 start server.js --name far-meow-backend
pm2 save
pm2 startup
```

## Step 5: Deploy Frontend

### 5.1 Update Farcaster Manifest

Edit `.well-known/farcaster.json`:

```json
{
  "accountAssociation": {
    "header": "<your_base64_header>",
    "payload": "<your_base64_payload>",
    "signature": "<your_signature>"
  },
  "frame": {
    "version": "next",
    "name": "Far Meow",
    "iconUrl": "https://far-meow.app/icon.png",
    "homeUrl": "https://far-meow.app",
    "imageUrl": "https://far-meow.app/splash.png",
    "buttonTitle": "Play Far Meow"
  }
}
```

Generate signature using Neynar CLI or manually.

### 5.2 Deploy Frontend to Vercel

```bash
npm install -g vercel
vercel --prod
```

Or use GitHub integration:

1. Push to GitHub
2. Import project in Vercel
3. Configure build settings (no build needed for static HTML)
4. Deploy!

### 5.3 Deploy Frontend to Netlify

```bash
npm install -g netlify-cli
netlify deploy --prod --dir=.
```

## Step 6: Configure DNS

Add these DNS records:

```
A     @        <your-server-ip>
CNAME api      <your-backend-url>
CNAME www      <your-main-url>
```

## Step 7: Testing

### 7.1 Test Contract

```bash
npx hardhat console --network base
```

```javascript
const vault = await ethers.getContractAt("FarMeowVault", "YOUR_CONTRACT_ADDRESS");
await vault.getCurrentRound();
```

### 7.2 Test Backend

```bash
curl https://api.far-meow.app/health
curl https://api.far-meow.app/vault-info
```

### 7.3 Test Frontend

1. Open https://far-meow.app
2. Connect Farcaster wallet
3. Check USDC balance displays
4. Verify countdown timer works

### 7.4 Test Full Flow

1. Pay entry fee (0.25 USDC)
2. Play game
3. Check score submission
4. Verify leaderboard updates
5. Test share functionality

## Step 8: Farcaster Integration

### 8.1 Register Mini App

1. Go to https://warpcast.com/~/developers
2. Create new mini app
3. Upload splash image (1200x630px)
4. Set domain to https://far-meow.app
5. Submit for review

### 8.2 Test in Warpcast

1. Open Warpcast mobile app
2. Search for "Far Meow"
3. Click Play button
4. Test full game flow

## Step 9: Post-Deployment

### 9.1 Monitor Contract

Set up monitoring with:
- Tenderly (https://tenderly.co)
- Defender (https://defender.openzeppelin.com)

### 9.2 Set Up Analytics

Add to `App.html`:

```html
<!-- Google Analytics -->
<script async src="https://www.googletagmanager.com/gtag/js?id=G-XXXXXXXXXX"></script>

<!-- Neynar Analytics (built-in) -->
```

### 9.3 Enable Logging

Backend logs automatically to console. For production:

```javascript
// Add to backend/server.js
const winston = require('winston');
const logger = winston.createLogger({...});
```

## Step 10: Security Checklist

- [ ] Contract verified on BaseScan
- [ ] Game server private key secured
- [ ] Rate limiting enabled on API
- [ ] CORS configured correctly
- [ ] Environment variables not committed
- [ ] Backup RPC endpoints configured
- [ ] Monitoring and alerts set up
- [ ] Emergency pause function tested

## Troubleshooting

### Contract Deployment Fails

```bash
# Check balance
cast balance <your-address> --rpc-url https://mainnet.base.org

# Check gas price
cast gas-price --rpc-url https://mainnet.base.org
```

### Backend Won't Start

```bash
# Check Node version
node --version  # Should be 18+

# Check environment variables
node -e "require('dotenv').config(); console.log(process.env)"

# Test RPC connection
curl -X POST https://mainnet.base.org \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}'
```

### Frontend Issues

1. Check browser console for errors
2. Verify Frame SDK loads correctly
3. Test wallet connection manually
4. Check CORS headers from backend

### Payment Fails

1. Verify USDC balance >= 0.25
2. Check USDC contract address is correct
3. Confirm vault contract deployed correctly
4. Test approval transaction separately

## Maintenance

### Update Game Parameters

```javascript
// Update in smart contract (requires redeploy or upgrade)
// Or update in backend for dynamic values
```

### Withdraw Platform Fees

```bash
npx hardhat console --network base
const vault = await ethers.getContractAt("FarMeowVault", "CONTRACT_ADDRESS");
await vault.withdrawPlatformFees("YOUR_ADDRESS");
```

### Emergency Pause

```bash
const vault = await ethers.getContractAt("FarMeowVault", "CONTRACT_ADDRESS");
await vault.pause();
```

## Support

- Documentation: https://docs.far-meow.app
- Discord: https://discord.gg/farmeow
- Farcaster: @farmeow
- Email: support@far-meow.app

## Next Steps

1. Create marketing materials
2. Announce on Farcaster
3. Partner with Farcaster communities
4. Add seasonal events
5. Implement leaderboard rewards
6. Create referral system

---

**Congratulations! 🎉 Your Far Meow game is now live!**

Share it on Farcaster and start earning!

// Far Meow Backend Server - Node.js + Express
// Handles score verification, leaderboard, and smart contract interactions

require('dotenv').config();
const express = require('express');
const cors = require('cors');
const { ethers } = require('ethers');

const app = express();
app.use(cors());
app.use(express.json());

// Connect to vault contract
const provider = new ethers.providers.JsonRpcProvider(process.env.BASE_RPC_URL);
const wallet = new ethers.Wallet(process.env.GAME_SERVER_PRIVATE_KEY, provider);
const vaultAbi = [
    'function verifyPlayer(address,uint256) external',
    'function submitScore(address,uint256,bytes32) external',
    'function finalizeRoundWithTopPlayers(address[],uint256[]) external',
    'function batchDistributePrizes(uint256) external'
];
const vault = new ethers.Contract(process.env.VAULT_ADDRESS, vaultAbi, wallet);

// Mock database (use PostgreSQL in production)
const scores = new Map();

// ============================================
// API ENDPOINTS
// ============================================

// Health check
app.get('/health', (req, res) => {
    res.json({ status: 'ok', timestamp: Date.now() });
});

// Verify player and register with smart contract
app.post('/verify-player', async (req, res) => {
    const { fid, username, address } = req.body;
    
    try {
        const tx = await vault.verifyPlayer(address, fid);
        await tx.wait();
        res.json({ success: true });
    } catch (e) {
        res.status(500).json({ error: e.message });
    }
});

// Submit score (with commit-reveal pattern)
app.post('/submit-score', async (req, res) => {
    const { address, score, secret, roundId } = req.body;
    
    try {
        const tx = await vault.submitScore(address, score, secret);
        await tx.wait();
        
        scores.set(address, { score, roundId });
        
        const allScores = Array.from(scores.values()).sort((a, b) => b.score - a.score);
        const rank = allScores.findIndex(s => s.score === score) + 1;
        
        res.json({ success: true, rank });
    } catch (e) {
        res.status(500).json({ error: e.message });
    }
});

// Get current leaderboard
app.get('/leaderboard', (req, res) => {
    const sorted = Array.from(scores.entries())
        .sort((a, b) => b[1].score - a[1].score)
        .slice(0, 100)
        .map(([addr, data], i) => ({
            address: addr,
            score: data.score,
            estimatedPayout: 0,
            username: `Player${i + 1}`
        }));
    res.json({ players: sorted });
});

// ============================================
// SCHEDULED TASKS
// ============================================

// Hourly finalization cron
setInterval(async () => {
    const sorted = Array.from(scores.entries())
        .sort((a, b) => b[1].score - a[1].score)
        .slice(0, 20);
    const addresses = sorted.map(s => s[0]);
    const scoreVals = sorted.map(s => s[1].score);
    
    try {
        const finalizeTx = await vault.finalizeRoundWithTopPlayers(addresses, scoreVals);
        await finalizeTx.wait();
        
        const distributeTx = await vault.batchDistributePrizes(currentRoundId);
        await distributeTx.wait();
        
        console.log('✅ Round finalized and prizes distributed');
        scores.clear();
    } catch (e) {
        console.error('❌ Finalization failed:', e);
    }
}, 3600000); // 1 hour

// ============================================
// START SERVER
// ============================================

app.listen(3000, () => console.log('Backend running on :3000'));

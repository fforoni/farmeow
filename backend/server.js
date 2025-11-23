// Far Meow Backend Server - Node.js + Express
// Handles score verification, leaderboard, and smart contract interactions

require('dotenv').config();
const express = require('express');
const cors = require('cors');
const { ethers } = require('ethers');
const rateLimit = require('express-rate-limit');

const app = express();
const PORT = process.env.PORT || 3000;

// Middleware
app.use(cors());
app.use(express.json());

// Rate limiting to prevent spam
const limiter = rateLimit({
    windowMs: 15 * 60 * 1000, // 15 minutes
    max: 100 // limit each IP to 100 requests per windowMs
});
app.use(limiter);

// Configuration
const CONFIG = {
    NEYNAR_API_KEY: process.env.NEYNAR_API_KEY,
    BASE_RPC_URL: process.env.BASE_RPC_URL || 'https://mainnet.base.org',
    VAULT_CONTRACT: process.env.VAULT_CONTRACT_ADDRESS,
    PRIVATE_KEY: process.env.GAME_SERVER_PRIVATE_KEY,
    MIN_ACCOUNT_AGE_DAYS: 7, // Anti-bot: account must be 7 days old
    MIN_FOLLOWERS: 5 // Anti-bot: minimum 5 followers
};

// Initialize ethers
const provider = new ethers.providers.JsonRpcProvider(CONFIG.BASE_RPC_URL);
const wallet = new ethers.Wallet(CONFIG.PRIVATE_KEY, provider);

const VAULT_ABI = [
    "function submitScore(address player, uint256 score, bytes32 secret) external",
    "function getCurrentRound() view returns (uint256, uint256, uint256, uint256, bool)",
    "function verifyPlayer(address player, uint256 fid) external",
    "function commitScore(bytes32 commitHash) external",
    "function finalizeRoundWithTopPlayers(address[] players, uint256[] scores) external"
];

const vaultContract = new ethers.Contract(CONFIG.VAULT_CONTRACT, VAULT_ABI, wallet);

// In-memory leaderboard cache (use Redis in production)
let currentLeaderboard = [];
let lastLeaderboardUpdate = 0;

// ============================================
// NEYNAR API HELPERS
// ============================================

async function getNeynarUserData(fid) {
    try {
        const response = await fetch(`https://api.neynar.com/v2/farcaster/user/bulk?fids=${fid}`, {
            headers: {
                'api_key': CONFIG.NEYNAR_API_KEY
            }
        });
        
        const data = await response.json();
        return data.users[0];
    } catch (error) {
        console.error('Neynar API error:', error);
        throw error;
    }
}

async function verifyFarcasterAccount(fid) {
    const userData = await getNeynarUserData(fid);
    
    if (!userData) {
        throw new Error('User not found');
    }
    
    // Check account age
    const accountAge = Date.now() - new Date(userData.registered_at).getTime();
    const daysOld = accountAge / (1000 * 60 * 60 * 24);
    
    if (daysOld < CONFIG.MIN_ACCOUNT_AGE_DAYS) {
        throw new Error(`Account must be at least ${CONFIG.MIN_ACCOUNT_AGE_DAYS} days old`);
    }
    
    // Check follower count
    if (userData.follower_count < CONFIG.MIN_FOLLOWERS) {
        throw new Error(`Account must have at least ${CONFIG.MIN_FOLLOWERS} followers`);
    }
    
    return userData;
}

// ============================================
// API ENDPOINTS
// ============================================

// Health check
app.get('/health', (req, res) => {
    res.json({ status: 'ok', timestamp: Date.now() });
});

// Verify player and register with smart contract
app.post('/verify-player', async (req, res) => {
    try {
        const { fid, username, address } = req.body;
        
        if (!fid || !address) {
            return res.status(400).json({ error: 'Missing required fields' });
        }
        
        // Verify Farcaster account with Neynar
        const userData = await verifyFarcasterAccount(fid);
        
        // Register player in smart contract
        const tx = await vaultContract.verifyPlayer(address, fid);
        await tx.wait();
        
        console.log(`✅ Player verified: ${username} (FID: ${fid})`);
        
        res.json({
            success: true,
            fid,
            username,
            verified: true,
            followerCount: userData.follower_count
        });
        
    } catch (error) {
        console.error('Verification error:', error);
        res.status(400).json({ error: error.message });
    }
});

// Submit score (with commit-reveal pattern)
app.post('/submit-score', async (req, res) => {
    try {
        const { fid, address, score, secret, commitment, roundId } = req.body;
        
        if (!fid || !address || score === undefined || !secret || !commitment) {
            return res.status(400).json({ error: 'Missing required fields' });
        }
        
        // Verify score is reasonable (anti-cheat)
        if (score > 100000) {
            return res.status(400).json({ error: 'Invalid score' });
        }
        
        // Commit score hash to contract first
        const commitTx = await vaultContract.commitScore(commitment);
        await commitTx.wait();
        
        // Wait a block to prevent front-running
        await new Promise(resolve => setTimeout(resolve, 2000));
        
        // Submit actual score
        const tx = await vaultContract.submitScore(address, score, secret);
        await tx.wait();
        
        // Update leaderboard
        updateLeaderboard(address, score, fid);
        
        const rank = getPlayerRank(address);
        
        console.log(`✅ Score submitted: ${score} (Rank: ${rank})`);
        
        res.json({
            success: true,
            score,
            estimatedRank: rank,
            roundId
        });
        
    } catch (error) {
        console.error('Score submission error:', error);
        res.status(500).json({ error: 'Failed to submit score' });
    }
});

// Get live rank during gameplay
app.post('/live-rank', async (req, res) => {
    try {
        const { fid, score } = req.body;
        
        if (!fid || score === undefined) {
            return res.status(400).json({ error: 'Missing required fields' });
        }
        
        // Calculate rank based on current leaderboard
        const rank = calculateRankForScore(score);
        
        res.json({ rank });
        
    } catch (error) {
        console.error('Live rank error:', error);
        res.status(500).json({ error: 'Failed to get rank' });
    }
});

// Get current leaderboard
app.get('/leaderboard', async (req, res) => {
    try {
        // Update leaderboard if stale (older than 10 seconds)
        if (Date.now() - lastLeaderboardUpdate > 10000) {
            await refreshLeaderboard();
        }
        
        res.json({
            leaderboard: currentLeaderboard.slice(0, 20),
            timestamp: lastLeaderboardUpdate
        });
        
    } catch (error) {
        console.error('Leaderboard error:', error);
        res.status(500).json({ error: 'Failed to get leaderboard' });
    }
});

// Get vault info
app.get('/vault-info', async (req, res) => {
    try {
        const roundData = await vaultContract.getCurrentRound();
        
        res.json({
            roundId: roundData[0].toString(),
            vaultAmount: ethers.utils.formatUnits(roundData[1], 6),
            totalPlayers: roundData[2].toString(),
            timeRemaining: roundData[3].toNumber(),
            finalized: roundData[4]
        });
        
    } catch (error) {
        console.error('Vault info error:', error);
        res.status(500).json({ error: 'Failed to get vault info' });
    }
});

// ============================================
// LEADERBOARD MANAGEMENT
// ============================================

function updateLeaderboard(address, score, fid) {
    const existing = currentLeaderboard.find(p => p.address === address);
    
    if (existing) {
        if (score > existing.score) {
            existing.score = score;
        }
    } else {
        currentLeaderboard.push({ address, score, fid });
    }
    
    // Sort by score descending
    currentLeaderboard.sort((a, b) => b.score - a.score);
    
    lastLeaderboardUpdate = Date.now();
}

function getPlayerRank(address) {
    const index = currentLeaderboard.findIndex(p => p.address === address);
    return index === -1 ? currentLeaderboard.length + 1 : index + 1;
}

function calculateRankForScore(score) {
    let rank = 1;
    for (const entry of currentLeaderboard) {
        if (entry.score >= score) {
            rank++;
        } else {
            break;
        }
    }
    return rank;
}

async function refreshLeaderboard() {
    // In production, fetch from database or smart contract
    lastLeaderboardUpdate = Date.now();
}

// ============================================
// SCHEDULED TASKS
// ============================================

// Finalize round every hour
setInterval(async () => {
    try {
        const roundData = await vaultContract.getCurrentRound();
        const timeRemaining = roundData[3].toNumber();
        
        if (timeRemaining === 0 && !roundData[4]) {
            console.log('⏰ Finalizing round...');
            
            // Prepare top 20 players
            const topPlayers = currentLeaderboard.slice(0, 20);
            const addresses = topPlayers.map(p => p.address);
            const scores = topPlayers.map(p => p.score);
            
            // Call smart contract to finalize
            const tx = await vaultContract.finalizeRoundWithTopPlayers(addresses, scores);
            await tx.wait();
            
            console.log('✅ Round finalized with top 20 players');
            
            // Reset leaderboard for new round
            currentLeaderboard = [];
        }
    } catch (error) {
        console.error('Round finalization error:', error);
    }
}, 60000); // Check every minute

// Cron job to finalize rounds (run hourly)
setInterval(async () => {
    // Get top 20 players
    const sorted = Array.from(scores.entries())
        .sort((a, b) => b[1].score - a[1].score)
        .slice(0, 20);
    const addresses = sorted.map(s => s[0]);
    const scoreVals = sorted.map(s => s[1].score);
    
    try {
        // Step 1: Finalize round
        const finalizeTx = await vault.finalizeRoundWithTopPlayers(addresses, scoreVals);
        await finalizeTx.wait();
        console.log('✅ Round finalized');
        
        // Step 2: Automatically distribute prizes
        const distributeTx = await vault.batchDistributePrizes(currentRoundId);
        await distributeTx.wait();
        console.log('✅ Prizes distributed automatically');
        
        scores.clear(); // Reset for new round
    } catch (e) {
        console.error('❌ Finalize/distribute failed:', e);
    }
}, 3600000); // 1 hour

// ============================================
// START SERVER
// ============================================

app.listen(PORT, () => {
    console.log(`🚀 Far Meow Backend running on port ${PORT}`);
    console.log(`📊 Vault Contract: ${CONFIG.VAULT_CONTRACT}`);
});

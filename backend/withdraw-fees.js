const { ethers } = require('ethers');
require('dotenv').config();

const VAULT_ABI = ['function withdrawPlatformFees(address) external'];

async function withdrawFees() {
    const provider = new ethers.providers.JsonRpcProvider(process.env.BASE_RPC_URL);
    const wallet = new ethers.Wallet(process.env.OWNER_PRIVATE_KEY, provider);
    const vault = new ethers.Contract(process.env.VAULT_ADDRESS, VAULT_ABI, wallet);
    
    // Your personal/company address
    const recipient = process.env.FEE_RECIPIENT_ADDRESS;
    
    try {
        console.log('💰 Withdrawing platform fees to:', recipient);
        const tx = await vault.withdrawPlatformFees(recipient);
        await tx.wait();
        console.log('✅ Fees withdrawn:', tx.hash);
    } catch (e) {
        console.error('❌ Withdrawal failed:', e);
    }
}

// Run weekly (or call via cron)
withdrawFees();

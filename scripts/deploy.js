const hre = require("hardhat");

async function main() {
  console.log("🚀 Deploying FarMeowVault to Base...");

  // Base Mainnet USDC address
  const USDC_ADDRESS = "0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913";
  
  // Get deployer
  const [deployer] = await ethers.getSigners();
  console.log("📝 Deploying with account:", deployer.address);
  
  const balance = await deployer.getBalance();
  console.log("💰 Account balance:", ethers.utils.formatEther(balance), "ETH");

  // Deploy contract
  const FarMeowVault = await ethers.getContractFactory("FarMeowVault");
  const vault = await FarMeowVault.deploy(
    USDC_ADDRESS,
    deployer.address // Game server address (can be updated later)
  );

  await vault.deployed();

  console.log("✅ FarMeowVault deployed to:", vault.address);
  console.log("📄 USDC Address:", USDC_ADDRESS);
  console.log("🎮 Game Server:", deployer.address);
  
  console.log("\n⏳ Waiting for block confirmations...");
  await vault.deployTransaction.wait(5);
  
  console.log("\n🔍 Verifying contract on BaseScan...");
  try {
    await hre.run("verify:verify", {
      address: vault.address,
      constructorArguments: [USDC_ADDRESS, deployer.address],
    });
    console.log("✅ Contract verified!");
  } catch (error) {
    console.log("⚠️  Verification failed:", error.message);
    console.log("You can verify manually later with:");
    console.log(`npx hardhat verify --network base ${vault.address} ${USDC_ADDRESS} ${deployer.address}`);
  }
  
  console.log("\n📋 Deployment Summary:");
  console.log("=====================");
  console.log("Contract Address:", vault.address);
  console.log("Network: Base Mainnet");
  console.log("Chain ID: 8453");
  console.log("\n🔗 Update these addresses in:");
  console.log("  - App.html (CONFIG.VAULT_CONTRACT)");
  console.log("  - backend/.env (VAULT_CONTRACT_ADDRESS)");
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });

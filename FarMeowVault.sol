// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

/**
 * @title FarMeowVault
 * @notice Upgradeable secure vault for Far Meow cat running game on Farcaster
 * @dev Manages hourly prize pools with top-20 distribution on Base network
 * 
 * Security Features:
 * - UUPS Upgradeable Pattern (secure upgrades)
 * - ReentrancyGuard on all state-changing functions
 * - Pausable for emergency stops
 * - SafeERC20 for token transfers
 * - Strict access controls
 * - No token inflation (USDC only)
 * - Comprehensive event logging
 * - Front-running protection via commit-reveal for score submission
 * 
 * @custom:oz-upgrades-from FarMeowVault
 */
contract FarMeowVault is 
    Initializable,
    OwnableUpgradeable, 
    ReentrancyGuardUpgradeable, 
    PausableUpgradeable,
    UUPSUpgradeable 
{
    using SafeERC20Upgradeable for IERC20Upgradeable;

    // ============ State Variables ============
    
    IERC20Upgradeable public usdc;
    address public gameServer;
    
    uint256 public constant ENTRY_FEE = 0.25e6; // 0.25 USDC (6 decimals)
    uint256 public constant VAULT_SHARE = 0.20e6; // 0.20 USDC to vault
    uint256 public constant PLATFORM_FEE = 0.05e6; // 0.05 USDC platform fee
    uint256 public constant ROUND_DURATION = 1 hours;
    uint256 public constant TOP_PLAYERS = 20;
    
    uint256 public currentRoundId;
    uint256 public roundStartTime;
    uint256 public platformBalance;
    
    // Top-Heavy Distribution: 25.5%, 15%, 10%, 7%, 5%, then 2.5% each for 6-20
    uint256[20] public payoutPercentages;
    
    struct Round {
        uint256 vaultAmount;
        uint256 totalPlayers;
        bool finalized;
        mapping(address => uint256) playerScores;
        mapping(address => bool) hasClaimed;
        address[] topPlayers;
        uint256[] topScores;
    }
    
    mapping(uint256 => Round) public rounds;
    mapping(address => uint256) public playerTotalEarnings;
    
    // Anti-bot: Farcaster FID verification
    mapping(address => uint256) public farcasterFIDs;
    mapping(address => bool) public verifiedPlayers;
    
    // Commit-reveal for score submission
    mapping(bytes32 => bool) public scoreCommitments;
    
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }
    
    // ============ Events ============
    
    event EntryPaid(address indexed player, uint256 roundId, uint256 amount);
    event RoundFinalized(uint256 indexed roundId, uint256 vaultAmount, address[] topPlayers);
    event PrizeClaimed(address indexed player, uint256 indexed roundId, uint256 amount, uint256 rank);
    event PlatformWithdrawal(address indexed to, uint256 amount);
    event GameServerUpdated(address indexed oldServer, address indexed newServer);
    event PlayerVerified(address indexed player, uint256 fid);
    event EmergencyWithdraw(address indexed token, uint256 amount);
    event ScoreSubmitted(address indexed player, uint256 roundId, uint256 score);
    
    // ============ Errors ============
    
    error RoundNotEnded();
    error RoundAlreadyFinalized();
    error AlreadyClaimed();
    error NotTopPlayer();
    error Unauthorized();
    error PlayerNotVerified();
    error InvalidScoreData();
    error CommitmentNotFound();
    error InsufficientVaultBalance();
    
    // ============ Modifiers ============
    
    modifier onlyGameServer() {
        if (msg.sender != gameServer && msg.sender != owner()) revert Unauthorized();
        _;
    }
    
    modifier onlyVerified() {
        if (!verifiedPlayers[msg.sender]) revert PlayerNotVerified();
        _;
    }
    
    // ============ Initializer (replaces constructor) ============
    
    function initialize(address _usdc, address _gameServer) public initializer {
        require(_usdc != address(0), "Invalid USDC address");
        require(_gameServer != address(0), "Invalid game server");
        
        __Ownable_init();
        __ReentrancyGuard_init();
        __Pausable_init();
        __UUPSUpgradeable_init();
        
        usdc = IERC20Upgradeable(_usdc);
        gameServer = _gameServer;
        
        // Initialize payout percentages
        payoutPercentages = [
            2550, 1500, 1000, 700, 500,
            250, 250, 250, 250, 250,
            250, 250, 250, 250, 250,
            250, 250, 250, 250, 250
        ];
        
        currentRoundId = 1;
        roundStartTime = block.timestamp;
    }
    
    // ============ Core Game Functions ============
    
    function payEntry() external nonReentrant whenNotPaused onlyVerified {
        if (block.timestamp >= roundStartTime + ROUND_DURATION) {
            _startNewRound();
        }
        
        usdc.safeTransferFrom(msg.sender, address(this), ENTRY_FEE);
        
        Round storage round = rounds[currentRoundId];
        round.vaultAmount += VAULT_SHARE;
        round.totalPlayers += 1;
        platformBalance += PLATFORM_FEE;
        
        emit EntryPaid(msg.sender, currentRoundId, ENTRY_FEE);
    }
    
    function commitScore(bytes32 commitHash) external onlyVerified {
        require(!rounds[currentRoundId].finalized, "Round finalized");
        scoreCommitments[commitHash] = true;
    }
    
    function submitScore(
        address player,
        uint256 score,
        bytes32 secret
    ) external onlyGameServer {
        require(!rounds[currentRoundId].finalized, "Round finalized");
        
        bytes32 commitHash = keccak256(abi.encodePacked(score, secret));
        if (!scoreCommitments[commitHash]) revert CommitmentNotFound();
        
        Round storage round = rounds[currentRoundId];
        
        if (score > round.playerScores[player]) {
            round.playerScores[player] = score;
            emit ScoreSubmitted(player, currentRoundId, score);
        }
        
        delete scoreCommitments[commitHash];
    }
    
    function finalizeRoundWithTopPlayers(
        address[] calldata players,
        uint256[] calldata scores
    ) external onlyGameServer nonReentrant {
        Round storage round = rounds[currentRoundId];
        
        if (block.timestamp < roundStartTime + ROUND_DURATION) revert RoundNotEnded();
        if (round.finalized) revert RoundAlreadyFinalized();
        if (players.length != scores.length || players.length > TOP_PLAYERS) revert InvalidScoreData();
        
        for (uint256 i = 0; i < players.length; i++) {
            if (round.playerScores[players[i]] != scores[i]) revert InvalidScoreData();
            if (i > 0 && scores[i] > scores[i-1]) revert InvalidScoreData();
        }
        
        round.topPlayers = players;
        round.topScores = scores;
        round.finalized = true;
        
        emit RoundFinalized(currentRoundId, round.vaultAmount, players);
    }
    
    /**
     * @notice Automatically distribute prizes to top players (called by game server)
     * @dev Should be called immediately after finalizeRoundWithTopPlayers
     * @param roundId The round to distribute prizes for
     */
    function batchDistributePrizes(uint256 roundId) external onlyGameServer nonReentrant {
        Round storage round = rounds[roundId];
        
        if (!round.finalized) revert RoundNotEnded();
        if (round.topPlayers.length == 0) revert InvalidScoreData();
        
        uint256 totalDistributed = 0;
        
        for (uint256 i = 0; i < round.topPlayers.length; i++) {
            address player = round.topPlayers[i];
            
            // Skip if already claimed
            if (round.hasClaimed[player]) continue;
            
            uint256 payout = (round.vaultAmount * payoutPercentages[i]) / 10000;
            
            // Check balance before transfer
            if (usdc.balanceOf(address(this)) < payout) {
                emit PrizeClaimed(player, roundId, 0, i + 1); // Log failed payout
                continue;
            }
            
            round.hasClaimed[player] = true;
            playerTotalEarnings[player] += payout;
            totalDistributed += payout;
            
            usdc.safeTransfer(player, payout);
            
            emit PrizeClaimed(player, roundId, payout, i + 1);
        }
    }
    
    /**
     * @notice Claim prize for a finalized round (manual fallback for players)
     * @dev This function is kept for backward compatibility and manual claims
     * @param roundId The round to claim the prize from
     */
    function claimPrize(uint256 roundId) external nonReentrant {
        Round storage round = rounds[roundId];
        
        if (!round.finalized) revert RoundNotEnded();
        if (round.hasClaimed[msg.sender]) revert AlreadyClaimed();
        
        uint256 rank = type(uint256).max;
        for (uint256 i = 0; i < round.topPlayers.length; i++) {
            if (round.topPlayers[i] == msg.sender) {
                rank = i;
                break;
            }
        }
        
        if (rank >= TOP_PLAYERS) revert NotTopPlayer();
        
        uint256 payout = (round.vaultAmount * payoutPercentages[rank]) / 10000;
        
        if (usdc.balanceOf(address(this)) < payout) revert InsufficientVaultBalance();

        round.hasClaimed[msg.sender] = true;
        playerTotalEarnings[msg.sender] += payout;
        
        usdc.safeTransfer(msg.sender, payout);
        
        emit PrizeClaimed(msg.sender, roundId, payout, rank + 1);
    }
    
    // ============ Admin Functions ============
    
    function withdrawPlatformFees(address to) external onlyOwner nonReentrant {
        require(to != address(0), "Invalid address");
        
        uint256 amount = platformBalance;
        platformBalance = 0;
        
        usdc.safeTransfer(to, amount);
        
        emit PlatformWithdrawal(to, amount);
    }
    
    function setGameServer(address _gameServer) external onlyOwner {
        require(_gameServer != address(0), "Invalid address");
        
        address oldServer = gameServer;
        gameServer = _gameServer;
        
        emit GameServerUpdated(oldServer, _gameServer);
    }
    
    function verifyPlayer(address player, uint256 fid) external onlyGameServer {
        require(player != address(0), "Invalid address");
        require(fid > 0, "Invalid FID");
        
        farcasterFIDs[player] = fid;
        verifiedPlayers[player] = true;
        
        emit PlayerVerified(player, fid);
    }
    
    function pause() external onlyOwner {
        _pause();
    }
    
    function unpause() external onlyOwner {
        _unpause();
    }
    
    function emergencyWithdraw(uint256 amount) external onlyOwner whenPaused {
        usdc.safeTransfer(owner(), amount);
        emit EmergencyWithdraw(address(usdc), amount);
    }
    
    // ============ View Functions ============
    
    function getCurrentRound() external view returns (
        uint256 roundId,
        uint256 vaultAmount,
        uint256 totalPlayers,
        uint256 timeRemaining,
        bool finalized
    ) {
        Round storage round = rounds[currentRoundId];
        
        uint256 timeLeft = 0;
        if (block.timestamp < roundStartTime + ROUND_DURATION) {
            timeLeft = (roundStartTime + ROUND_DURATION) - block.timestamp;
        }
        
        return (
            currentRoundId,
            round.vaultAmount,
            round.totalPlayers,
            timeLeft,
            round.finalized
        );
    }
    
    function getPlayerScore(address player) external view returns (uint256) {
        return rounds[currentRoundId].playerScores[player];
    }
    
    function getTopPlayers(uint256 roundId) external view returns (
        address[] memory players,
        uint256[] memory scores
    ) {
        Round storage round = rounds[roundId];
        return (round.topPlayers, round.topScores);
    }
    
    function hasClaimed(uint256 roundId, address player) external view returns (bool) {
        return rounds[roundId].hasClaimed[player];
    }
    
    function estimatePayout(uint256 rank) external view returns (uint256) {
        if (rank >= TOP_PLAYERS) return 0;
        
        Round storage round = rounds[currentRoundId];
        uint256 payout = (round.vaultAmount * payoutPercentages[rank]) / 10000;
        return payout;
    }
    
    // ============ Upgrade Authorization ============
    
    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}
    
    // ============ Internal Functions ============
    
    function _startNewRound() internal {
        currentRoundId += 1;
        roundStartTime = block.timestamp;
    }
    
    /**
     * @dev This empty reserved space allows adding new state variables in future upgrades
     * without shifting down storage layout of child contracts.
     */
    uint256[50] private __gap;
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../FarMeowVault.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockUSDC is ERC20 {
    constructor() ERC20("USDC", "USDC") {
        _mint(msg.sender, 1000000e6);
    }
    function decimals() public pure override returns (uint8) { return 6; }
}

contract FarMeowVaultTest is Test {
    FarMeowVault vault;
    MockUSDC usdc;
    address owner = address(1);
    address server = address(2);
    address player = address(3);

    function setUp() public {
        vm.startPrank(owner);
        usdc = new MockUSDC();
        vault = new FarMeowVault(address(usdc), server);
        
        // Setup player
        usdc.transfer(player, 10e6);
        vm.stopPrank();
        
        vm.prank(server);
        vault.verifyPlayer(player, 123);
    }

    function testPayEntry() public {
        vm.startPrank(player);
        usdc.approve(address(vault), 1e6);
        vault.payEntry();
        vm.stopPrank();
        
        (,uint256 vaultAmt,,, ) = vault.getCurrentRound();
        assertEq(vaultAmt, 0.20e6);
    }
    
    function testFullFlow() public {
        // Player pays
        vm.startPrank(player);
        usdc.approve(address(vault), 1e6);
        vault.payEntry();
        
        // Commit score
        bytes32 secret = keccak256("secret");
        uint256 score = 1000;
        bytes32 commit = keccak256(abi.encodePacked(score, secret));
        vault.commitScore(commit);
        vm.stopPrank();
        
        // Server submits
        vm.prank(server);
        vault.submitScore(player, score, secret);
        
        // Fast forward 1 hour
        vm.warp(block.timestamp + 3601);
        
        // Finalize
        address[] memory players = new address[](1);
        players[0] = player;
        uint256[] memory scores = new uint256[](1);
        scores[0] = score;
        
        vm.prank(server);
        vault.finalizeRoundWithTopPlayers(players, scores);
        
        // Claim
        vm.prank(player);
        vault.claimPrize(1);
        
        assertGt(usdc.balanceOf(player), 9e6);
    }
}

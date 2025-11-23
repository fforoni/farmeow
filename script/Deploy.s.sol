// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../FarMeowVault.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract DeployScript is Script {
    function run() external {
        // Load from environment
        address usdcAddress = vm.envAddress("USDC_ADDRESS");
        address gameServer = vm.envAddress("GAME_SERVER");
        
        console.log("==============================================");
        console.log("Deploying FarMeowVault to Base Sepolia");
        console.log("==============================================");
        console.log("USDC Address:", usdcAddress);
        console.log("Game Server:", gameServer);
        console.log("");
        
        vm.startBroadcast();
        
        // Step 1: Deploy implementation
        console.log("Deploying implementation...");
        FarMeowVault implementation = new FarMeowVault();
        console.log("Implementation:", address(implementation));
        
        // Step 2: Encode initializer
        bytes memory initData = abi.encodeWithSelector(
            FarMeowVault.initialize.selector,
            usdcAddress,
            gameServer
        );
        
        // Step 3: Deploy proxy
        console.log("Deploying proxy...");
        ERC1967Proxy proxy = new ERC1967Proxy(
            address(implementation),
            initData
        );
        
        console.log("");
        console.log("==============================================");
        console.log("DEPLOYMENT SUCCESSFUL!");
        console.log("==============================================");
        console.log("Proxy Address:", address(proxy));
        console.log("Implementation:", address(implementation));
        console.log("");
        console.log("UPDATE App.html:");
        console.log("VAULT_CONTRACT: '%s'", address(proxy));
        console.log("==============================================");
        
        vm.stopBroadcast();
    }
}

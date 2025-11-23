// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../FarMeowVault.sol";

contract UpgradeScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address proxyAddress = vm.envAddress("PROXY_ADDRESS");
        
        vm.startBroadcast(deployerPrivateKey);
        
        // Deploy new implementation
        FarMeowVault newImplementation = new FarMeowVault();
        console.log("New implementation deployed at:", address(newImplementation));
        
        // Upgrade proxy to new implementation
        FarMeowVault proxy = FarMeowVault(proxyAddress);
        proxy.upgradeTo(address(newImplementation));
        
        console.log("Proxy upgraded successfully");
        
        vm.stopBroadcast();
    }
}

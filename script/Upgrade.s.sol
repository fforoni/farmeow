// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../FarMeowVault.sol";

contract UpgradeScript is Script {
    function run() external {
        address proxyAddress = vm.envAddress("PROXY_ADDRESS");
        
        console.log("Upgrading FarMeowVault at:", proxyAddress);
        
        vm.startBroadcast();
        
        // Deploy new implementation
        FarMeowVault newImpl = new FarMeowVault();
        console.log("New Implementation:", address(newImpl));
        
        // Upgrade proxy
        FarMeowVault proxy = FarMeowVault(proxyAddress);
        proxy.upgradeTo(address(newImpl));
        
        console.log("Upgrade successful!");
        
        vm.stopBroadcast();
    }
}

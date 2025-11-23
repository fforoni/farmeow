// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../FarMeowVault.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract DeploySafeScript is Script {
    function run() external {
        // Use a temporary deployer wallet
        uint256 deployerKey = vm.envUint("TEMP_DEPLOYER_KEY");
        address safeMultisig = vm.envAddress("SAFE_ADDRESS"); // Your Safe wallet
        
        vm.startBroadcast(deployerKey);
        
        FarMeowVault implementation = new FarMeowVault();
        
        bytes memory data = abi.encodeWithSelector(
            FarMeowVault.initialize.selector,
            vm.envAddress("USDC_ADDRESS"),
            vm.envAddress("GAME_SERVER")
        );
        
        ERC1967Proxy proxy = new ERC1967Proxy(
            address(implementation),
            data
        );
        
        // Transfer ownership to Safe
        FarMeowVault(address(proxy)).transferOwnership(safeMultisig);
        
        console.log("Proxy:", address(proxy));
        console.log("Owner transferred to Safe:", safeMultisig);
        
        vm.stopBroadcast();
    }
}

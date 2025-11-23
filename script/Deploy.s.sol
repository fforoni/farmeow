// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../FarMeowVault.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract DeployScript is Script {
    function run() external {
        // SECURE: Read from env, never hardcode
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        address usdcAddress = vm.envAddress("USDC_ADDRESS");
        address gameServer = vm.envAddress("GAME_SERVER");
        
        vm.startBroadcast(deployerPrivateKey);
        
        // Deploy implementation
        FarMeowVault implementation = new FarMeowVault();
        console.log("Implementation:", address(implementation));
        
        // Encode initializer
        bytes memory data = abi.encodeWithSelector(
            FarMeowVault.initialize.selector,
            usdcAddress,
            gameServer
        );
        
        // Deploy proxy
        ERC1967Proxy proxy = new ERC1967Proxy(
            address(implementation),
            data
        );
        console.log("Proxy (use this):", address(proxy));
        
        vm.stopBroadcast();
    }
}

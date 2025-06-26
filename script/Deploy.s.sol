// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {ShuffleToken} from "../src/ShuffleStakeToken.sol";

contract DeployScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        // VRF Configuration - these should be set based on the network
        address vrfCoordinator = vm.envAddress("VRF_COORDINATOR");
        uint64 subscriptionId = uint64(vm.envUint("SUBSCRIPTION_ID"));
        bytes32 gasLane = vm.envBytes32("GAS_LANE");
        uint32 callbackGasLimit = uint32(vm.envUint("CALLBACK_GAS_LIMIT"));
        
        console2.log("Deploying ShuffleToken with address:", deployer);
        console2.log("VRF Coordinator:", vrfCoordinator);
        console2.log("Subscription ID:", subscriptionId);
        console2.log("Gas Lane (as uint256):", uint256(gasLane));
        console2.log("Callback Gas Limit:", callbackGasLimit);
        
        vm.startBroadcast(deployerPrivateKey);
        
        ShuffleToken token = new ShuffleToken(
            vrfCoordinator,
            subscriptionId,
            gasLane,
            callbackGasLimit
        );
        
        vm.stopBroadcast();
        
        console2.log("ShuffleToken deployed at:", address(token));
        console2.log("Token name:", token.name());
        console2.log("Token symbol:", token.symbol());
        console2.log("Total supply:", token.totalSupply());
        console2.log("Winners per epoch:", token.WINNERS_PER_EPOCH());
        console2.log("Epoch duration:", token.EPOCH_DURATION());
        console2.log("Owner:", token.owner());
        console2.log("Current epoch:", token.currentEpoch());
    }
} 
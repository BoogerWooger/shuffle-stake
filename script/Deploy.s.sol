// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script, console2} from "forge-std/Script.sol";
import {LotteryToken} from "../src/ShuffleStakeToken.sol";

contract DeployScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        // VRF Configuration - these should be set based on the network
        address vrfCoordinator = vm.envAddress("VRF_COORDINATOR");
        uint64 subscriptionId = vm.envUint64("SUBSCRIPTION_ID");
        bytes32 gasLane = vm.envBytes32("GAS_LANE");
        uint32 callbackGasLimit = vm.envUint32("CALLBACK_GAS_LIMIT");
        
        console2.log("Deploying LotteryToken with address:", deployer);
        console2.log("VRF Coordinator:", vrfCoordinator);
        console2.log("Subscription ID:", subscriptionId);
        console2.log("Gas Lane:", gasLane);
        console2.log("Callback Gas Limit:", callbackGasLimit);
        
        vm.startBroadcast(deployerPrivateKey);
        
        LotteryToken token = new LotteryToken(
            vrfCoordinator,
            subscriptionId,
            gasLane,
            callbackGasLimit
        );
        
        vm.stopBroadcast();
        
        console2.log("LotteryToken deployed at:", address(token));
        console2.log("Token name:", token.name());
        console2.log("Token symbol:", token.symbol());
        console2.log("Total supply:", token.totalSupply());
        console2.log("Winners per epoch:", token.WINNERS_PER_EPOCH());
        console2.log("Epoch duration:", token.EPOCH_DURATION());
        console2.log("Owner:", token.owner());
        console2.log("Current epoch:", token.currentEpoch());
    }
} 
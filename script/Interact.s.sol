// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {ShuffleToken} from "../src/ShuffleStakeToken.sol";

contract InteractScript is Script {
    function run() external {
        // Get contract address from environment or use a default
        address contractAddress = vm.envOr("CONTRACT_ADDRESS", address(0));
        
        // Get deployer private key
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        
        if (contractAddress == address(0)) {
            console2.log("No contract address provided. Deploying new contract...");
            
            // VRF Configuration for local testing
            address vrfCoordinator = vm.envOr("VRF_COORDINATOR", address(0x7a1BaC17Ccc5b313516C5E16fb24f7659aA5ebed)); // Mumbai testnet
            uint64 subscriptionId = uint64(vm.envOr("SUBSCRIPTION_ID", uint256(1)));
            bytes32 gasLane = vm.envOr("GAS_LANE", bytes32(0x4b09e658ed251bcafeebbc69400383d49f344ace09e9576aba6f40893f1b0f08));
            uint32 callbackGasLimit = uint32(vm.envOr("CALLBACK_GAS_LIMIT", uint256(500000)));
            
            vm.startBroadcast(deployerPrivateKey);
            ShuffleToken newToken = new ShuffleToken(
                vrfCoordinator,
                subscriptionId,
                gasLane,
                callbackGasLimit
            );
            vm.stopBroadcast();
            
            contractAddress = address(newToken);
            console2.log("New contract deployed at:", contractAddress);
        } else {
            console2.log("Using existing contract at:", contractAddress);
        }

        // Get the token contract instance
        ShuffleToken token = ShuffleToken(contractAddress);
        
        console2.log("\n=== Contract Information ===");
        console2.log("Token Name:", token.name());
        console2.log("Token Symbol:", token.symbol());
        console2.log("Decimals:", token.decimals());
        console2.log("Total Supply:", token.totalSupply());
        console2.log("Winners Per Epoch:", token.WINNERS_PER_EPOCH());
        console2.log("Epoch Duration:", token.EPOCH_DURATION());
        console2.log("Current Epoch:", token.getCurrentEpoch());
        console2.log("Owner:", token.owner());
        console2.log("User Count:", token.getUserCount());
        console2.log("Randomness Available:", token.isRandomnessAvailable());
        
        console2.log("\n=== Adding Users ===");
        vm.startBroadcast(deployerPrivateKey);
        token.addUser(makeAddr("user1"));
        token.addUser(makeAddr("user2"));
        token.addUser(makeAddr("user3"));
        token.addUser(makeAddr("user4"));
        token.addUser(makeAddr("user5"));
        token.addUser(makeAddr("user6"));
        token.addUser(makeAddr("user7"));
        token.addUser(makeAddr("user8"));
        token.addUser(makeAddr("user9"));
        token.addUser(makeAddr("user10"));
        vm.stopBroadcast();
        
        console2.log("Added 10 users to lottery");
        console2.log("New user count:", token.getUserCount());
        
        console2.log("\n=== Initial Balances ===");
        for (uint256 i = 0; i < 10; i++) {
            address user = token.getAllUsers()[i];
            uint256 balance = token.balanceOf(user);
            console2.log("User", i + 1);
            console2.log("Address:", user);
            console2.log("Balance:", balance, "tokens");
        }
        
        console2.log("\n=== Requesting Randomness ===");
        vm.startBroadcast(deployerPrivateKey);
        token.forceRequestRandomness();
        vm.stopBroadcast();
        
        console2.log("Randomness requested. In a real scenario, this would trigger Chainlink VRF.");
        console2.log("For testing, we'll simulate the callback...");
        
        // For testing, use the test function to set randomness directly
        vm.startBroadcast(deployerPrivateKey);
        token.setRandomSeedForCurrentEpoch(123456789);
        vm.stopBroadcast();
        
        console2.log("Randomness set for testing. Seed: 123456789");
        console2.log("Randomness Available:", token.isRandomnessAvailable());
        
        console2.log("\n=== Final Balances After Randomness ===");
        uint256 totalBalance = 0;
        for (uint256 i = 0; i < 10; i++) {
            address user = token.getAllUsers()[i];
            uint256 balance = token.balanceOf(user);
            totalBalance += balance;
            console2.log("User", i + 1);
            console2.log("Address:", user);
            console2.log("Balance:", balance, "tokens");
        }
        console2.log("Total distributed:", totalBalance, "tokens");
        
        console2.log("\n=== Winners ===");
        address[] memory winners = token.getWinners();
        console2.log("Number of winners:", winners.length);
        for (uint256 i = 0; i < winners.length; i++) {
            console2.log("Winner", i + 1, ":", winners[i]);
        }
        
        console2.log("\n=== Testing User Removal ===");
        vm.startBroadcast(deployerPrivateKey);
        token.removeUser(makeAddr("user1"));
        vm.stopBroadcast();
        
        console2.log("Removed user1 from lottery");
        console2.log("New user count:", token.getUserCount());
        console2.log("User1 balance after removal:", token.balanceOf(makeAddr("user1")));
        
        console2.log("\n=== Testing Epoch Change ===");
        uint256 currentEpoch = token.getCurrentEpoch();
        console2.log("Current epoch:", currentEpoch);
        
        // Simulate epoch change
        vm.warp(block.timestamp + token.EPOCH_DURATION());
        token.checkEpochChange();
        
        console2.log("New epoch:", token.getCurrentEpoch());
        console2.log("Randomness available after epoch change:", token.isRandomnessAvailable());
        
        console2.log("\n=== Final State ===");
        console2.log("Total Supply:", token.totalSupply());
        console2.log("User Count:", token.getUserCount());
        console2.log("Current Epoch:", token.getCurrentEpoch());
        console2.log("Randomness Available:", token.isRandomnessAvailable());
    }
} 
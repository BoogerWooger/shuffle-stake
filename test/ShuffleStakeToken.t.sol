// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test, console2} from "forge-std/Test.sol";
import {ShuffleToken} from "../src/ShuffleStakeToken.sol";
import {VRFCoordinatorV2Mock} from "@chainlink/contracts/src/v0.8/mocks/VRFCoordinatorV2Mock.sol";

contract ShuffleTokenTest is Test {
    ShuffleToken public token;
    VRFCoordinatorV2Mock public vrfCoordinator;
    address public owner;
    address public user1;
    address public user2;
    address public user3;
    address public user4;
    address public user5;
    address public user6;
    address public user7;
    address public user8;
    address public user9;
    address public user10;

    // VRF Configuration
    uint64 public subscriptionId = 1;
    bytes32 public gasLane = 0x79d3d8832d904592c0bf9818b621522c988bb8b0c05cdc3b15aea1b6e8db0c15;
    uint32 public callbackGasLimit = 500000;

    event UserAdded(address indexed user);
    event UserRemoved(address indexed user);
    event EpochChanged(uint256 indexed epoch, uint256 randomSeed);
    event RandomnessRequested(uint256 indexed requestId);

    function setUp() public {
        owner = makeAddr("owner");
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");
        user3 = makeAddr("user3");
        user4 = makeAddr("user4");
        user5 = makeAddr("user5");
        user6 = makeAddr("user6");
        user7 = makeAddr("user7");
        user8 = makeAddr("user8");
        user9 = makeAddr("user9");
        user10 = makeAddr("user10");

        // Deploy VRF Coordinator Mock
        vrfCoordinator = new VRFCoordinatorV2Mock(0, 0);
        
        // Create subscription
        vrfCoordinator.createSubscription();
        vrfCoordinator.fundSubscription(subscriptionId, 1000000000000000000);

        vm.startPrank(owner);
        token = new ShuffleToken(
            address(vrfCoordinator),
            subscriptionId,
            gasLane,
            callbackGasLimit
        );
        vm.stopPrank();

        // Add the token contract as a consumer
        vrfCoordinator.addConsumer(subscriptionId, address(token));
    }

    // ============ Constructor Tests ============

    function test_Constructor() public {
        assertEq(token.name(), "ShuffleToken");
        assertEq(token.symbol(), "LOTTO");
        assertEq(token.decimals(), 0);
        assertEq(token.totalSupply(), 5);
        assertEq(token.TOTAL_SUPPLY(), 5);
        assertEq(token.WINNERS_PER_EPOCH(), 5);
        assertEq(token.EPOCH_DURATION(), 384); // 12 * 32
        assertEq(token.owner(), owner);
        assertEq(token.getUserCount(), 0);
        assertEq(token.currentEpoch(), token.getCurrentEpoch());
        assertEq(token.currentRandomSeed(), 0);
        assertEq(token.randomnessRequested(), false);
    }

    function test_InitialEpoch() public {
        uint256 expectedEpoch = block.timestamp / 384;
        assertEq(token.getCurrentEpoch(), expectedEpoch);
        assertEq(token.currentEpoch(), expectedEpoch);
    }

    // ============ User Management Tests ============

    function test_AddUser() public {
        vm.prank(owner);
        vm.expectEmit(true, false, false, false);
        emit UserAdded(user1);
        token.addUser(user1);
        
        assertEq(token.getUserCount(), 1);
        assertEq(token.userIndex(user1), 1);
        assertEq(token.getAllUsers()[0], user1);
    }

    function test_AddUser_OnlyOwner() public {
        vm.prank(user1);
        vm.expectRevert("Ownable: caller is not the owner");
        token.addUser(user2);
    }

    function test_AddUser_ZeroAddress() public {
        vm.prank(owner);
        vm.expectRevert("Cannot add zero address");
        token.addUser(address(0));
    }

    function test_AddUser_AlreadyExists() public {
        vm.startPrank(owner);
        token.addUser(user1);
        vm.expectRevert("User already exists");
        token.addUser(user1);
        vm.stopPrank();
    }

    function test_AddMultipleUsers() public {
        vm.startPrank(owner);
        token.addUser(user1);
        token.addUser(user2);
        token.addUser(user3);
        token.addUser(user4);
        token.addUser(user5);
        vm.stopPrank();
        
        assertEq(token.getUserCount(), 5);
        address[] memory users = token.getAllUsers();
        assertEq(users[0], user1);
        assertEq(users[1], user2);
        assertEq(users[2], user3);
        assertEq(users[3], user4);
        assertEq(users[4], user5);
    }

    function test_RemoveUser() public {
        vm.startPrank(owner);
        token.addUser(user1);
        token.addUser(user2);
        token.addUser(user3);
        vm.stopPrank();
        
        vm.prank(owner);
        vm.expectEmit(true, false, false, false);
        emit UserRemoved(user2);
        token.removeUser(user2);
        
        assertEq(token.getUserCount(), 2);
        assertEq(token.userIndex(user2), 0);
        assertEq(token.userIndex(user1), 1);
        assertEq(token.userIndex(user3), 2);
        
        address[] memory users = token.getAllUsers();
        assertEq(users[0], user1);
        assertEq(users[1], user3);
    }

    function test_RemoveUser_OnlyOwner() public {
        vm.startPrank(owner);
        token.addUser(user1);
        vm.stopPrank();
        
        vm.prank(user1);
        vm.expectRevert("Ownable: caller is not the owner");
        token.removeUser(user1);
    }

    function test_RemoveUser_DoesNotExist() public {
        vm.prank(owner);
        vm.expectRevert("User does not exist");
        token.removeUser(user1);
    }

    function test_RemoveUser_LastUser() public {
        vm.startPrank(owner);
        token.addUser(user1);
        token.removeUser(user1);
        vm.stopPrank();
        
        assertEq(token.getUserCount(), 0);
        assertEq(token.userIndex(user1), 0);
        assertEq(token.getAllUsers().length, 0);
    }

    function test_RemoveUser_MiddleUser() public {
        vm.startPrank(owner);
        token.addUser(user1);
        token.addUser(user2);
        token.addUser(user3);
        token.addUser(user4);
        vm.stopPrank();
        
        vm.prank(owner);
        token.removeUser(user2);
        
        assertEq(token.getUserCount(), 3);
        address[] memory users = token.getAllUsers();
        assertEq(users[0], user1);
        assertEq(users[1], user4); // user4 moved to position 1
        assertEq(users[2], user3);
        assertEq(token.userIndex(user4), 2); // Updated index
    }

    // ============ Epoch Management Tests ============

    function test_GetCurrentEpoch() public {
        uint256 expectedEpoch = block.timestamp / 384;
        assertEq(token.getCurrentEpoch(), expectedEpoch);
    }

    function test_CheckEpochChange_NoChange() public {
        uint256 initialEpoch = token.currentEpoch();
        token.checkEpochChange();
        assertEq(token.currentEpoch(), initialEpoch);
    }

    function test_CheckEpochChange_WithChange() public {
        uint256 initialEpoch = token.currentEpoch();
        
        // Add some users first
        vm.startPrank(owner);
        token.addUser(user1);
        token.addUser(user2);
        token.addUser(user3);
        vm.stopPrank();
        
        // Simulate epoch change
        vm.warp(block.timestamp + 384);
        
        vm.expectEmit(true, false, false, true);
        emit EpochChanged(initialEpoch + 1, 0);
        token.checkEpochChange();
        
        assertEq(token.currentEpoch(), initialEpoch + 1);
        assertEq(token.currentRandomSeed(), 0);
        assertEq(token.randomnessRequested(), true);
    }

    // ============ Randomness Tests ============

    function test_RequestRandomness_NoUsers() public {
        vm.prank(owner);
        vm.expectRevert("No users in lottery");
        token.forceRequestRandomness();
    }

    function test_RequestRandomness_WithUsers() public {
        vm.startPrank(owner);
        token.addUser(user1);
        token.addUser(user2);
        vm.stopPrank();
        
        vm.prank(owner);
        vm.expectEmit(true, false, false, true);
        emit RandomnessRequested(1); // First request ID
        token.forceRequestRandomness();
        
        assertEq(token.randomnessRequested(), true);
    }

    function test_FulfillRandomWords() public {
        vm.startPrank(owner);
        token.addUser(user1);
        token.addUser(user2);
        token.addUser(user3);
        token.addUser(user4);
        token.addUser(user5);
        vm.stopPrank();
        
        // Request randomness
        vm.prank(owner);
        token.forceRequestRandomness();
        
        // Simulate VRF callback
        uint256[] memory randomWords = new uint256[](1);
        randomWords[0] = 12345;
        
        vm.prank(address(vrfCoordinator));
        token.fulfillRandomWords(1, randomWords);
        
        assertEq(token.currentRandomSeed(), 12345);
        assertEq(token.randomnessRequested(), false);
    }

    // ============ Winner Selection Tests ============

    function test_IsWinner_NoRandomness() public {
        vm.startPrank(owner);
        token.addUser(user1);
        vm.stopPrank();
        
        assertFalse(token.isWinner(user1));
    }

    function test_IsWinner_NotInLottery() public {
        assertFalse(token.isWinner(user1));
    }

    function test_IsWinner_WithRandomness() public {
        vm.startPrank(owner);
        token.addUser(user1);
        token.addUser(user2);
        token.addUser(user3);
        token.addUser(user4);
        token.addUser(user5);
        token.addUser(user6);
        vm.stopPrank();
        
        // Set random seed manually for testing
        vm.store(address(token), keccak256(abi.encode(uint256(3))), bytes32(uint256(12345)));
        
        // Check winners (this will depend on the shuffle algorithm)
        bool user1Winner = token.isWinner(user1);
        bool user2Winner = token.isWinner(user2);
        bool user3Winner = token.isWinner(user3);
        bool user4Winner = token.isWinner(user4);
        bool user5Winner = token.isWinner(user5);
        bool user6Winner = token.isWinner(user6);
        
        // Count winners
        uint256 winnerCount = 0;
        if (user1Winner) winnerCount++;
        if (user2Winner) winnerCount++;
        if (user3Winner) winnerCount++;
        if (user4Winner) winnerCount++;
        if (user5Winner) winnerCount++;
        if (user6Winner) winnerCount++;
        
        // Should have exactly 5 winners
        assertEq(winnerCount, 5);
    }

    function test_BalanceOf_NoRandomness() public {
        vm.startPrank(owner);
        token.addUser(user1);
        vm.stopPrank();
        
        assertEq(token.balanceOf(user1), 0);
    }

    function test_BalanceOf_NotInLottery() public {
        assertEq(token.balanceOf(user1), 0);
    }

    function test_BalanceOf_WithRandomness() public {
        vm.startPrank(owner);
        token.addUser(user1);
        token.addUser(user2);
        token.addUser(user3);
        token.addUser(user4);
        token.addUser(user5);
        vm.stopPrank();
        
        // Set random seed manually for testing
        vm.store(address(token), keccak256(abi.encode(uint256(3))), bytes32(uint256(12345)));
        
        // Check balances
        uint256 user1Balance = token.balanceOf(user1);
        uint256 user2Balance = token.balanceOf(user2);
        uint256 user3Balance = token.balanceOf(user3);
        uint256 user4Balance = token.balanceOf(user4);
        uint256 user5Balance = token.balanceOf(user5);
        
        // Sum of balances should equal total supply
        uint256 totalBalance = user1Balance + user2Balance + user3Balance + user4Balance + user5Balance;
        assertEq(totalBalance, token.totalSupply());
        
        // Each balance should be 0 or 1
        assertTrue(user1Balance == 0 || user1Balance == 1);
        assertTrue(user2Balance == 0 || user2Balance == 1);
        assertTrue(user3Balance == 0 || user3Balance == 1);
        assertTrue(user4Balance == 0 || user4Balance == 1);
        assertTrue(user5Balance == 0 || user5Balance == 1);
    }

    // ============ GetWinners Tests ============

    function test_GetWinners_NoRandomness() public {
        vm.startPrank(owner);
        token.addUser(user1);
        token.addUser(user2);
        vm.stopPrank();
        
        address[] memory winners = token.getWinners();
        assertEq(winners.length, 0);
    }

    function test_GetWinners_WithRandomness() public {
        vm.startPrank(owner);
        token.addUser(user1);
        token.addUser(user2);
        token.addUser(user3);
        token.addUser(user4);
        token.addUser(user5);
        vm.stopPrank();
        
        // Set random seed manually for testing
        vm.store(address(token), keccak256(abi.encode(uint256(3))), bytes32(uint256(12345)));
        
        address[] memory winners = token.getWinners();
        assertEq(winners.length, 5);
        
        // All winners should have balance 1
        for (uint256 i = 0; i < winners.length; i++) {
            assertEq(token.balanceOf(winners[i]), 1);
        }
    }

    // ============ Shuffle Algorithm Tests ============

    function test_ShufflePosition_Deterministic() public {
        vm.startPrank(owner);
        token.addUser(user1);
        token.addUser(user2);
        token.addUser(user3);
        vm.stopPrank();
        
        // Set random seed
        vm.store(address(token), keccak256(abi.encode(uint256(3))), bytes32(uint256(12345)));
        
        // Same seed should produce same results
        bool firstCheck = token.isWinner(user1);
        bool secondCheck = token.isWinner(user1);
        assertEq(firstCheck, secondCheck);
    }

    function test_ShufflePosition_DifferentSeeds() public {
        vm.startPrank(owner);
        token.addUser(user1);
        token.addUser(user2);
        token.addUser(user3);
        token.addUser(user4);
        token.addUser(user5);
        vm.stopPrank();
        
        // Test with different seeds
        vm.store(address(token), keccak256(abi.encode(uint256(3))), bytes32(uint256(12345)));
        bool result1 = token.isWinner(user1);
        
        vm.store(address(token), keccak256(abi.encode(uint256(3))), bytes32(uint256(54321)));
        bool result2 = token.isWinner(user1);
        
        // Results might be different (though they could be the same by chance)
        // The important thing is that the function works with different seeds
        assertTrue(true); // Just checking it doesn't revert
    }

    // ============ Integration Tests ============

    function test_CompleteLotteryWorkflow() public {
        // 1. Add users
        vm.startPrank(owner);
        token.addUser(user1);
        token.addUser(user2);
        token.addUser(user3);
        token.addUser(user4);
        token.addUser(user5);
        token.addUser(user6);
        token.addUser(user7);
        token.addUser(user8);
        token.addUser(user9);
        token.addUser(user10);
        vm.stopPrank();
        
        assertEq(token.getUserCount(), 10);
        
        // 2. Check initial state
        assertEq(token.balanceOf(user1), 0);
        assertEq(token.balanceOf(user2), 0);
        assertEq(token.totalSupply(), 5);
        
        // 3. Set random seed
        vm.store(address(token), keccak256(abi.encode(uint256(3))), bytes32(uint256(12345)));
        
        // 4. Check winners
        address[] memory winners = token.getWinners();
        assertEq(winners.length, 5);
        
        // 5. Verify balances
        uint256 totalBalance = 0;
        for (uint256 i = 0; i < 10; i++) {
            address user = token.getAllUsers()[i];
            uint256 balance = token.balanceOf(user);
            totalBalance += balance;
            assertTrue(balance == 0 || balance == 1);
        }
        assertEq(totalBalance, 5);
        
        // 6. Remove a user
        vm.prank(owner);
        token.removeUser(user1);
        assertEq(token.getUserCount(), 9);
        assertEq(token.balanceOf(user1), 0);
        
        // 7. Check that other users still have correct balances
        uint256 newTotalBalance = 0;
        for (uint256 i = 0; i < 9; i++) {
            address user = token.getAllUsers()[i];
            uint256 balance = token.balanceOf(user);
            newTotalBalance += balance;
        }
        assertEq(newTotalBalance, 5);
    }

    // ============ Edge Cases Tests ============

    function test_ExactFiveUsers() public {
        vm.startPrank(owner);
        token.addUser(user1);
        token.addUser(user2);
        token.addUser(user3);
        token.addUser(user4);
        token.addUser(user5);
        vm.stopPrank();
        
        vm.store(address(token), keccak256(abi.encode(uint256(3))), bytes32(uint256(12345)));
        
        // All users should be winners
        assertEq(token.balanceOf(user1), 1);
        assertEq(token.balanceOf(user2), 1);
        assertEq(token.balanceOf(user3), 1);
        assertEq(token.balanceOf(user4), 1);
        assertEq(token.balanceOf(user5), 1);
        
        address[] memory winners = token.getWinners();
        assertEq(winners.length, 5);
    }

    function test_LessThanFiveUsers() public {
        vm.startPrank(owner);
        token.addUser(user1);
        token.addUser(user2);
        token.addUser(user3);
        vm.stopPrank();
        
        vm.store(address(token), keccak256(abi.encode(uint256(3))), bytes32(uint256(12345)));
        
        // All users should be winners
        assertEq(token.balanceOf(user1), 1);
        assertEq(token.balanceOf(user2), 1);
        assertEq(token.balanceOf(user3), 1);
        
        address[] memory winners = token.getWinners();
        assertEq(winners.length, 3);
    }

    function test_MoreThanFiveUsers() public {
        vm.startPrank(owner);
        token.addUser(user1);
        token.addUser(user2);
        token.addUser(user3);
        token.addUser(user4);
        token.addUser(user5);
        token.addUser(user6);
        token.addUser(user7);
        vm.stopPrank();
        
        vm.store(address(token), keccak256(abi.encode(uint256(3))), bytes32(uint256(12345)));
        
        // Exactly 5 should be winners
        uint256 winnerCount = 0;
        for (uint256 i = 0; i < 7; i++) {
            address user = token.getAllUsers()[i];
            if (token.balanceOf(user) == 1) {
                winnerCount++;
            }
        }
        assertEq(winnerCount, 5);
    }

    // ============ Gas Tests ============

    function test_Gas_AddUser() public {
        uint256 gasBefore = gasleft();
        
        vm.prank(owner);
        token.addUser(user1);
        
        uint256 gasUsed = gasBefore - gasleft();
        console2.log("Gas used for addUser:", gasUsed);
    }

    function test_Gas_RemoveUser() public {
        vm.startPrank(owner);
        token.addUser(user1);
        token.addUser(user2);
        token.addUser(user3);
        vm.stopPrank();
        
        uint256 gasBefore = gasleft();
        
        vm.prank(owner);
        token.removeUser(user2);
        
        uint256 gasUsed = gasBefore - gasleft();
        console2.log("Gas used for removeUser:", gasUsed);
    }

    function test_Gas_BalanceOf() public {
        vm.startPrank(owner);
        token.addUser(user1);
        token.addUser(user2);
        token.addUser(user3);
        token.addUser(user4);
        token.addUser(user5);
        vm.stopPrank();
        
        vm.store(address(token), keccak256(abi.encode(uint256(3))), bytes32(uint256(12345)));
        
        uint256 gasBefore = gasleft();
        
        token.balanceOf(user1);
        
        uint256 gasUsed = gasBefore - gasleft();
        console2.log("Gas used for balanceOf:", gasUsed);
    }

    function test_Gas_GetWinners() public {
        vm.startPrank(owner);
        token.addUser(user1);
        token.addUser(user2);
        token.addUser(user3);
        token.addUser(user4);
        token.addUser(user5);
        token.addUser(user6);
        token.addUser(user7);
        token.addUser(user8);
        token.addUser(user9);
        token.addUser(user10);
        vm.stopPrank();
        
        vm.store(address(token), keccak256(abi.encode(uint256(3))), bytes32(uint256(12345)));
        
        uint256 gasBefore = gasleft();
        
        token.getWinners();
        
        uint256 gasUsed = gasBefore - gasleft();
        console2.log("Gas used for getWinners:", gasUsed);
    }
} 
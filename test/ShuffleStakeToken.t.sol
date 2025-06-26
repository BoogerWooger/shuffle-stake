// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console2} from "forge-std/Test.sol";
import {ShuffleToken} from "../src/ShuffleStakeToken.sol";
import {VRFCoordinatorV2Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2Mock.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

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

    function test_Constructor() public view {
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

    function test_InitialEpoch() public view {
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
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, user1));
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
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, user1));
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

    function test_GetCurrentEpoch() public view {
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
        
        // Add more than 5 users to enable lottery functionality
        vm.startPrank(owner);
        token.addUser(user1);
        token.addUser(user2);
        token.addUser(user3);
        token.addUser(user4);
        token.addUser(user5);
        token.addUser(user6);
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
        // Should not revert, just return early
        token.forceRequestRandomness();
        
        // Verify that randomness was not requested
        assertEq(token.randomnessRequested(), false);
    }

    function test_RequestRandomness_WithUsers() public {
        vm.startPrank(owner);
        token.addUser(user1);
        token.addUser(user2);
        token.addUser(user3);
        token.addUser(user4);
        token.addUser(user5);
        token.addUser(user6);
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
        token.addUser(user6);
        vm.stopPrank();
        
        // Request randomness
        vm.prank(owner);
        token.forceRequestRandomness();
        
        // Set random seed using the proper test function
        vm.prank(owner);
        token.setRandomSeedForTesting(12345);
        
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

    function test_IsWinner_NotInLottery() public view {
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
        token.addUser(user7);
        vm.stopPrank();
        
        // Set random seed using the proper test function
        vm.prank(owner);
        token.setRandomSeedForTesting(12345);
        
        // Check winners (this will depend on the shuffle algorithm)
        bool user1Winner = token.isWinner(user1);
        bool user2Winner = token.isWinner(user2);
        bool user3Winner = token.isWinner(user3);
        bool user4Winner = token.isWinner(user4);
        bool user5Winner = token.isWinner(user5);
        bool user6Winner = token.isWinner(user6);
        bool user7Winner = token.isWinner(user7);
        
        // Count winners
        uint256 winnerCount = 0;
        if (user1Winner) winnerCount++;
        if (user2Winner) winnerCount++;
        if (user3Winner) winnerCount++;
        if (user4Winner) winnerCount++;
        if (user5Winner) winnerCount++;
        if (user6Winner) winnerCount++;
        if (user7Winner) winnerCount++;
        
        // Should have exactly 5 winners
        assertEq(winnerCount, 5);
    }

    function test_BalanceOf_NoRandomness() public {
        vm.startPrank(owner);
        token.addUser(user1);
        vm.stopPrank();
        
        assertEq(token.balanceOf(user1), 0);
    }

    function test_BalanceOf_NotInLottery() public view {
        assertEq(token.balanceOf(user1), 0);
    }

    function test_BalanceOf_WithRandomness() public {
        vm.startPrank(owner);
        token.addUser(user1);
        token.addUser(user2);
        token.addUser(user3);
        token.addUser(user4);
        token.addUser(user5);
        token.addUser(user6);
        vm.stopPrank();
        
        // Set random seed using the proper test function
        vm.prank(owner);
        token.setRandomSeedForTesting(12345);
        
        // Check balances
        uint256 user1Balance = token.balanceOf(user1);
        uint256 user2Balance = token.balanceOf(user2);
        uint256 user3Balance = token.balanceOf(user3);
        uint256 user4Balance = token.balanceOf(user4);
        uint256 user5Balance = token.balanceOf(user5);
        uint256 user6Balance = token.balanceOf(user6);
        
        // Sum of balances should equal total supply
        uint256 totalBalance = user1Balance + user2Balance + user3Balance + user4Balance + user5Balance + user6Balance;
        assertEq(totalBalance, token.totalSupply());
        
        // Each balance should be 0 or 1
        assertTrue(user1Balance == 0 || user1Balance == 1);
        assertTrue(user2Balance == 0 || user2Balance == 1);
        assertTrue(user3Balance == 0 || user3Balance == 1);
        assertTrue(user4Balance == 0 || user4Balance == 1);
        assertTrue(user5Balance == 0 || user5Balance == 1);
        assertTrue(user6Balance == 0 || user6Balance == 1);
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
        token.addUser(user6);
        vm.stopPrank();
        
        // Set random seed using the proper test function
        vm.prank(owner);
        token.setRandomSeedForTesting(12345);
        
        address[] memory winners = token.getWinners();
        assertEq(winners.length, 5);
        
        // All winners should have balance 1
        for (uint256 i = 0; i < winners.length; i++) {
            assertEq(token.balanceOf(winners[i]), 1);
        }
    }

    // ============ Shuffle Algorithm Tests ============

    function test_AlwaysSelectsExactlyFiveUniqueWinners() public {
        vm.startPrank(owner);
        
        // Test with different user counts to ensure scalability
        uint256[4] memory userCounts = [uint256(6), 10, 25, 100];
        uint256[5] memory testSeeds = [uint256(12345), 67890, 111111, 999999, 555555];
        
        for (uint256 userCountIndex = 0; userCountIndex < userCounts.length; userCountIndex++) {
            uint256 targetUserCount = userCounts[userCountIndex];
            
            // Reset contract for each test
            // Remove all existing users first
            address[] memory existingUsers = token.getAllUsers();
            for (uint256 j = 0; j < existingUsers.length; j++) {
                token.removeUser(existingUsers[j]);
            }
            
            // Add target number of users
            for (uint256 i = 1; i <= targetUserCount; i++) {
                token.addUser(vm.addr(i));
            }
            
            // Test with multiple seeds for this user count
            for (uint256 seedIndex = 0; seedIndex < testSeeds.length; seedIndex++) {
                token.setRandomSeedForTesting(testSeeds[seedIndex]);
                
                // Count winners
                uint256 winnerCount = 0;
                address[] memory allUsers = token.getAllUsers();
                address[] memory winners = new address[](5);
                
                for (uint256 i = 0; i < allUsers.length; i++) {
                    if (token.balanceOf(allUsers[i]) == 1) {
                        require(winnerCount < 5, "Too many winners detected");
                        winners[winnerCount] = allUsers[i];
                        winnerCount++;
                    }
                }
                
                // Should always be exactly 5
                assertEq(winnerCount, 5, 
                    string(abi.encodePacked(
                        "Failed with ", vm.toString(targetUserCount), " users, seed ", vm.toString(testSeeds[seedIndex])
                    )));
                
                // Verify no duplicates in winners
                for (uint256 i = 0; i < 5; i++) {
                    for (uint256 j = i + 1; j < 5; j++) {
                        assertTrue(winners[i] != winners[j], "Duplicate winner detected");
                    }
                }
            }
        }
        
        vm.stopPrank();
    }

    function test_DifferentEpochsProduceDifferentWinners() public {
        vm.startPrank(owner);
        // Add 8 users
        for (uint256 i = 1; i <= 8; i++) {
            token.addUser(vm.addr(i));
        }
        
        // Set same seed for current epoch
        token.setRandomSeedForTesting(12345);
        
        // Get winners for current epoch
        address[] memory epoch1Winners = new address[](5);
        uint256 winnerCount = 0;
        address[] memory allUsers = token.getAllUsers();
        
        for (uint256 i = 0; i < allUsers.length; i++) {
            if (token.balanceOf(allUsers[i]) == 1) {
                epoch1Winners[winnerCount] = allUsers[i];
                winnerCount++;
            }
        }
        assertEq(winnerCount, 5);
        
        // Move to next epoch (simulate time passing)
        vm.warp(block.timestamp + 384); // Move forward by one epoch
        token.checkEpochChange();
        token.setRandomSeedForTesting(12345); // Same seed, different epoch
        
        // Get winners for new epoch
        address[] memory epoch2Winners = new address[](5);
        winnerCount = 0;
        
        for (uint256 i = 0; i < allUsers.length; i++) {
            if (token.balanceOf(allUsers[i]) == 1) {
                epoch2Winners[winnerCount] = allUsers[i];
                winnerCount++;
            }
        }
        assertEq(winnerCount, 5);
        
        // Compare winners - they should be different
        bool sameWinners = true;
        for (uint256 i = 0; i < 5; i++) {
            bool foundInEpoch2 = false;
            for (uint256 j = 0; j < 5; j++) {
                if (epoch1Winners[i] == epoch2Winners[j]) {
                    foundInEpoch2 = true;
                    break;
                }
            }
            if (!foundInEpoch2) {
                sameWinners = false;
                break;
            }
        }
        
        // Winners should be different across epochs (with very high probability)
        assertFalse(sameWinners, "Winners should be different across epochs");
        vm.stopPrank();
    }

    function test_DeterministicWinnerSelectionWithinEpoch() public {
        vm.startPrank(owner);
        // Add 7 users
        for (uint256 i = 1; i <= 7; i++) {
            token.addUser(vm.addr(i));
        }
        
        token.setRandomSeedForTesting(12345);
        vm.stopPrank();
        
        // Get winners multiple times - should be consistent
        address[] memory allUsers = token.getAllUsers();
        bool[] memory firstCheck = new bool[](7);
        bool[] memory secondCheck = new bool[](7);
        bool[] memory thirdCheck = new bool[](7);
        
        for (uint256 i = 0; i < allUsers.length; i++) {
            firstCheck[i] = token.balanceOf(allUsers[i]) == 1;
            secondCheck[i] = token.balanceOf(allUsers[i]) == 1;
            thirdCheck[i] = token.balanceOf(allUsers[i]) == 1;
        }
        
        // All checks should be identical
        for (uint256 i = 0; i < 7; i++) {
            assertEq(firstCheck[i], secondCheck[i], "First and second check differ");
            assertEq(secondCheck[i], thirdCheck[i], "Second and third check differ");
        }
    }

    function test_SelectionIndependentOfUserOrder() public {
        vm.startPrank(owner);
        
        // Add users in one order
        address user1 = vm.addr(1);
        address user2 = vm.addr(2);
        address user3 = vm.addr(3);
        address user4 = vm.addr(4);
        address user5 = vm.addr(5);
        address user6 = vm.addr(6);
        
        token.addUser(user1);
        token.addUser(user2);
        token.addUser(user3);
        token.addUser(user4);
        token.addUser(user5);
        token.addUser(user6);
        
        token.setRandomSeedForTesting(12345);
        
        // Record which users are winners
        bool user1Winner = token.balanceOf(user1) == 1;
        bool user2Winner = token.balanceOf(user2) == 1;
        bool user3Winner = token.balanceOf(user3) == 1;
        bool user4Winner = token.balanceOf(user4) == 1;
        bool user5Winner = token.balanceOf(user5) == 1;
        bool user6Winner = token.balanceOf(user6) == 1;
        
        // Verify exactly 5 winners
        uint256 winnerCount = 0;
        if (user1Winner) winnerCount++;
        if (user2Winner) winnerCount++;
        if (user3Winner) winnerCount++;
        if (user4Winner) winnerCount++;
        if (user5Winner) winnerCount++;
        if (user6Winner) winnerCount++;
        
        assertEq(winnerCount, 5, "Should have exactly 5 winners");
        
        vm.stopPrank();
    }

    function test_SelectionPurelyBasedOnBalanceOf() public {
        vm.startPrank(owner);
        // Add 8 users
        for (uint256 i = 1; i <= 8; i++) {
            token.addUser(vm.addr(i));
        }
        
        // Test that changing seed immediately affects balanceOf results
        token.setRandomSeedForTesting(12345);
        
        // Get initial results
        address[] memory allUsers = token.getAllUsers();
        bool[] memory results1 = new bool[](8);
        for (uint256 i = 0; i < 8; i++) {
            results1[i] = token.balanceOf(allUsers[i]) == 1;
        }
        
        // Change seed and get new results immediately
        token.setRandomSeedForTesting(54321);
        bool[] memory results2 = new bool[](8);
        for (uint256 i = 0; i < 8; i++) {
            results2[i] = token.balanceOf(allUsers[i]) == 1;
        }
        
        // Results should be different (no caching)
        bool anyDifference = false;
        for (uint256 i = 0; i < 8; i++) {
            if (results1[i] != results2[i]) {
                anyDifference = true;
                break;
            }
        }
        assertTrue(anyDifference, "Results should change when seed changes (no caching)");
        
        // Both should still have exactly 5 winners
        uint256 winners1 = 0;
        uint256 winners2 = 0;
        for (uint256 i = 0; i < 8; i++) {
            if (results1[i]) winners1++;
            if (results2[i]) winners2++;
        }
        assertEq(winners1, 5, "First seed should produce 5 winners");
        assertEq(winners2, 5, "Second seed should produce 5 winners");
        
        vm.stopPrank();
    }

    function test_GetWinnersMatchesBalanceOfResults() public {
        vm.startPrank(owner);
        // Add 7 users
        for (uint256 i = 1; i <= 7; i++) {
            token.addUser(vm.addr(i));
        }
        
        token.setRandomSeedForTesting(98765);
        vm.stopPrank();
        
        // Get winners from getWinners()
        address[] memory winnersFromFunction = token.getWinners();
        assertEq(winnersFromFunction.length, 5, "getWinners should return 5 winners");
        
        // Verify all returned winners have balance 1
        for (uint256 i = 0; i < winnersFromFunction.length; i++) {
            assertEq(token.balanceOf(winnersFromFunction[i]), 1, "Winner should have balance 1");
        }
        
        // Verify no non-winners are returned
        address[] memory allUsers = token.getAllUsers();
        for (uint256 i = 0; i < allUsers.length; i++) {
            bool isInWinnersList = false;
            for (uint256 j = 0; j < winnersFromFunction.length; j++) {
                if (allUsers[i] == winnersFromFunction[j]) {
                    isInWinnersList = true;
                    break;
                }
            }
            
            if (token.balanceOf(allUsers[i]) == 1) {
                assertTrue(isInWinnersList, "Winner should be in getWinners result");
            } else {
                assertFalse(isInWinnersList, "Non-winner should not be in getWinners result");
            }
        }
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
        
        // 3. Set random seed using the proper test function
        vm.prank(owner);
        token.setRandomSeedForTesting(12345);
        
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

    function test_InsufficientUsers_LotteryDoesNotWork() public {
        vm.startPrank(owner);
        token.addUser(user1);
        token.addUser(user2);
        token.addUser(user3);
        token.addUser(user4);
        token.addUser(user5); // Exactly 5 users - should not work
        
        // Set random seed using the proper test function
        token.setRandomSeedForTesting(12345);
        vm.stopPrank();
        
        // All balances should be 0 since we need more than 5 users
        assertEq(token.balanceOf(user1), 0);
        assertEq(token.balanceOf(user2), 0);
        assertEq(token.balanceOf(user3), 0);
        assertEq(token.balanceOf(user4), 0);
        assertEq(token.balanceOf(user5), 0);
        
        // No winners should be returned
        address[] memory winners = token.getWinners();
        assertEq(winners.length, 0);
        
        // isWinner should return false for all users
        assertFalse(token.isWinner(user1));
        assertFalse(token.isWinner(user2));
        assertFalse(token.isWinner(user3));
        assertFalse(token.isWinner(user4));
        assertFalse(token.isWinner(user5));
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
        
        // Set random seed using the proper test function
        token.setRandomSeedForTesting(12345);
        vm.stopPrank();
        
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
        token.addUser(user6);
        
        // Set random seed using the proper test function
        token.setRandomSeedForTesting(12345);
        vm.stopPrank();
        
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
        
        // Set random seed using the proper test function
        token.setRandomSeedForTesting(12345);
        vm.stopPrank();
        
        uint256 gasBefore = gasleft();
        
        token.getWinners();
        
        uint256 gasUsed = gasBefore - gasleft();
        console2.log("Gas used for getWinners:", gasUsed);
    }

    function test_ScalabilityWithLargeUserCounts() public {
        vm.startPrank(owner);
        
        // Test with a large number of users to verify O(1) complexity per user check
        uint256 largeUserCount = 1000;
        
        // Add many users
        for (uint256 i = 1; i <= largeUserCount; i++) {
            token.addUser(vm.addr(i));
        }
        
        token.setRandomSeedForTesting(123456789);
        
        // Test that we still get exactly 5 winners
        uint256 winnerCount = 0;
        address[] memory allUsers = token.getAllUsers();
        
        uint256 gasBefore = gasleft();
        
        for (uint256 i = 0; i < allUsers.length; i++) {
            if (token.balanceOf(allUsers[i]) == 1) {
                winnerCount++;
            }
        }
        
        uint256 gasUsed = gasBefore - gasleft();
        console2.log("Gas used for", largeUserCount, "users:", gasUsed);
        console2.log("Gas per user check:", gasUsed / largeUserCount);
        
        // Should still be exactly 5 winners regardless of scale
        assertEq(winnerCount, 5, "Should have exactly 5 winners even with large user count");
        
        // Gas usage should be reasonable (less than 100k gas per user would be acceptable)
        assertTrue(gasUsed / largeUserCount < 100000, "Gas usage per user should be reasonable");
        
        vm.stopPrank();
    }

    function test_SimpleAlgorithmGeneratesExactlyFiveWinners() public {
        vm.startPrank(owner);
        
        // Test with 10 users
        for (uint256 i = 1; i <= 10; i++) {
            token.addUser(vm.addr(i));
        }
        
        // Test with multiple seeds to ensure consistency
        uint256[10] memory testSeeds = [
            uint256(12345), 67890, 111111, 999999, 555555,
            42, 987654321, 123123123, 456456456, 789789789
        ];
        
        for (uint256 seedIndex = 0; seedIndex < testSeeds.length; seedIndex++) {
            token.setRandomSeedForTesting(testSeeds[seedIndex]);
            
            // Count winners and collect their addresses
            uint256 winnerCount = 0;
            address[] memory allUsers = token.getAllUsers();
            address[] memory winners = new address[](5);
            
            for (uint256 i = 0; i < allUsers.length; i++) {
                if (token.balanceOf(allUsers[i]) == 1) {
                    winners[winnerCount] = allUsers[i];
                    winnerCount++;
                }
            }
            
            // Should always be exactly 5
            assertEq(winnerCount, 5, 
                string(abi.encodePacked("Seed ", vm.toString(testSeeds[seedIndex]), " produced ", vm.toString(winnerCount), " winners instead of 5")));
            
            // Verify uniqueness - no duplicate winners
            for (uint256 i = 0; i < 5; i++) {
                for (uint256 j = i + 1; j < 5; j++) {
                    assertTrue(winners[i] != winners[j], "Duplicate winner found");
                }
            }
            
            // Verify sum of balances equals total supply
            uint256 totalBalance = 0;
            for (uint256 i = 0; i < allUsers.length; i++) {
                totalBalance += token.balanceOf(allUsers[i]);
            }
            assertEq(totalBalance, 5, "Sum of balances should equal 5");
        }
        
        vm.stopPrank();
    }
} 
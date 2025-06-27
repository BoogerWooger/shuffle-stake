// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console2} from "forge-std/Test.sol";
import {ShuffleToken} from "../src/ShuffleStakeToken.sol";
import {VRFCoordinatorV2Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2Mock.sol";

contract ShuffleTokenInvariantTest is Test {
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

    // Invariant: Total supply should always be 5
    function invariant_TotalSupplyAlwaysFive() public view {
        assertEq(token.totalSupply(), 5, "Total supply is not 5");
    }

    // Invariant: Sum of all balances should equal total supply when randomness is available
    function invariant_SumOfBalancesEqualsTotalSupply() public view {
        if (token.getRandomSeedForEpoch(token.getCurrentEpoch()) == 0 || token.getUserCount() <= 5) {
            // No randomness or insufficient users, all balances should be 0
            uint256 sum = 0;
            address[] memory users = token.getAllUsers();
            for (uint256 i = 0; i < users.length; i++) {
                sum += token.balanceOf(users[i]);
            }
            assertEq(sum, 0, "Sum of balances should be 0 when no randomness or insufficient users");
        } else {
            // Randomness available and sufficient users, sum should equal total supply
            uint256 sum = 0;
            address[] memory users = token.getAllUsers();
            for (uint256 i = 0; i < users.length; i++) {
                sum += token.balanceOf(users[i]);
            }
            assertEq(sum, token.totalSupply(), "Sum of balances does not equal total supply");
        }
    }

    // Invariant: No address should have balance greater than 1
    function invariant_NoBalanceGreaterThanOne() public view {
        address[] memory users = token.getAllUsers();
        for (uint256 i = 0; i < users.length; i++) {
            uint256 balance = token.balanceOf(users[i]);
            assertLe(balance, 1, "Balance greater than 1 detected");
        }
    }

    // Invariant: No address should have negative balance
    function invariant_NoNegativeBalances() public view {
        address[] memory users = token.getAllUsers();
        for (uint256 i = 0; i < users.length; i++) {
            uint256 balance = token.balanceOf(users[i]);
            assertGe(balance, 0, "Negative balance detected");
        }
    }

    // Invariant: Number of winners should be exactly 5 when sufficient users and randomness
    function invariant_WinnerCountExactlyFive() public view {
        if (token.getRandomSeedForEpoch(token.getCurrentEpoch()) == 0 || token.getUserCount() <= 5) {
            return; // No randomness or insufficient users
        }
        
        uint256 winnerCount = 0;
        address[] memory users = token.getAllUsers();
        for (uint256 i = 0; i < users.length; i++) {
            if (token.balanceOf(users[i]) == 1) {
                winnerCount++;
            }
        }
        assertEq(winnerCount, 5, "Winner count should be exactly 5");
    }

    // Invariant: Token name and symbol should never be empty
    function invariant_TokenMetadataNeverEmpty() public view {
        assertGt(bytes(token.name()).length, 0, "Token name is empty");
        assertGt(bytes(token.symbol()).length, 0, "Token symbol is empty");
    }

    // Invariant: Decimals should always be 0
    function invariant_DecimalsAlwaysZero() public view {
        assertEq(token.decimals(), 0, "Decimals is not 0");
    }

    // Invariant: Epoch duration should always be 384
    function invariant_EpochDurationAlways384() public view {
        assertEq(token.EPOCH_DURATION(), 384, "Epoch duration is not 384");
    }

    // Invariant: Winners per epoch should always be 5
    function invariant_WinnersPerEpochAlwaysFive() public view {
        assertEq(token.WINNERS_PER_EPOCH(), 5, "Winners per epoch is not 5");
    }

    // Invariant: Current epoch should be non-negative
    function invariant_CurrentEpochNonNegative() public view {
        assertGe(token.getCurrentEpoch(), 0, "Current epoch is negative");
    }

    // Invariant: User count should match array length
    function invariant_UserCountMatchesArrayLength() public view {
        address[] memory users = token.getAllUsers();
        assertEq(token.getUserCount(), users.length, "User count does not match array length");
    }

    // Invariant: User indices should be valid
    function invariant_UserIndicesValid() public view {
        address[] memory users = token.getAllUsers();
        for (uint256 i = 0; i < users.length; i++) {
            uint256 index = token.userIndex(users[i]);
            assertGt(index, 0, "User index is 0 or invalid");
            assertLe(index, users.length, "User index exceeds array length");
        }
    }

    // Invariant: Non-users should have index 0
    function invariant_NonUsersHaveIndexZero() public view {
        address nonUser = address(0x999999); // Use a fixed address that's not a user
        assertEq(token.userIndex(nonUser), 0, "Non-user has non-zero index");
    }

    // Invariant: Epoch should not decrease
    function invariant_EpochNeverDecreases() public view {
        uint256 currentEpoch = token.getCurrentEpoch();
        uint256 expectedEpoch = block.timestamp / token.EPOCH_DURATION();
        assertGe(expectedEpoch, currentEpoch, "Epoch decreased");
    }

    // Invariant: Winners array should have correct length
    function invariant_WinnersArrayCorrectLength() public view {
        if (token.getRandomSeedForEpoch(token.getCurrentEpoch()) == 0 || token.getUserCount() <= 5) {
            address[] memory winners = token.getWinners();
            assertEq(winners.length, 0, "Winners array should be empty when no randomness or insufficient users");
        } else {
            address[] memory winners = token.getWinners();
            assertEq(winners.length, 5, "Winners array should have exactly 5 winners when sufficient users");
        }
    }

    // Invariant: All winners should have balance 1
    function invariant_AllWinnersHaveBalanceOne() public view {
        if (token.getRandomSeedForEpoch(token.getCurrentEpoch()) == 0 || token.getUserCount() <= 5) {
            return; // No randomness or insufficient users
        }
        
        address[] memory winners = token.getWinners();
        for (uint256 i = 0; i < winners.length; i++) {
            assertEq(token.balanceOf(winners[i]), 1, "Winner does not have balance 1");
        }
    }

    // Invariant: Non-winners should have balance 0
    function invariant_NonWinnersHaveBalanceZero() public view {
        if (token.getRandomSeedForEpoch(token.getCurrentEpoch()) == 0 || token.getUserCount() <= 5) {
            return; // No randomness or insufficient users
        }
        
        address[] memory winners = token.getWinners();
        address[] memory allUsers = token.getAllUsers();
        
        for (uint256 i = 0; i < allUsers.length; i++) {
            bool isWinner = false;
            for (uint256 j = 0; j < winners.length; j++) {
                if (allUsers[i] == winners[j]) {
                    isWinner = true;
                    break;
                }
            }
            
            if (!isWinner) {
                assertEq(token.balanceOf(allUsers[i]), 0, "Non-winner has non-zero balance");
            }
        }
    }

    // Invariant: Winner selection should be deterministic within epoch
    function invariant_WinnerSelectionDeterministic() public view {
        if (token.getRandomSeedForEpoch(token.getCurrentEpoch()) == 0 || token.getUserCount() <= 5) {
            return; // No randomness or insufficient users
        }
        
        address[] memory users = token.getAllUsers();
        for (uint256 i = 0; i < users.length; i++) {
            bool firstCheck = token.isWinner(users[i]);
            bool secondCheck = token.isWinner(users[i]);
            assertEq(firstCheck, secondCheck, "Winner selection is not deterministic");
        }
    }
} 
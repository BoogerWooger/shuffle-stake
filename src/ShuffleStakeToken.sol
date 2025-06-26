// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@chainlink/contracts/src/v0.8/vrf/VRFConsumerBaseV2.sol";
import "@chainlink/contracts/src/v0.8/vrf/interfaces/VRFCoordinatorV2Interface.sol";

/**
 * @title ShuffleToken
 * @dev A lottery token that distributes 5 tokens to 5 random users each epoch
 */
contract ShuffleToken is Ownable, VRFConsumerBaseV2 {
    // Chainlink VRF variables
    VRFCoordinatorV2Interface private immutable i_vrfCoordinator;
    uint64 private immutable i_subscriptionId;
    bytes32 private immutable i_gasLane;
    uint32 private immutable i_callbackGasLimit;
    uint16 private constant REQUEST_CONFIRMATIONS = 3;
    uint32 private constant NUM_WORDS = 1;

    // Lottery variables
    uint256 public constant TOTAL_SUPPLY = 5;
    uint256 public constant WINNERS_PER_EPOCH = 5;
    uint256 public constant EPOCH_DURATION = 12 * 32; // 384 seconds (Ethereum epoch)
    
    // User management
    address[] public users;
    mapping(address => uint256) public userIndex; // 1-indexed, 0 means not in array
    uint256 public userCount;
    
    // Epoch and randomness
    uint256 public currentEpoch;
    uint256 public currentRandomSeed;
    bool public randomnessRequested;
    
    // Events
    event UserAdded(address indexed user);
    event UserRemoved(address indexed user);
    event EpochChanged(uint256 indexed epoch, uint256 randomSeed);
    event RandomnessRequested(uint256 indexed requestId);
    event WinnersSelected(uint256 indexed epoch, address[] winners);

    constructor(
        address vrfCoordinatorV2,
        uint64 subscriptionId,
        bytes32 gasLane,
        uint32 callbackGasLimit
    ) VRFConsumerBaseV2(vrfCoordinatorV2) Ownable(msg.sender) {
        i_vrfCoordinator = VRFCoordinatorV2Interface(vrfCoordinatorV2);
        i_subscriptionId = subscriptionId;
        i_gasLane = gasLane;
        i_callbackGasLimit = callbackGasLimit;
        
        // Initialize first epoch
        currentEpoch = getCurrentEpoch();
        currentRandomSeed = 0;
        randomnessRequested = false;
    }

    /**
     * @dev Get current epoch based on block timestamp
     */
    function getCurrentEpoch() public view returns (uint256) {
        return block.timestamp / EPOCH_DURATION;
    }

    /**
     * @dev Add a user to the lottery pool
     * @param user Address of the user to add
     */
    function addUser(address user) external onlyOwner {
        require(user != address(0), "Cannot add zero address");
        require(userIndex[user] == 0, "User already exists");
        
        users.push(user);
        userIndex[user] = users.length; // 1-indexed
        userCount++;
        
        emit UserAdded(user);
    }

    /**
     * @dev Remove a user from the lottery pool
     * @param user Address of the user to remove
     */
    function removeUser(address user) external onlyOwner {
        require(userIndex[user] != 0, "User does not exist");
        
        uint256 index = userIndex[user] - 1; // Convert to 0-indexed
        uint256 lastIndex = users.length - 1;
        
        if (index != lastIndex) {
            // Move last user to the removed position
            address lastUser = users[lastIndex];
            users[index] = lastUser;
            userIndex[lastUser] = index + 1; // Update index for moved user
        }
        
        users.pop();
        delete userIndex[user];
        userCount--;
        
        emit UserRemoved(user);
    }

    /**
     * @dev Check if epoch has changed and request randomness if needed
     */
    function checkEpochChange() public {
        uint256 newEpoch = getCurrentEpoch();
        
        if (newEpoch > currentEpoch) {
            // Epoch changed, reset state
            currentEpoch = newEpoch;
            currentRandomSeed = 0;
            randomnessRequested = false;
            
            // Request new randomness only if we have more than TOTAL_SUPPLY users
            if (userCount > TOTAL_SUPPLY) {
                requestRandomness();
            }
            
            emit EpochChanged(currentEpoch, currentRandomSeed);
        }
    }

    /**
     * @dev Request randomness from Chainlink VRF
     */
    function requestRandomness() internal {
        require(!randomnessRequested, "Randomness already requested");
        require(userCount > TOTAL_SUPPLY, "Need more than TOTAL_SUPPLY users");
        
        randomnessRequested = true;
        uint256 requestId = i_vrfCoordinator.requestRandomWords(
            i_gasLane,
            i_subscriptionId,
            REQUEST_CONFIRMATIONS,
            i_callbackGasLimit,
            NUM_WORDS
        );
        
        emit RandomnessRequested(requestId);
    }

    /**
     * @dev Callback function used by VRF Coordinator
     */
    function fulfillRandomWords(uint256 /* requestId */, uint256[] memory randomWords) internal override {
        currentRandomSeed = randomWords[0];
        randomnessRequested = false;
        
        emit EpochChanged(currentEpoch, currentRandomSeed);
    }

    /**
     * @dev Get the balance of a user (calculated dynamically)
     * @param user Address of the user
     * @return Balance of the user (0 or 1)
     */
    function balanceOf(address user) public view returns (uint256) {
        if (userIndex[user] == 0 || userCount <= TOTAL_SUPPLY) {
            return 0;
        }
        
        // Check if we have randomness for current epoch
        if (currentRandomSeed == 0) {
            return 0;
        }
        
        // Use shuffle-or-not algorithm to determine if user is a winner
        return isWinner(user) ? 1 : 0;
    }

    /**
     * @dev Check if a user is a winner using shuffle-or-not algorithm
     * @param user Address of the user to check
     * @return True if user is a winner
     */
    function isWinner(address user) public view returns (bool) {
        if (userIndex[user] == 0 || userCount <= TOTAL_SUPPLY || currentRandomSeed == 0) {
            return false;
        }
        
        // Use deterministic shuffle to select exactly 5 winners
        uint256 userPos = userIndex[user] - 1; // Convert to 0-indexed
        return isInWinningPositions(userPos, currentRandomSeed);
    }

    /**
     * @dev Check if a user position is in the winning positions using deterministic selection
     * @param userPos The user's position (0-indexed)
     * @param seed Random seed
     * @return True if the user is in a winning position
     */
    function isInWinningPositions(uint256 userPos, uint256 seed) internal view returns (bool) {
        // Use a deterministic approach to select exactly 5 unique positions
        // We'll simulate a Fisher-Yates shuffle to get the first 5 positions
        
        uint256[] memory positions = new uint256[](userCount);
        for (uint256 i = 0; i < userCount; i++) {
            positions[i] = i;
        }
        
        // Perform partial Fisher-Yates shuffle for the first 5 positions
        for (uint256 i = 0; i < WINNERS_PER_EPOCH && i < userCount; i++) {
            // Generate a random index from i to userCount-1
            uint256 randomIndex = i + (uint256(keccak256(abi.encodePacked(seed, i))) % (userCount - i));
            
            // Swap positions[i] with positions[randomIndex]
            uint256 temp = positions[i];
            positions[i] = positions[randomIndex];
            positions[randomIndex] = temp;
            
            // Check if this position matches our user
            if (positions[i] == userPos) {
                return true;
            }
        }
        
        return false;
    }

    /**
     * @dev Get all winners for current epoch
     * @return Array of winner addresses
     */
    function getWinners() external view returns (address[] memory) {
        if (currentRandomSeed == 0 || userCount <= TOTAL_SUPPLY) {
            return new address[](0);
        }
        
        address[] memory winners = new address[](WINNERS_PER_EPOCH);
        uint256 winnerCount = 0;
        
        for (uint256 i = 0; i < users.length && winnerCount < WINNERS_PER_EPOCH; i++) {
            if (isWinner(users[i])) {
                winners[winnerCount] = users[i];
                winnerCount++;
            }
        }
        
        // Resize array to actual winner count
        assembly {
            mstore(winners, winnerCount)
        }
        
        return winners;
    }

    /**
     * @dev Get total supply (always 5)
     */
    function totalSupply() external pure returns (uint256) {
        return TOTAL_SUPPLY;
    }

    /**
     * @dev Get token name
     */
    function name() external pure returns (string memory) {
        return "ShuffleToken";
    }

    /**
     * @dev Get token symbol
     */
    function symbol() external pure returns (string memory) {
        return "LOTTO";
    }

    /**
     * @dev Get token decimals
     */
    function decimals() external pure returns (uint8) {
        return 0; // No decimals for lottery tokens
    }

    /**
     * @dev Get all users in the lottery
     */
    function getAllUsers() external view returns (address[] memory) {
        return users;
    }

    /**
     * @dev Get user count
     */
    function getUserCount() external view returns (uint256) {
        return userCount;
    }

    /**
     * @dev Check if randomness is available for current epoch
     */
    function isRandomnessAvailable() external view returns (bool) {
        return currentRandomSeed != 0;
    }

    /**
     * @dev Force request randomness (for testing)
     */
    function forceRequestRandomness() external onlyOwner {
        if (userCount > TOTAL_SUPPLY) {
            requestRandomness();
        }
    }

    /**
     * @dev Set random seed directly (for testing only)
     * @param seed The random seed to set
     */
    function setRandomSeedForTesting(uint256 seed) external onlyOwner {
        currentRandomSeed = seed;
        randomnessRequested = false;
        emit EpochChanged(currentEpoch, currentRandomSeed);
    }
} 
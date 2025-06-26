// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@chainlink/contracts/src/v0.8/vrf/VRFConsumerBaseV2.sol";
import "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";

/**
 * @title LotteryToken
 * @dev A lottery token that distributes 5 tokens to 5 random users each epoch
 */
contract LotteryToken is Ownable, VRFConsumerBaseV2 {
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
            
            // Request new randomness if we have users
            if (userCount > 0) {
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
        require(userCount > 0, "No users in lottery");
        
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
    function fulfillRandomWords(uint256 requestId, uint256[] memory randomWords) internal override {
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
        if (userIndex[user] == 0 || userCount == 0) {
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
        if (userIndex[user] == 0 || userCount == 0 || currentRandomSeed == 0) {
            return false;
        }
        
        // Use deterministic shuffle based on random seed
        uint256 userPos = userIndex[user] - 1; // Convert to 0-indexed
        uint256 shuffledPos = shufflePosition(userPos, currentRandomSeed);
        
        // Top 5 positions are winners
        return shuffledPos < WINNERS_PER_EPOCH;
    }

    /**
     * @dev Shuffle position using deterministic algorithm
     * @param position Original position
     * @param seed Random seed
     * @return Shuffled position
     */
    function shufflePosition(uint256 position, uint256 seed) internal pure returns (uint256) {
        // Use a simple but effective shuffling algorithm
        uint256 hash = uint256(keccak256(abi.encodePacked(position, seed)));
        return hash % userCount;
    }

    /**
     * @dev Get all winners for current epoch
     * @return Array of winner addresses
     */
    function getWinners() external view returns (address[] memory) {
        if (currentRandomSeed == 0 || userCount == 0) {
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
        return "LotteryToken";
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
        if (userCount > 0) {
            requestRandomness();
        }
    }
} 
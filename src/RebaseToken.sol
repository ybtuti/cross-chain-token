// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/**
 * @title RebaseToken
 * @author ybtuti
 * @notice This is a chroos chain token that incentivises users to deposit into a vault and gain interest.
 * @notice The Interest rate in the smart contract can only decrease
 * @notice Each user will have their own iterest rate ie the global interest rate at the time of depositing.
 */
contract RebaseToken is ERC20 {
    error RebaseToken__InterestRateCanOnlyDecrease(uint256 oldInterestRate, uint256 newInterestRate);

    uint256 private constant PRECISION_FACTOR = 1e18;
    uint256 private s_interestRate = 5e10;
    mapping(address => uint256) private s_userInterestRate;
    mapping(address => uint256) private s_userLastUpdatedTimestamp;

    event InterestRateSet(uint256 newInterestRate);

    constructor() ERC20("Rebase Token", "RBT") {
        //
    }

    /*
    * @notice This sets te new interest rate
    * @param _newInterestRate The new interest rate
    * @dev The interest rate can only decrease
    */
    function setInterestRate(uint256 _newInterestRate) external {
        // Set Interest rate
        if (_newInterestRate < s_interestRate) {
            revert RebaseToken__InterestRateCanOnlyDecrease(s_interestRate, _newInterestRate);
        }
        s_interestRate = _newInterestRate;
        emit InterestRateSet(_newInterestRate);
    }

    /*
    * @notice Mint the user tokens when they deposit into the vault
    * @param _to The user address to mint the tokens to
    * @param _amount The amount of tokens to mint to the user
    */
    function mint(address _to, uint256 _amount) external {
        _mintAccruedInterest(_to);
        s_userInterestRate[_to] = s_interestRate;
        _mint(_to, _amount);
    }

    /*
    * Calculte the balance for the user including the interest that has accumulated since the last update
    * (principle balance) + some interest that has accured
    * @param _user The user address to calculate the balance for
    * @return The balance of the user including the interest that has accumulated since the last update
    */
    function balanceOf(address _user) public view override returns (uint256) {
        // Get the current principle balance of the user
        // Multiply the principle balance by the interest thathas accumulated since the balnce was last updated
        return super.balanceOf(_user) * _calculateUserAccumulatedInterestSinceLastUpdate(_user) / PRECISION_FACTOR;
    }

    /*
    * @notice Calculate the interest that has accumulated since the last update
    * @param _user The user address to calculate the interest for
    * @return The interest that has accumulated since the last update
    */
    function _calculateUserAccumulatedInterestSinceLastUpdate(address _user)
        internal
        view
        returns (uint256 linearInterest)
    {
        // We need to calculate the interest since the last update
        // This is gong to be the linear growth with time
        // 1. Calculate the time since the last update
        // 2. Calculate the amount of linear growth
        uint256 timeElapsed = block.timestamp - s_userLastUpdatedTimestamp[_user];
        linearInterest = PRECISION_FACTOR + (s_userInterestRate[_user] * timeElapsed);
    }

    function _mintAccruedInterest(address _user) internal {
        // Find their current balance of rebaseTokens that have been minted to the user -> principleBalance
        // Calclate their current balance including any interest -> balanceOf
        // Calculate the number of tokens that need to be minted to the user -> (2) - (1)
        // Call _mint to mint the tokens to the user
        // Set the user last updated timestamp
        s_userLastUpdatedTimestamp[_user] = block.timestamp;
    }

    /*
    * @notice Get the interest rate for a user
    * @param _user The user address to the interest Rate for
    * @return The interest rate for the user
    */
    function getUserInterestRate(address _user) external view returns (uint256) {
        return s_userInterestRate[_user];
    }
}

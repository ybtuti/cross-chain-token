// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";

/**
 * @title RebaseToken
 * @author ybtuti
 * @notice This is a chroos chain token that incentivises users to deposit into a vault and gain interest.
 * @notice The Interest rate in the smart contract can only decrease
 * @notice Each user will have their own iterest rate ie the global interest rate at the time of depositing.
 */
contract RebaseToken is ERC20, Ownable, AccessControl {
    error RebaseToken__InterestRateCanOnlyDecrease(uint256 oldInterestRate, uint256 newInterestRate);

    uint256 private constant PRECISION_FACTOR = 1e18;
    bytes32 private constant MINT_AND_BURN_ROLE = keccak256("MINT_AND_BURN_ROLE");
    uint256 private s_interestRate = (5 * PRECISION_FACTOR) / 1e8;
    mapping(address => uint256) private s_userInterestRate;
    mapping(address => uint256) private s_userLastUpdatedTimestamp;

    event InterestRateSet(uint256 newInterestRate);

    constructor() ERC20("Rebase Token", "RBT") Ownable(msg.sender) {
        //
    }

    function grantMintAndBurnRole(address _account) external onlyOwner {
        _grantRole(MINT_AND_BURN_ROLE, _account);
    }

    /*
    * @notice This sets te new interest rate
    * @param _newInterestRate The new interest rate
    * @dev The interest rate can only decrease
    */
    function setInterestRate(uint256 _newInterestRate) external onlyOwner {
        // Set Interest rate
        if (_newInterestRate >= s_interestRate) {
            revert RebaseToken__InterestRateCanOnlyDecrease(s_interestRate, _newInterestRate);
        }
        s_interestRate = _newInterestRate;
        emit InterestRateSet(_newInterestRate);
    }

    /*
    * @notice Get the principle balance of the user. This is the number of tokens that have currently been minted to the user, not including any interest that has accrued since the last time the user interacted with the protocol.
    * @param _user The user address to get the principle balance for
    * @return The principle balance of the user
    */
    function principleBalanceOf(address _user) external view returns (uint256) {
        return super.balanceOf(_user);
    }

    /*
    * @notice Mint the user tokens when they deposit into the vault
    * @param _to The user address to mint the tokens to
    * @param _amount The amount of tokens to mint to the user
    */
    function mint(address _to, uint256 _amount) external onlyRole(MINT_AND_BURN_ROLE) {
        _mintAccruedInterest(_to);
        s_userInterestRate[_to] = s_interestRate;
        _mint(_to, _amount);
    }

    /*
    * @notice Burn the user tokens when they withdraw from the vault
    * @param _from The user address to burn the tokens from
    * @param _amount The amount of tokens to burn from the user
    */
    function burn(address _from, uint256 _amount) external onlyRole(MINT_AND_BURN_ROLE) {
        _mintAccruedInterest(_from);
        _burn(_from, _amount);
    }

    /*
    * Calculte the balance for the user including the interest that has accumulated since the last update
    * (principle balance) + some interest that has accured
    * @param _user The user address to calculate the balance for
    * @return The balance of the user including the interest that has accumulated since the last update
    */
    function balanceOf(address _user) public view override returns (uint256) {
        // Get the current principle balance of the user
        // Finish Rebase-token-contract the principle balance by the interest thathas accumulated since the balnce was last updated
        return super.balanceOf(_user) * _calculateUserAccumulatedInterestSinceLastUpdate(_user) / PRECISION_FACTOR;
    }

    /*
    * @notice Transfer tokens from one user to another
    * @param _recipient The user address to transfer the tokens to
    * @param _amount The amount of tokens to transfer
    * @return True if the transfer was successful
    */
    function transfer(address _recipient, uint256 _amount) public override returns (bool) {
        _mintAccruedInterest(msg.sender);
        _mintAccruedInterest(_recipient);
        if (_amount == type(uint256).max) {
            _amount = balanceOf(msg.sender);
        }
        if (balanceOf(_recipient) == 0) {
            s_userInterestRate[_recipient] = s_userInterestRate[msg.sender];
        }
        return super.transfer(_recipient, _amount);
    }

    /**
     * @notice Transfer tokens from one user to another
     * @param _sender The user address to transfer the tokens from
     * @param _recipient The user address to transfer the tokens to
     * @param _amount The amount of tokens to transfer
     * @return True if the transfer was successful
     */
    function transferFrom(address _sender, address _recipient, uint256 _amount) public override returns (bool) {
        _mintAccruedInterest(_sender);
        _mintAccruedInterest(_recipient);
        if (_amount == type(uint256).max) {
            _amount = balanceOf(_sender);
        }
        if (balanceOf(_recipient) == 0) {
            s_userInterestRate[_recipient] = s_userInterestRate[_sender];
        }
        return super.transferFrom(_sender, _recipient, _amount);
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

    /*
    * @notice Mint the accrued interest to the user since the last time they interacted with the protocol
    * @param _user The user address to mint the accrued interest to
    */
    function _mintAccruedInterest(address _user) internal {
        // Find their current balance of rebaseTokens that have been minted to the user -> principleBalance
        uint256 previousPrincipleBalance = super.balanceOf(_user);
        // Calclate their current balance including any interest -> balanceOf
        uint256 currentBalance = balanceOf(_user);
        // Calculate the number of tokens that need to be minted to the user -> (2) - (1)
        uint256 balanceIncrease = currentBalance - previousPrincipleBalance;
        // Set the user last updated timestamp
        s_userLastUpdatedTimestamp[_user] = block.timestamp;
        // Call _mint to mint the tokens to the user
        _mint(_user, balanceIncrease);
    }
    /*
    * @notice Get the interest rate that is currently set for the contract any depositors will recieve this interest rate
    */

    function getInterestRate() external view returns (uint256) {
        return s_interestRate;
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

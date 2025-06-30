// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import "../lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import "../lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import "../lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import "../lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";

contract Presale is Ownable {
    using SafeERC20 for IERC20;

    address public USDT;
    address public USDC;
    address public fundsReceiver;

    uint public totalTokenSale;
    uint public startTime;
    uint public endTime;
    uint public currentPhase;

    uint[][3] public phases;

    mapping(address => bool) public isBlacklisted;

    constructor(address _USDT, address _USDC, address _fundsReceiver, uint _totalTokenSale, uint[][3] memory _phases, uint _startTime, uint _endTime) Ownable(msg.sender) {
        USDT = _USDT;
        USDC = _USDC;
        fundsReceiver = _fundsReceiver;
        totalTokenSale = _totalTokenSale;
        phases = _phases;
        startTime = _startTime;
        endTime = _endTime;

        require(endTime > startTime, "Incorrect presale duration");
    }

    /**
     * Adds an address to the blacklist
     * @param _address the address to blacklist
     */
    function blackList(address _address) external onlyOwner {
        require(!isBlacklisted[_address], "Already blacklisted.");
        isBlacklisted[_address] = true;
    }

    /**
     * Removes an address to the blacklist
     * @param _address the address to remove from the blacklist
     */
    function removeBlackList(address _address) external onlyOwner {
        require(isBlacklisted[_address], "IS not blacklisted.");
        isBlacklisted[_address] = false;
    }

    /**
     * Buys the presale token using USDT or USDC
     * @param _payingToken USDT or USDC
     * @param _payingAmount amount of usd to pay
     */
    function buyWithStable(address _payingToken, uint _payingAmount) external {
        require(!isBlacklisted[msg.sender], "Is blacklisted");
        require(block.timestamp >= startTime, "Presale is not live yet");
        require(block.timestamp <= endTime, "Presale ended");
        require(_payingToken == USDT || _payingToken == USDC, "Paying token not supported");

        uint amountToRecive;
        if (ERC20(_payingToken).decimals() == 18) {
            amountToRecive = (_payingAmount * 1e6) / phases[currentPhase][1];
        } else {
            amountToRecive = (_payingAmount * 10 ** (18 - ERC20(_payingToken).decimals()) * 1e6) / phases[currentPhase][1];
        }
    }

    /**
     * Withdraws an amount of ERC20 tokens from the contract, used to recover funds if required
     * @param _token ERC20 token address to withdraw
     * @param _amount amount of tokens to withdraw
     */
    function emergencyERC20Withdraw(address _token, uint _amount) external onlyOwner {
        IERC20(_token).safeTransfer(msg.sender, _amount);
    }

    /**
     * Withdraws all the native balance from the contract, used to recover funds if required
     */
    function emergencyNativeWithdraw() external onlyOwner {
        (bool success, ) = msg.sender.call{value: address(this).balance}("");
        require(success, "Transfer failed");
    }
}

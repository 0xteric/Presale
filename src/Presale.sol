// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import "../lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import "../lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import "../lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import "../lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import "./interfaces/IAggregator.sol";

contract Presale is Ownable {
    using SafeERC20 for IERC20;

    address public USDT;
    address public USDC;
    address public fundsReceiver;
    address public dataFeedAddress;
    address public saleTokenAddress;

    uint public totalTokenSale;
    uint public startTime;
    uint public endTime;
    uint public currentPhase;
    uint public totalSold;

    uint[][3] public phases;

    mapping(address => bool) public isBlacklisted;
    mapping(address => uint) public userBalance;

    event Buy(address user, uint amount);

    constructor(
        address _saleTokenAddress,
        address _USDT,
        address _USDC,
        address _fundsReceiver,
        address _dataFeedAddress,
        uint _totalTokenSale,
        uint[][3] memory _phases,
        uint _startTime,
        uint _endTime
    ) Ownable(msg.sender) {
        saleTokenAddress = _saleTokenAddress;
        USDT = _USDT;
        USDC = _USDC;
        fundsReceiver = _fundsReceiver;
        totalTokenSale = _totalTokenSale;
        phases = _phases;
        startTime = _startTime;
        endTime = _endTime;
        dataFeedAddress = _dataFeedAddress;

        require(endTime > startTime, "Incorrect presale duration");
    }

    function getEthPrice() public view returns (uint) {
        (, int256 price, , , ) = IAggregator(dataFeedAddress).latestRoundData();
        return uint(price * 1e10);
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

        managePhaseTimestamp();

        (uint amountToReceive, uint phase) = managePhaseCrossing(_payingAmount, _payingToken);

        currentPhase = phase;

        totalSold += amountToReceive;
        require(totalSold <= totalTokenSale, "Sold out!");
        userBalance[msg.sender] += amountToReceive;
        IERC20(_payingToken).safeTransferFrom(msg.sender, fundsReceiver, _payingAmount);

        emit Buy(msg.sender, _payingAmount);
    }

    /**
     * Buys the presale token using native currency
     */
    function buyWithNative() external payable {
        require(!isBlacklisted[msg.sender], "Is blacklisted");
        require(block.timestamp >= startTime, "Presale is not live yet");
        require(block.timestamp <= endTime, "Presale ended");

        managePhaseTimestamp();

        uint amountToPayInUsd = (msg.value * getEthPrice()) / 1e30;

        (uint amountToReceive, uint phase) = managePhaseCrossing(amountToPayInUsd, address(0));
        currentPhase = phase;

        totalSold += amountToReceive;
        require(totalSold <= totalTokenSale, "Sold out!");

        (bool success, ) = fundsReceiver.call{value: msg.value}("");
        require(success, "Transfer failed!");

        userBalance[msg.sender] += amountToReceive;

        emit Buy(msg.sender, amountToReceive);
    }

    /**
     * Claims the tokens bought
     */
    function claim() external {
        require(block.timestamp > endTime, "Presale is live");
        uint amount = userBalance[msg.sender];
        delete userBalance[msg.sender];

        IERC20(saleTokenAddress).safeTransfer(msg.sender, amount);
    }

    function managePhaseCrossing(uint _amountIn, address _tokenIn) public view returns (uint, uint) {
        uint8 tokenInDecimals = _tokenIn == address(0) ? 18 : ERC20(_tokenIn).decimals();

        uint remainingAmount = _amountIn;
        uint tokensToReceive = 0;
        uint tempTotalSold = totalSold;
        uint phase = currentPhase;

        while (remainingAmount > 0 && phase < 3) {
            uint tokensLeftInPhase = phases[phase][0] > tempTotalSold ? phases[phase][0] - tempTotalSold : 0;

            if (tokensLeftInPhase == 0) {
                phase++;
                tempTotalSold = 0;
                continue;
            }

            uint phasePrice = phases[phase][1];
            uint phaseValueUSD = (tokensLeftInPhase * phasePrice) / 1e18;

            if (remainingAmount <= phaseValueUSD) {
                tokensToReceive += (remainingAmount * 10 ** (18 - tokenInDecimals) * 1e6) / phasePrice;
                remainingAmount = 0;
            } else {
                tokensToReceive += (tokensLeftInPhase);
                remainingAmount -= phaseValueUSD;
                phase++;
            }
        }

        require(remainingAmount == 0, "Not enough tokens in presale phases");

        return (tokensToReceive, phase);
    }

    function managePhaseTimestamp() public {
        if (block.timestamp >= phases[currentPhase][2] && currentPhase < 3) {
            currentPhase++;
        }
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

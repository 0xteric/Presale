// SPDX License-Identifier: MIT

pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../src/Presale.sol";
import "../src/MockToken.sol";

contract PresaleTest is Test {
    address deployer = vm.addr(2);
    address user = 0x0b07f64ABc342B68AEc57c0936E4B6fD4452967E;
    address user2 = vm.addr(1);
    address USDC = 0xaf88d065e77c8cC2239327C5EDb3A432268e5831;
    address USDT = 0xFd086bC7CD5C481DCC9C85ebE478A1C0b69FCbb9;
    address dataFeedAddress = 0x639Fe6ab55C921f74e7fac1ee960C0B6293ba612;

    uint256[][3] phases;

    MockToken mockToken;

    Presale presale;

    function setUp() public {
        vm.startPrank(deployer);

        phases[0] = [333_333_334 * 1e18, 3000, block.timestamp + 1 days];
        phases[1] = [666_666_667 * 1e18, 4000, block.timestamp + 1 days];
        phases[2] = [1_000_000_000 * 1e18, 5000, block.timestamp + 1 days];

        mockToken = new MockToken();

        mockToken.mint(deployer, 1_000_000_000 * 1e18);

        presale = new Presale(
            address(mockToken),
            USDT,
            USDC,
            0x0b07f64ABc342B68AEc57c0936E4B6fD4452967E,
            dataFeedAddress,
            1_000_000_000 * 1e18,
            phases,
            block.timestamp,
            block.timestamp + 4 days
        );
        // mockToken.approve(address(presale), 1_000_000_000 * 1e18);
        mockToken.transfer(address(presale), 1_000_000_000 * 1e18);

        vm.stopPrank();
    }

    function testDeployedCorrectly() public {
        uint deployerBalance = mockToken.balanceOf(deployer);
        uint presaleBalance = mockToken.balanceOf(address(presale));

        assertEq(deployerBalance, 0);
        assertEq(presaleBalance, 1_000_000_000 * 1e18);
    }

    function testBuyWithStableBasic() public {
        vm.startPrank(user);

        address tokenToPay = USDC;
        uint amountToPay = 1_000 * 1e6;

        (uint amountToReceive, uint phase) = presale.managePhaseCrossing(amountToPay, tokenToPay);

        IERC20(tokenToPay).approve(address(presale), amountToPay);

        presale.buyWithStable(tokenToPay, amountToPay);

        uint userBalance = presale.userBalance(user);

        assertEq(userBalance, amountToReceive);
        vm.stopPrank();
    }

    function testBuyWithStablePhaseCrossing() public {
        vm.startPrank(user);

        address tokenToPay = USDC;
        uint amountToPay = 3_000_000 * 1e6;

        (uint amountToReceive, uint phase) = presale.managePhaseCrossing(amountToPay, tokenToPay);

        IERC20(tokenToPay).approve(address(presale), amountToPay);

        presale.buyWithStable(tokenToPay, amountToPay);

        uint userBalance = presale.userBalance(user);

        assertEq(amountToReceive, userBalance);
        assertEq(phase, presale.currentPhase());
        vm.stopPrank();
    }

    function testBuyWithStableFullPhase() public {
        vm.startPrank(user);

        address tokenToPay = USDC;
        uint amountToPay = 1_000_000_002 * 1e3;

        (uint amountToReceive, uint phase) = presale.managePhaseCrossing(amountToPay, tokenToPay);

        IERC20(tokenToPay).approve(address(presale), amountToPay);

        presale.buyWithStable(tokenToPay, amountToPay);

        uint userBalance = presale.userBalance(user);

        assertEq(amountToReceive, phases[0][0]);
        assertEq(amountToReceive, userBalance);
        vm.stopPrank();
    }

    function testBuyWithNative() public {
        vm.startPrank(user);
        vm.deal(user, 10 ether);

        uint amountToPay = 10 ether;
        uint amountToPayInUsd = (presale.getEthPrice() * amountToPay) / 1e30;

        (uint amountToReceive, uint phase) = presale.managePhaseCrossing(amountToPayInUsd, address(0));

        presale.buyWithNative{value: amountToPay}();

        uint userBalance = presale.userBalance(user);

        assertEq(amountToReceive, userBalance);
        assertEq(presale.currentPhase(), phase);
        vm.stopPrank();
    }

    function testBuyWithNativePhaseCrossing() public {
        vm.startPrank(user);
        vm.deal(user, 1000 ether);

        uint amountToPay = 1000 ether;
        uint amountToPayInUsd = (presale.getEthPrice() * amountToPay) / 1e30;

        (uint amountToReceive, uint phase) = presale.managePhaseCrossing(amountToPayInUsd, address(0));

        presale.buyWithNative{value: amountToPay}();

        uint userBalance = presale.userBalance(user);

        assertEq(amountToReceive, userBalance);
        assertEq(presale.currentPhase(), phase);
        vm.stopPrank();
    }

    function testBuyExceedsPresale() public {
        vm.startPrank(user);
        vm.deal(user, 2000 ether);

        vm.expectRevert("Not enough tokens in presale phases");
        presale.buyWithNative{value: 2000 ether}();
        vm.stopPrank();
    }

    function testClaimTokens() public {
        vm.startPrank(user);

        uint amountToBuy = 100_000 * 1e6;

        IERC20(USDC).approve(address(presale), amountToBuy);

        presale.buyWithStable(USDC, amountToBuy);

        uint presaleBalanceBefore = presale.userBalance(user);
        uint tokenBalanceBefore = IERC20(address(mockToken)).balanceOf(user);

        vm.warp(block.timestamp + 5 days);

        presale.claim();

        uint presaleBalanceAfter = presale.userBalance(user);
        uint tokenBalanceAfter = IERC20(address(mockToken)).balanceOf(user);

        assertEq(presaleBalanceAfter, tokenBalanceBefore);
        assertEq(presaleBalanceBefore, tokenBalanceAfter);
        vm.stopPrank();
    }

    function testClaimBeforeTime() public {
        vm.startPrank(user);

        uint amountToBuy = 100_000 * 1e6;

        IERC20(USDC).approve(address(presale), amountToBuy);

        presale.buyWithStable(USDC, amountToBuy);

        vm.warp(block.timestamp + 3 days);

        vm.expectRevert("Presale is live");
        presale.claim();
        vm.stopPrank();
    }

    function testAddToBlackList() public {
        vm.startPrank(deployer);

        presale.blackList(user2);

        bool blacklisted = presale.isBlacklisted(user2);

        assertTrue(blacklisted);

        vm.stopPrank();
    }

    function testAddToBlackListDouble() public {
        vm.startPrank(deployer);

        presale.blackList(user2);

        bool blacklisted = presale.isBlacklisted(user2);

        assertTrue(blacklisted);

        vm.expectRevert("Already blacklisted.");
        presale.blackList(user2);

        vm.stopPrank();
    }

    function testRemoveFromBlackList() public {
        vm.startPrank(deployer);

        presale.blackList(user2);

        bool blacklisted = presale.isBlacklisted(user2);

        assertTrue(blacklisted);

        presale.removeBlackList(user2);

        bool blacklisted2 = presale.isBlacklisted(user2);

        assertTrue(!blacklisted2);
    }

    function testRemoveFromBlackListNotBlacklisted() public {
        vm.startPrank(deployer);

        vm.expectRevert("Not blacklisted.");
        presale.removeBlackList(user2);
    }

    function testEmergencyERC20Withdraw() public {
        vm.startPrank(deployer);

        uint amountToWithdraw = 1_000_000 * 1e18;
        address tokenToWithdraw = address(mockToken);

        uint presaleBalanceBefore = IERC20(tokenToWithdraw).balanceOf(address(presale));

        presale.emergencyERC20Withdraw(tokenToWithdraw, amountToWithdraw);

        uint presaleBalanceAfter = IERC20(tokenToWithdraw).balanceOf(address(presale));

        assertEq(presaleBalanceAfter, presaleBalanceBefore - amountToWithdraw);
    }

    function testEmergencyETHWithdraw() public {
        vm.startPrank(deployer);

        uint amountToWithdraw = 90 ether;

        vm.deal(deployer, 101 ether);

        (bool success, ) = address(presale).call{value: 100 ether}("");
        require(success, "Transfer failed!!");

        uint balanceBefore = address(presale).balance;

        presale.emergencyNativeWithdraw(amountToWithdraw);

        uint balanceAfter = address(presale).balance;

        assertEq(balanceAfter, balanceBefore - amountToWithdraw);
    }
}

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

        phases[0] = [333333334 * 1e18, 3000, block.timestamp + 1 days];
        phases[1] = [666666667 * 1e18, 4000, block.timestamp + 1 days];
        phases[2] = [1000000000 * 1e18, 5000, block.timestamp + 1 days];

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
    }

    function testBuyWithStablePhaseCrossing() public {
        vm.startPrank(user);

        address tokenToPay = USDC;
        uint amountToPay = 1_100_000 * 1e6;

        (uint amountToReceive, uint phase) = presale.managePhaseCrossing(amountToPay, tokenToPay);

        IERC20(tokenToPay).approve(address(presale), amountToPay);

        presale.buyWithStable(tokenToPay, amountToPay);

        uint userBalance = presale.userBalance(user);

        assertEq(amountToReceive, userBalance);
        assertEq(phase, 1);
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
    }

    function testBuyWithNative() public {
        vm.startPrank(user);
        vm.deal(user, 100 ether);

        uint amountToPay = 10 ether;
        uint amountToPayInUsd = (presale.getEthPrice() * amountToPay) / 1e30;

        (uint amountToReceive, uint phase) = presale.managePhaseCrossing(amountToPayInUsd, address(0));

        presale.buyWithNative{value: amountToPay}();

        uint userBalance = presale.userBalance(user);

        assertEq(amountToReceive, userBalance);
    }

    function testBlackList() public {
        presale.blackList(user2);

        bool blacklisted = presale.isBlacklisted(user2);

        assertTrue(blacklisted);
    }
}

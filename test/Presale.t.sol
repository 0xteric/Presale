// SPDX License-Identifier: MIT

pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../src/Presale.sol";

contract PresaleTest is Test {
    address user = 0x0b07f64ABc342B68AEc57c0936E4B6fD4452967E;
    address user2 = vm.addr(1);
    address USDC = 0xaf88d065e77c8cC2239327C5EDb3A432268e5831;
    address USDT = 0xFd086bC7CD5C481DCC9C85ebE478A1C0b69FCbb9;

    Presale presale;

    function setUp() public {
        uint[][3] memory phases;
        for (uint i = 0; i < 3; i++) {
            phases[i] = new uint[](3);
        }
        phases[0][0] = 333_333_333;
        phases[0][1] = 1e6;
        phases[0][2] = block.timestamp + 1 days;
        phases[1][0] = 333_333_333;
        phases[1][1] = 2e6;
        phases[1][2] = block.timestamp + 2 days;
        phases[2][0] = 333_333_333;
        phases[2][1] = 3e6;
        phases[2][2] = block.timestamp + 3 days;

        presale = new Presale(USDT, USDC, 0x0b07f64ABc342B68AEc57c0936E4B6fD4452967E, 1_000_000_000, phases, block.timestamp, block.timestamp + 4 days);
    }

    function testBlackList() public {
        presale.blackList(user2);

        bool blacklisted = presale.isBlacklisted(user2);

        assertTrue(blacklisted);
    }
}

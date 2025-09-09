// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {Test, console} from "forge-std/Test.sol";
import {DeployOurToken} from "../script/DeployOurToken.s.sol";
import {OurToken} from "../src/OurToken.sol";

contract OurTokenTest is Test {
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    OurToken public ourToken;
    DeployOurToken public deployer;

    address bob = makeAddr("bob");
    address alice = makeAddr("alice");
    address eve = makeAddr("eve");

    uint256 public constant STARTING_BALANCE = 100 ether;
    uint256 public constant TOTAL_SUPPLY = 1000 ether;

    function setUp() public {
        deployer = new DeployOurToken();
        ourToken = deployer.run();

        vm.prank(msg.sender);
        ourToken.transfer(bob, STARTING_BALANCE);
    }

    function testBobBalance() public view {
        assertEq(STARTING_BALANCE, ourToken.balanceOf(bob));
    }

    function testAllowancesWorks() public {
        uint256 initialAllowance = 1000;

        // Bob approves Alice to spend token on his behalf
        vm.prank(bob);
        ourToken.approve(alice, initialAllowance);

        uint256 transferAmount = 500;

        vm.prank(alice);
        ourToken.transferFrom(bob, alice, transferAmount);

        assertEq(ourToken.balanceOf(alice), transferAmount);
        assertEq(ourToken.balanceOf(bob), STARTING_BALANCE - transferAmount);
    }

    // AI written test
    // -------- Basic Supply --------
    function testTotalSupply() public view {
        assertEq(ourToken.totalSupply(), TOTAL_SUPPLY);
    }

    function testDeployerGetsInitialSupply() public view {
        uint256 deployerBalance = ourToken.balanceOf(msg.sender);
        assertEq(deployerBalance, TOTAL_SUPPLY - STARTING_BALANCE);
    }

    // -------- Transfers --------
    function testTransferWorks() public {
        vm.prank(bob);
        ourToken.transfer(alice, 10 ether);

        assertEq(ourToken.balanceOf(alice), 10 ether);
        assertEq(ourToken.balanceOf(bob), STARTING_BALANCE - 10 ether);
    }

    function testTransferFailsIfInsufficientBalance() public {
        vm.prank(alice); // Alice has 0 initially
        vm.expectRevert();
        ourToken.transfer(bob, 1 ether);
    }

    function testTransferEmitsEvent() public {
        vm.prank(bob);
        vm.expectEmit(true, true, false, true);
        emit Transfer(bob, alice, 1 ether);
        ourToken.transfer(alice, 1 ether);
    }

    function testTransferZeroTokens() public {
        vm.prank(bob);
        ourToken.transfer(alice, 0);
        assertEq(ourToken.balanceOf(alice), 0);
        assertEq(ourToken.balanceOf(bob), STARTING_BALANCE);
    }

    // -------- Allowances --------
    function testApproveAllowance() public {
        vm.prank(bob);
        vm.expectEmit(true, true, false, true);
        emit Approval(bob, alice, 500);
        ourToken.approve(alice, 500);

        assertEq(ourToken.allowance(bob, alice), 500);
    }

    

    function testTransferFromWorks() public {
        uint256 initialAllowance = 100;
        vm.prank(bob);
        ourToken.approve(alice, initialAllowance);

        vm.prank(alice);
        ourToken.transferFrom(bob, eve, 50);

        assertEq(ourToken.balanceOf(eve), 50);
        assertEq(ourToken.balanceOf(bob), STARTING_BALANCE - 50);
        assertEq(ourToken.allowance(bob, alice), initialAllowance - 50);
    }

    function testTransferFromFailsWithoutEnoughAllowance() public {
        vm.prank(bob);
        ourToken.approve(alice, 10);

        vm.prank(alice);
        vm.expectRevert();
        ourToken.transferFrom(bob, eve, 50);
    }

    function testApproveZeroOverwrites() public {
        vm.prank(bob);
        ourToken.approve(alice, 200);
        vm.prank(bob);
        ourToken.approve(alice, 0);
        assertEq(ourToken.allowance(bob, alice), 0);
    }

    // -------- Edge Cases --------
    function testCannotTransferToZeroAddress() public {
        vm.prank(bob);
        vm.expectRevert();
        ourToken.transfer(address(0), 1 ether);
    }

    function testCannotApproveZeroAddress() public {
        vm.prank(bob);
        vm.expectRevert();
        ourToken.approve(address(0), 100);
    }

}
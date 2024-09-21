// SPDX-License-Identifier: Mitchell

pragma solidity ^0.8.25;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Test, console} from "forge-std/Test.sol";
import {DeployDigitalP2P} from "../../script/DeployDigitalP2P.s.sol";
import {DigitalP2P} from "../../src/DigitalP2P.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import {DigitalP2P_NotOwner, DigitalP2P_InvalidAddress, DigitalP2P_InvalidAmount, DigitalP2P_AmountShouldBeGreaterThanZero, DigitalP2P_AmountShouldBeGreaterThanMinimumAmount, DigitalP2P_AmountShouldBeLessThanMaximumAmount, DigitalP2P_TransferNotProccessed, DigitalP2P_InvalidOrderId, DigitalP2P_OrderAlreadyExists, DigitalP2P_InvalidOrderStatus, DigitalP2P_UserIsNotAllowedToReleaseFunds, DigitalP2P_OrderDoesNotExist, DigitalP2P_AmountExpectedDoesNotMatch, DigitalP2P_AdminAddressAlreadyExists} from "../../src/DigitalP2P.sol";

contract DigitalP2PTest is Test {
    DigitalP2P digitalP2P;
    DeployDigitalP2P deployDigitalP2P;
    ERC20Mock usdtToken;
    uint256 constant AMOUNT_USDT_TOKEN_TO_MINT = 1000;
    uint256 constant minimumAmount = 1;
    uint256 constant maximumAmount = 500;
    uint256 constant USDT_DECIMAL_PLACES = 1e6;
    uint256 constant STARTING_BALANCE = 1 ether;
    string constant ORDER_ID = "f47ac10b-58cc-4372-a567-0e02b2c3d479";
    address USER = makeAddr("user");
    address SELLER = makeAddr("seller");
    address BUYER = makeAddr("seller");

    function setUp() external {
        deployDigitalP2P = new DeployDigitalP2P();
        digitalP2P = deployDigitalP2P.run();
        usdtToken = ERC20Mock(address(digitalP2P.usdtToken()));
        usdtToken.mint(USER, AMOUNT_USDT_TOKEN_TO_MINT * USDT_DECIMAL_PLACES);
        usdtToken.mint(SELLER, AMOUNT_USDT_TOKEN_TO_MINT * USDT_DECIMAL_PLACES);
        vm.deal(USER, STARTING_BALANCE);
    }

    function testOwner() public view {
        assertEq(digitalP2P.getOwner(), msg.sender);
    }

    function testChangeOwner() public {
        vm.prank(msg.sender);
        digitalP2P.changeOwner(USER);
        assertEq(digitalP2P.getOwner(), USER);
    }

    function testChangeOwnerIsNotOwner() public {
        vm.expectRevert();
        digitalP2P.changeOwner(USER);
    }

    function testChangeOwnerInvalidAddress() public {
        vm.expectRevert();
        digitalP2P.changeOwner(address(0));
    }

    function testSetMinimumAmount() public {
        vm.prank(msg.sender);
        digitalP2P.setMinimumAmount(2);
        assertEq(digitalP2P.getMinimumAmount(), 2e6);
    }

    function testSetMinimumAmountNotOwner() public {
        vm.expectRevert();
        digitalP2P.setMinimumAmount(2);
    }

    function testSetMinimumInvalidAmount() public {
        vm.expectRevert();
        digitalP2P.setMinimumAmount(0);
    }

    function testSetMaximumAmount() public {
        uint256 newAmount = 50;
        vm.prank(msg.sender);
        digitalP2P.setMaximumAmount(newAmount);
        console.log("maxinum amount", digitalP2P.getMaximumAmount());
        assertEq(
            digitalP2P.getMaximumAmount(),
            newAmount * USDT_DECIMAL_PLACES
        );
    }

    function testSetMaximumAmountNotOwner() public {
        uint256 newAmount = 50;
        vm.expectRevert();
        digitalP2P.setMaximumAmount(newAmount);
    }

    function testRevertMinimumAmountIsGreatherThanMaxinumAmount() public {
        vm.prank(msg.sender);
        uint256 newAmount = 5;
        digitalP2P.setMinimumAmount(10);
        vm.expectRevert();
        digitalP2P.setMaximumAmount(newAmount);
    }

    function testGetMinimumAmount() public view {
        assertEq(
            digitalP2P.getMinimumAmount(),
            minimumAmount * USDT_DECIMAL_PLACES
        );
    }

    function testGetMaximumAmount() public view {
        assertEq(
            digitalP2P.getMaximumAmount(),
            maximumAmount * USDT_DECIMAL_PLACES
        );
    }

    function testGetBalance() public {
        vm.prank(msg.sender);
        (bool success, ) = address(digitalP2P).call{value: STARTING_BALANCE}(
            ""
        );
        assert(success);
        assertEq(digitalP2P.getBalance(), STARTING_BALANCE);
    }

    function testProcessOrderAmountShouldBeGreaterThanZero() public {
        vm.expectRevert();
        digitalP2P.processOrder("0", address(0), 0, 0);
    }

    function testProcessOrderAmountShouldBeGreatherThanMinimumAmount() public {
        vm.prank(msg.sender);
        digitalP2P.setMinimumAmount(10);
        vm.expectRevert();
        digitalP2P.processOrder("0", address(0), 5, 5);
    }

    function testProcessOrderAmounShouldBeLessThanMaximumAmount() public {
        vm.prank(msg.sender);
        digitalP2P.setMaximumAmount(10);
        vm.expectRevert();
        digitalP2P.processOrder("0", address(0), 15, 15);
    }

    function testProcessOrderInvalidOrderId() public {
        vm.prank(msg.sender);
        vm.expectRevert();
        digitalP2P.processOrder("282828282-28282828", address(0), 15, 15);
    }

    function testProcessOrderInvalidSellerAddress() public {
        vm.prank(msg.sender);
        vm.expectRevert();
        digitalP2P.processOrder(
            "f47ac10b-58cc-4372-a567-0e02b2c3d479",
            address(0),
            15,
            15
        );
    }

    function testProcessOrderOrderCreated() public {
        uint256 amount = 5;
        vm.startPrank(SELLER);
        usdtToken.approve(address(digitalP2P), amount * USDT_DECIMAL_PLACES);
        digitalP2P.processOrder(ORDER_ID, SELLER, amount, amount);
        vm.stopPrank();
        DigitalP2P.Order memory orderCreated = digitalP2P.getOrder(ORDER_ID);
        assertEq(orderCreated.buyer, SELLER);
        assertEq(orderCreated.seller, SELLER);
        assertEq(orderCreated.cryptoAmount, amount * USDT_DECIMAL_PLACES);
        assertEq(
            uint256(orderCreated.status),
            uint256(DigitalP2P.orderStatus.Pending)
        );
    }

    function testProcessOrderEventEmitsOrderCreatedWithIndexes() public {
        uint256 amount = 5;
        vm.prank(SELLER);
        usdtToken.approve(address(digitalP2P), amount * USDT_DECIMAL_PLACES);
        vm.expectEmit(true, true, false, false);
        emit DigitalP2P.orderCreated(
            ORDER_ID,
            DigitalP2P.orderStatus.Pending,
            msg.sender,
            SELLER,
            amount * USDT_DECIMAL_PLACES
        );
        vm.prank(msg.sender);
        digitalP2P.processOrder(ORDER_ID, SELLER, amount, amount);
    }

    function testProcessOrderEventEmitsOrderCreatedNonIndexes() public {
        uint256 amount = 5;
        vm.prank(SELLER);
        usdtToken.approve(address(digitalP2P), amount * USDT_DECIMAL_PLACES);
        vm.expectEmit(false, false, true, true);
        emit DigitalP2P.orderCreated(
            ORDER_ID,
            DigitalP2P.orderStatus.Pending,
            msg.sender,
            SELLER,
            amount * USDT_DECIMAL_PLACES
        );
        vm.prank(msg.sender);
        digitalP2P.processOrder(ORDER_ID, SELLER, amount, amount);
    }

    function testProcessOrderOrderAlreadyExists() public {
        uint256 amount = 5;
        vm.prank(SELLER);
        usdtToken.approve(address(digitalP2P), amount * USDT_DECIMAL_PLACES);
        digitalP2P.processOrder(ORDER_ID, SELLER, amount, amount);
        vm.expectRevert();
        digitalP2P.processOrder(ORDER_ID, SELLER, amount, amount);
    }

    function testProcessOrderPriceMisMatch() public {
        uint256 amount = 5;
        vm.prank(SELLER);
        usdtToken.approve(address(digitalP2P), amount * USDT_DECIMAL_PLACES);
        vm.expectRevert(DigitalP2P_AmountExpectedDoesNotMatch.selector);
        digitalP2P.processOrder(ORDER_ID, SELLER, amount, amount + 1);
    }

    function testProcessOrderGetUsdtBalance() public {
        uint256 amount = 5 * USDT_DECIMAL_PLACES;
        vm.prank(SELLER);
        usdtToken.approve(address(digitalP2P), amount);
        digitalP2P.processOrder(ORDER_ID, SELLER, 5, 5);
        digitalP2P.getOrder(ORDER_ID);
        uint256 balance = digitalP2P.getUSDTBalance();
        assertEq(balance, amount);
    }

    function testGetUserUsdtBalance() public {
        vm.prank(SELLER);
        uint256 userBalance = digitalP2P.getUserBalance(SELLER);
        assertEq(userBalance, AMOUNT_USDT_TOKEN_TO_MINT * USDT_DECIMAL_PLACES);
    }

    function testContractUsdtBalance() public {
        uint256 amount = 5 * USDT_DECIMAL_PLACES;
        vm.prank(SELLER);
        usdtToken.approve(address(digitalP2P), amount);
        vm.prank(address(digitalP2P));
        usdtToken.transferFrom(SELLER, address(digitalP2P), amount);
        uint256 contractBalance = digitalP2P.getUSDTBalance();
        console.log("contract", contractBalance);
        assertEq(contractBalance, amount);
    }

    function testUserGetAllowance() public {
        uint256 amount = 5 * USDT_DECIMAL_PLACES;
        vm.prank(SELLER);
        usdtToken.approve(address(digitalP2P), amount);
        uint256 userUsdtBalance = digitalP2P.getUserAllowance(SELLER);
        assertEq(userUsdtBalance, amount);
    }

    function testReleaseFundsShouldBeOwner() public {
        vm.expectRevert();
        vm.prank(USER);
        digitalP2P.releaseOrder(ORDER_ID);
    }

    function testReleaseFundsOrderDoesNotExist() public {
        vm.expectRevert(DigitalP2P_OrderDoesNotExist.selector);
        vm.prank(msg.sender);
        digitalP2P.releaseOrder("f47ac10b-58cc-4372-a567-0e02b2c3d478");
    }

    function testReleaseFundsInvalidOrderUUID() public {
        vm.expectRevert(DigitalP2P_InvalidOrderId.selector);
        vm.prank(msg.sender);
        digitalP2P.releaseOrder("f47ac10b-58c");
    }

    function testReleaseFundsInvalidStatus() public {
        uint256 amount = 5;
        vm.prank(SELLER);
        usdtToken.approve(address(digitalP2P), amount * USDT_DECIMAL_PLACES);
        vm.prank(msg.sender);
        digitalP2P.processOrder(ORDER_ID, SELLER, amount, amount);
        vm.prank(msg.sender);
        digitalP2P.updateOrderStatus(ORDER_ID, DigitalP2P.orderStatus.Fraud);
        vm.expectRevert(DigitalP2P_InvalidOrderStatus.selector);
        vm.prank(msg.sender);
        digitalP2P.releaseOrder(ORDER_ID);
    }

    function testReleaseFundsUserIsNotAllowedToReleaseFunds() public {
        uint256 amount = 5;
        vm.prank(SELLER);
        usdtToken.approve(address(digitalP2P), amount * USDT_DECIMAL_PLACES);
        vm.prank(msg.sender);
        digitalP2P.processOrder(ORDER_ID, SELLER, amount, amount);
        vm.prank(msg.sender);
        vm.expectRevert(DigitalP2P_UserIsNotAllowedToReleaseFunds.selector);
        digitalP2P.releaseOrder(ORDER_ID);
    }

    function testReleaseFundsSuccess() public {
        uint256 amount = 5;
        usdtToken.mint(
            msg.sender,
            AMOUNT_USDT_TOKEN_TO_MINT * USDT_DECIMAL_PLACES
        );
        vm.prank(msg.sender);
        usdtToken.approve(address(digitalP2P), amount * USDT_DECIMAL_PLACES);
        digitalP2P.processOrder(ORDER_ID, msg.sender, amount, amount);
        vm.prank(msg.sender);
        digitalP2P.releaseOrder(ORDER_ID);
        uint256 buyerBalance = digitalP2P.getUserBalance(msg.sender);
        assertEq(
            buyerBalance + amount * USDT_DECIMAL_PLACES,
            AMOUNT_USDT_TOKEN_TO_MINT * USDT_DECIMAL_PLACES
        );
    }

    function testReleaseFundsEventEmitOrderReleaseWithIndexes() public {
        uint256 amount = 5;
        usdtToken.mint(
            msg.sender,
            AMOUNT_USDT_TOKEN_TO_MINT * USDT_DECIMAL_PLACES
        );
        vm.prank(SELLER);
        usdtToken.approve(address(digitalP2P), amount * USDT_DECIMAL_PLACES);
        vm.prank(msg.sender);
        digitalP2P.processOrder(ORDER_ID, SELLER, amount, amount);
        vm.prank(msg.sender);
        digitalP2P.addAdmin(SELLER);
        vm.expectEmit(true, true, true, false);
        emit DigitalP2P.orderReleased(
            ORDER_ID,
            SELLER,
            msg.sender,
            amount * USDT_DECIMAL_PLACES
        );
        vm.prank(SELLER);
        digitalP2P.releaseOrder(ORDER_ID);
    }

    function testReleaseFundsEventEmitOrderReleaseNonIndexes() public {
        uint256 amount = 5;
        usdtToken.mint(
            msg.sender,
            AMOUNT_USDT_TOKEN_TO_MINT * USDT_DECIMAL_PLACES
        );
        vm.prank(SELLER);
        usdtToken.approve(address(digitalP2P), amount * USDT_DECIMAL_PLACES);
        vm.prank(msg.sender);
        digitalP2P.processOrder(ORDER_ID, SELLER, amount, amount);
        vm.prank(msg.sender);
        digitalP2P.addAdmin(SELLER);
        vm.expectEmit(false, false, false, true);
        emit DigitalP2P.orderReleased(
            ORDER_ID,
            SELLER,
            msg.sender,
            amount * USDT_DECIMAL_PLACES
        );
        vm.prank(SELLER);
        digitalP2P.releaseOrder(ORDER_ID);
    }

    function testReleaseFundsSuccessRemoveOrder() public {
        uint256 amount = 5;
        usdtToken.mint(
            msg.sender,
            AMOUNT_USDT_TOKEN_TO_MINT * USDT_DECIMAL_PLACES
        );
        vm.prank(msg.sender);
        usdtToken.approve(address(digitalP2P), amount * USDT_DECIMAL_PLACES);
        digitalP2P.processOrder(ORDER_ID, msg.sender, amount, amount);
        vm.prank(msg.sender);
        digitalP2P.releaseOrder(ORDER_ID);
        DigitalP2P.Order memory order = digitalP2P.getOrder(ORDER_ID);
        assertEq(bytes(order.id).length, 0);
    }

    function testUpdateStatusInvalidUUID() public {
        vm.expectRevert(DigitalP2P_InvalidOrderId.selector);
        vm.prank(msg.sender);
        digitalP2P.updateOrderStatus(
            "f47ac10b-58c",
            DigitalP2P.orderStatus.Fraud
        );
    }

    function testUpdateStatusOrdesDoesNotExist() public {
        vm.expectRevert(DigitalP2P_OrderDoesNotExist.selector);
        vm.prank(msg.sender);
        digitalP2P.updateOrderStatus(ORDER_ID, DigitalP2P.orderStatus.Fraud);
    }

    function testUpdateStatusSuccess() public {
        uint256 amount = 5;
        vm.prank(SELLER);
        usdtToken.approve(address(digitalP2P), amount * USDT_DECIMAL_PLACES);
        digitalP2P.processOrder(ORDER_ID, SELLER, amount, amount);
        vm.prank(msg.sender);
        digitalP2P.updateOrderStatus(ORDER_ID, DigitalP2P.orderStatus.Fraud);
        DigitalP2P.Order memory order = digitalP2P.getOrder(ORDER_ID);
        assertEq(uint256(order.status), uint256(DigitalP2P.orderStatus.Fraud));
    }

    function testUpdateStatusEventEmitChangeStatusWithIndexes() public {
        uint256 amount = 5;
        vm.prank(SELLER);
        usdtToken.approve(address(digitalP2P), amount * USDT_DECIMAL_PLACES);
        digitalP2P.processOrder(ORDER_ID, SELLER, amount, amount);
        vm.expectEmit(true, true, true, false);
        emit DigitalP2P.orderChangeStatus(
            ORDER_ID,
            msg.sender,
            string(abi.encodePacked("from", DigitalP2P.orderStatus.Pending, " to ", DigitalP2P.orderStatus.PriceMismatch)),
            DigitalP2P.orderStatus.Pending,
            DigitalP2P.orderStatus.PriceMismatch
        );
        vm.prank(msg.sender);
        digitalP2P.updateOrderStatus(ORDER_ID, DigitalP2P.orderStatus.PriceMismatch);
    }

    function testUpdateStatusEventEmitChangeStatusNonIndexes() public {
        uint256 amount = 5;
        vm.prank(SELLER);
        usdtToken.approve(address(digitalP2P), amount * USDT_DECIMAL_PLACES);
        digitalP2P.processOrder(ORDER_ID, SELLER, amount, amount);
        vm.expectEmit(false, false, false, true);
        emit DigitalP2P.orderChangeStatus(
            ORDER_ID,
            msg.sender,
            string(abi.encodePacked("from", DigitalP2P.orderStatus.Pending, " to ", DigitalP2P.orderStatus.PriceMismatch)),
            DigitalP2P.orderStatus.Pending,
            DigitalP2P.orderStatus.PriceMismatch
        );
        vm.prank(msg.sender);
        digitalP2P.updateOrderStatus(ORDER_ID, DigitalP2P.orderStatus.PriceMismatch);
    }

    function testAddAdminShouldBeOwner() public {
        vm.expectRevert();
        digitalP2P.addAdmin(USER);
    }

    function testAddAdminInvalidAddress() public {
        vm.prank(msg.sender);
        vm.expectRevert(DigitalP2P_InvalidAddress.selector);
        digitalP2P.addAdmin(address(0));
    }

    function testAddAdminSuccess() public {
        address admin = makeAddr("admin");
        vm.prank(msg.sender);
        digitalP2P.addAdmin(admin);
        address expectedAdmin = digitalP2P.getAdmin(admin);
        assertEq(admin, expectedAdmin);
    }

    function testAddAdminAdminAlreadyExists() public {
        address admin = makeAddr("admin");
        vm.prank(msg.sender);
        digitalP2P.addAdmin(admin);
        vm.expectRevert(DigitalP2P_AdminAddressAlreadyExists.selector);
        vm.prank(msg.sender);
        digitalP2P.addAdmin(admin);
    }

    function testRemoveAdminShouldBeOwner() public {
        vm.expectRevert();
        digitalP2P.removeAdmin(USER);
    }

    function testRemoveAdminInvalidAddress() public {
        vm.prank(msg.sender);
        vm.expectRevert(DigitalP2P_InvalidAddress.selector);
        digitalP2P.removeAdmin(address(0));
    }

    function testRemoveAdminSuccess() public {
        address admin = makeAddr("admin");
        vm.prank(msg.sender);
        digitalP2P.addAdmin(admin);
        vm.prank(msg.sender);
        digitalP2P.removeAdmin(admin);
        address expectedAdmin = digitalP2P.getAdmin(admin);
        assertEq(address(0), expectedAdmin);
    }

    // Update status
}

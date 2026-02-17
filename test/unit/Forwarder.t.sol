// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {Test} from "forge-std/Test.sol";
import {
    DepositForwarder,
    DepositForwarder_OnlyFactory,
    DepositForwarder_AlreadyInitialized,
    DepositForwarder_InvalidFactory
} from "../../src/DepositForwarder.sol";
import {ForwarderFactory, ForwarderFactory_InvalidAddress} from "../../src/ForwarderFactory.sol";
import {ERC20Mock} from "../mocks/ERC20Mock.sol";

contract ForwarderTest is Test {
    DepositForwarder impl;
    ForwarderFactory factory;
    ERC20Mock token;

    address vault = makeAddr("vault");
    address buyer = makeAddr("buyer");
    address owner;

    function setUp() public {
        owner = address(this);
        impl = new DepositForwarder();
        factory = new ForwarderFactory(address(impl), vault);
        token = new ERC20Mock("MockUSDT", "USDT", 6);
    }

    function testComputeAddressIsDeterministic() public view {
        bytes32 salt = keccak256("order-1");
        address a = factory.computeAddress(salt);
        address b = factory.computeAddress(salt);
        assertEq(a, b);
    }

    function testComputeAddressMatchesDeployedProxy() public {
        bytes32 salt = keccak256("order-2");
        address predicted = factory.computeAddress(salt);
        address deployed = factory.deploy(salt);
        assertEq(predicted, deployed);
    }

    function testDeployAndFlush() public {
        bytes32 salt = keccak256("order-3");
        address predicted = factory.computeAddress(salt);

        uint256 amount = 100e6;
        token.mint(predicted, amount);

        address[] memory recipients = new address[](1);
        recipients[0] = buyer;
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = amount;

        factory.deployAndFlush(salt, address(token), recipients, amounts);
        assertEq(token.balanceOf(buyer), amount);
        assertEq(token.balanceOf(predicted), 0);
    }

    function testDeployAndFlushMultipleRecipients() public {
        bytes32 salt = keccak256("order-4");
        address predicted = factory.computeAddress(salt);

        uint256 total = 100e6;
        uint256 fee = 0.6e6;
        uint256 net = total - fee;
        token.mint(predicted, total);

        address[] memory recipients = new address[](2);
        recipients[0] = buyer;
        recipients[1] = vault;
        uint256[] memory amounts = new uint256[](2);
        amounts[0] = net;
        amounts[1] = fee;

        factory.deployAndFlush(salt, address(token), recipients, amounts);
        assertEq(token.balanceOf(buyer), net);
        assertEq(token.balanceOf(vault), fee);
    }

    function testBatchFlushTokens() public {
        bytes32 salt1 = keccak256("batch-1");
        bytes32 salt2 = keccak256("batch-2");

        address proxy1 = factory.deploy(salt1);
        address proxy2 = factory.deploy(salt2);

        token.mint(proxy1, 50e6);
        token.mint(proxy2, 75e6);

        address[] memory proxies = new address[](2);
        proxies[0] = proxy1;
        proxies[1] = proxy2;

        factory.batchFlushTokens(proxies, address(token));
        assertEq(token.balanceOf(vault), 125e6);
        assertEq(token.balanceOf(proxy1), 0);
        assertEq(token.balanceOf(proxy2), 0);
    }

    function testOnlyFactoryCanFlush() public {
        bytes32 salt = keccak256("order-5");
        address proxy = factory.deploy(salt);

        address[] memory recipients = new address[](1);
        recipients[0] = buyer;
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 1e6;

        vm.prank(address(0xdead));
        vm.expectRevert(DepositForwarder_OnlyFactory.selector);
        DepositForwarder(payable(proxy)).flushTokens(address(token), recipients, amounts);
    }

    function testOnlyOwnerCanDeploy() public {
        bytes32 salt = keccak256("order-6");
        vm.prank(address(0xdead));
        vm.expectRevert();
        factory.deploy(salt);
    }

    function testFlushNative() public {
        bytes32 salt = keccak256("order-native");
        address proxy = factory.deploy(salt);
        vm.deal(proxy, 1 ether);

        factory.flushNative(payable(proxy), payable(vault));
        assertEq(vault.balance, 1 ether);
        assertEq(proxy.balance, 0);
    }

    function testFlushNativeOnlyFactory() public {
        bytes32 salt = keccak256("order-native-guard");
        address proxy = factory.deploy(salt);
        vm.deal(proxy, 1 ether);

        vm.prank(address(0xdead));
        vm.expectRevert(DepositForwarder_OnlyFactory.selector);
        DepositForwarder(payable(proxy)).flushNative(payable(vault));
    }

    function testFlushNativeViaFactory() public {
        bytes32 salt = keccak256("order-native-factory");
        address proxy = factory.deploy(salt);
        vm.deal(proxy, 2 ether);

        factory.flushNative(payable(proxy), payable(vault));
        assertEq(vault.balance, 2 ether);
        assertEq(proxy.balance, 0);
    }

    function testFlushNativeOnlyOwner() public {
        bytes32 salt = keccak256("order-native-owner");
        address proxy = factory.deploy(salt);
        vm.deal(proxy, 1 ether);

        vm.prank(address(0xdead));
        vm.expectRevert();
        factory.flushNative(payable(proxy), payable(vault));
    }

    function testZeroAddressImplementationReverts() public {
        vm.expectRevert(ForwarderFactory_InvalidAddress.selector);
        new ForwarderFactory(address(0), vault);
    }

    function testZeroAddressVaultReverts() public {
        vm.expectRevert(ForwarderFactory_InvalidAddress.selector);
        new ForwarderFactory(address(impl), address(0));
    }

    function testInitZeroAddressReverts() public {
        DepositForwarder raw = new DepositForwarder();
        vm.expectRevert(DepositForwarder_InvalidFactory.selector);
        raw.init(address(0));
    }

    function testCanReceiveTokensBeforeDeployment() public {
        bytes32 salt = keccak256("pre-deploy");
        address predicted = factory.computeAddress(salt);

        token.mint(predicted, 200e6);
        assertEq(token.balanceOf(predicted), 200e6);

        address[] memory recipients = new address[](1);
        recipients[0] = vault;
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 200e6;

        factory.deployAndFlush(salt, address(token), recipients, amounts);
        assertEq(token.balanceOf(vault), 200e6);
        assertEq(token.balanceOf(predicted), 0);
    }

    function testDoubleInitReverts() public {
        bytes32 salt = keccak256("order-double-init");
        address proxy = factory.deploy(salt);

        vm.expectRevert(DepositForwarder_AlreadyInitialized.selector);
        DepositForwarder(payable(proxy)).init(address(0xdead));
    }
}

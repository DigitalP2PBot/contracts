// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

error DepositForwarder_OnlyFactory();
error DepositForwarder_AlreadyInitialized();
error DepositForwarder_InvalidFactory();
error DepositForwarder_LengthMismatch();
error DepositForwarder_NativeTransferFailed();

contract DepositForwarder {
    using SafeERC20 for IERC20;

    address private _factory;

    event TokensFlushed(address indexed proxy, address indexed token, uint256 totalAmount);
    event NativeFlushed(address indexed proxy, address indexed recipient, uint256 amount);

    modifier onlyFactory() {
        if (msg.sender != _factory) revert DepositForwarder_OnlyFactory();
        _;
    }

    function init(address factory_) external {
        if (_factory != address(0)) revert DepositForwarder_AlreadyInitialized();
        if (factory_ == address(0)) revert DepositForwarder_InvalidFactory();
        _factory = factory_;
    }

    function flushTokens(address token, address[] calldata recipients, uint256[] calldata amounts)
        external
        onlyFactory
    {
        if (recipients.length != amounts.length) revert DepositForwarder_LengthMismatch();
        uint256 totalAmount;
        IERC20 erc20 = IERC20(token);
        for (uint256 i; i < recipients.length; ++i) {
            erc20.safeTransfer(recipients[i], amounts[i]);
            totalAmount += amounts[i];
        }
        emit TokensFlushed(address(this), token, totalAmount);
    }

    function flushNative(address payable recipient) external onlyFactory {
        uint256 balance = address(this).balance;
        (bool ok,) = recipient.call{value: balance}("");
        if (!ok) revert DepositForwarder_NativeTransferFailed();
        emit NativeFlushed(address(this), recipient, balance);
    }

    function factory() external view returns (address) {
        return _factory;
    }

    receive() external payable {}
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {DepositForwarder} from "./DepositForwarder.sol";

error ForwarderFactory_InvalidAddress();

contract ForwarderFactory is Ownable {
    address public immutable implementation;
    address public immutable vault;

    event ProxyDeployed(address indexed proxy, bytes32 indexed salt);

    constructor(address _implementation, address _vault) Ownable(msg.sender) {
        if (_implementation == address(0)) revert ForwarderFactory_InvalidAddress();
        if (_vault == address(0)) revert ForwarderFactory_InvalidAddress();
        implementation = _implementation;
        vault = _vault;
    }

    function computeAddress(bytes32 salt) external view returns (address) {
        return Clones.predictDeterministicAddress(implementation, salt, address(this));
    }

    function deploy(bytes32 salt) public onlyOwner returns (address proxy) {
        proxy = Clones.cloneDeterministic(implementation, salt);
        DepositForwarder(payable(proxy)).init(address(this));
        emit ProxyDeployed(proxy, salt);
    }

    function deployAndFlush(bytes32 salt, address token, address[] calldata recipients, uint256[] calldata amounts)
        external
        onlyOwner
        returns (address proxy)
    {
        proxy = deploy(salt);
        DepositForwarder(payable(proxy)).flushTokens(token, recipients, amounts);
    }

    function flushNative(address payable proxy, address payable recipient) external onlyOwner {
        DepositForwarder(proxy).flushNative(recipient);
    }

    function batchFlushTokens(address[] calldata proxies, address token) external onlyOwner {
        address[] memory recipients = new address[](1);
        recipients[0] = vault;
        uint256[] memory amounts = new uint256[](1);
        for (uint256 i; i < proxies.length; ++i) {
            uint256 balance = IERC20(token).balanceOf(proxies[i]);
            if (balance == 0) continue;
            amounts[0] = balance;
            DepositForwarder(payable(proxies[i])).flushTokens(token, recipients, amounts);
        }
    }
}

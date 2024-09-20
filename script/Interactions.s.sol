// SPDX-License-Identifier: MIT

pragma solidity ^0.8.25;

import {Script, console} from "forge-std/Script.sol";
import {DevOpsTools} from "foundry-devops/src/DevOpsTools.sol";
import {DigitalP2P} from "../src/DigitalP2P.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract DigitalP2PProcessOrder is Script {
    uint256 constant USDT_DECIMAL_PLACES = 1e6;
    string constant ORDER_ID = "f47ac10b-58cc-4372-a567-0e02b2c3d479";
    address constant SELLER = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;
    uint256 constant USDT_AMOUNT = 2;
    uint256 constant AMOUNT_USDT_TOKEN_TO_MINT = 100;
    uint256 constant ANVIL_CHAIN_ID = 31337;
    ERC20Mock usdtToken;

    function processOrder(address mostRecentlyDeployed) public {
        uint256 _amount = 5;
        DigitalP2P digitalP2P = DigitalP2P(payable(mostRecentlyDeployed));
        vm.startBroadcast();
        usdtToken = ERC20Mock(address(digitalP2P.usdtToken()));
        usdtToken.mint(SELLER, AMOUNT_USDT_TOKEN_TO_MINT * USDT_DECIMAL_PLACES);
        usdtToken.approve(address(digitalP2P), _amount * USDT_DECIMAL_PLACES);

        digitalP2P.processOrder(ORDER_ID, SELLER, _amount, _amount);
        vm.stopBroadcast();
    }

    function run() public {
        address mostRecentlyDeployed = DevOpsTools.get_most_recent_deployment(
            "DigitalP2P",
            block.chainid
        );
        console.log(
            "last deploy[, mostRecentlyDeployed]",
            mostRecentlyDeployed
        );
        processOrder(payable(mostRecentlyDeployed));
    }
}

contract DigitalP2PReleaseOrder is Script {
    string constant ORDER_ID = "f47ac10b-58cc-4372-a567-0e02b2c3d479";

    function releaseOrder(address mostRecentlyDeployed) public {
        vm.startBroadcast();
        DigitalP2P(payable(mostRecentlyDeployed)).releaseOrder(ORDER_ID);
        vm.stopBroadcast();
    }

    function run() public {
        address mostRecentlyDeployed = DevOpsTools.get_most_recent_deployment(
            "DigitalP2P",
            block.chainid
        );
        releaseOrder(mostRecentlyDeployed);
    }
}

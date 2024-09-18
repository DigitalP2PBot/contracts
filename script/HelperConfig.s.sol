// SPDX-License-Identifier: Mitchell

pragma solidity ^0.8.25;

import {Script} from "forge-std/Script.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";

contract HelperConfig is Script {
    address polygonAmoyUsdtTokenAddress = 0xd723DBc20c3Df2f06F4Ca5F217f91919C912d7f8;
    address polygonPosUsdtTokenAddress = 0xc2132D05D31c914a87C6611C10748AEb04B58e8F;
    uint256 polygonAmoyChainId = 80002;
    uint256 polygonPos = 137;

    struct NetworkConfig {
        address priceFeed;
        address usdtTokenAddress;
    }

    NetworkConfig public activeNetworkConfig;

    constructor() {
        if (block.chainid == polygonAmoyChainId) {
            activeNetworkConfig = getPolygonTestNetConfig();
        } else if (block.chainid == polygonPos) {
            activeNetworkConfig = getPolygonPosConfig();
        } else {
            activeNetworkConfig = getOrCreateAnvilEthConfig();
        }
    }

    function getPolygonTestNetConfig() public view returns (NetworkConfig memory) {
        return NetworkConfig({
            priceFeed: 0x2514895c72f50D8bd4B4F9b1110F0D6bD2c97526,
            usdtTokenAddress: polygonAmoyUsdtTokenAddress
        });
    }

    function getPolygonPosConfig() public view returns (NetworkConfig memory) {
        return NetworkConfig({
            priceFeed: 0x8A753747A1Fa494EC906cE90E9f37563A8AF630e,
            usdtTokenAddress: polygonPosUsdtTokenAddress
        });
    }

    function getOrCreateAnvilEthConfig() public returns (NetworkConfig memory) {
        if (activeNetworkConfig.priceFeed != address(0)) {
            return activeNetworkConfig;
        }
        vm.startBroadcast();
        //MockV3Aggregator mockV3Aggregator = new MockV3Aggregator(DECIMALS, INITIAL_PRICE);
        ERC20Mock mockUsdtTokenAddress = new ERC20Mock();
        vm.stopBroadcast();
        NetworkConfig memory anvilConfig =
            NetworkConfig({priceFeed: address(0), usdtTokenAddress: address(mockUsdtTokenAddress)});
        return anvilConfig;
    }
}

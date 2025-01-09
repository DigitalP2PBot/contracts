// SPDX-License-Identifier: Mitchell

pragma solidity ^0.8.25;

import {Script} from "forge-std/Script.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";

contract HelperConfig is Script {
    address polygonPosUsdtTokenAddress =
        0xc2132D05D31c914a87C6611C10748AEb04B58e8F;
    uint256 polygonAmoyChainId = 80002;
    uint256 polygonPos = 137;
    uint256 sepoliaChainId = 11155111;

    struct NetworkConfig {
        address priceFeed;
        address usdtTokenAddress;
    }

    NetworkConfig public activeNetworkConfig;

    constructor() {
        if (block.chainid == polygonAmoyChainId) {
            uint256 amount = 1000;
            vm.startBroadcast();
            ERC20Mock mockUsdtTokenAddress = new ERC20Mock();
            mockUsdtTokenAddress.mint(msg.sender, amount);
            mockUsdtTokenAddress.mint(
                0x02E2e0791Ac89F219aCA15FE109F5cD7f83C9a07,
                amount
            );

            mockUsdtTokenAddress.mint(
                0x778F53F8549b2c198dc734cb59dfeDd437496499,
                amount
            );
            vm.stopBroadcast();
            activeNetworkConfig = getPolygonTestNetConfig(
                address(mockUsdtTokenAddress)
            );
        } else if (block.chainid == sepoliaChainId) {
            uint256 amount = 1000;
            vm.startBroadcast();
            ERC20Mock mockUsdtTokenAddress = new ERC20Mock();
            mockUsdtTokenAddress.mint(msg.sender, amount);
            mockUsdtTokenAddress.mint(
                0x02E2e0791Ac89F219aCA15FE109F5cD7f83C9a07,
                amount
            );

            mockUsdtTokenAddress.mint(
                0x778F53F8549b2c198dc734cb59dfeDd437496499,
                amount
            );
            vm.stopBroadcast();
            activeNetworkConfig = getSepoliaConfig(
                address(mockUsdtTokenAddress)
            );
        } else if (block.chainid == polygonPos) {
            activeNetworkConfig = getPolygonPosConfig(
                address(polygonPosUsdtTokenAddress)
            );
        } else {
            vm.startBroadcast();
            ERC20Mock mockUsdtTokenAddress = new ERC20Mock();
            vm.stopBroadcast();
            activeNetworkConfig = getOrCreateAnvilEthConfig(
                address(mockUsdtTokenAddress)
            );
        }
    }

    function getPolygonTestNetConfig(
        address usdtTokenAddress
    ) public pure returns (NetworkConfig memory) {
        return
            NetworkConfig({
                priceFeed: 0x2514895c72f50D8bd4B4F9b1110F0D6bD2c97526,
                usdtTokenAddress: usdtTokenAddress
            });
    }

    function getPolygonPosConfig(
        address usdtTokenAddress
    ) public pure returns (NetworkConfig memory) {
        return
            NetworkConfig({
                priceFeed: 0x8A753747A1Fa494EC906cE90E9f37563A8AF630e,
                usdtTokenAddress: usdtTokenAddress
            });
    }

    function getSepoliaConfig(
        address usdtTokenAddress
    ) public pure returns (NetworkConfig memory) {
        return
            NetworkConfig({
                priceFeed: 0x8A753747A1Fa494EC906cE90E9f37563A8AF630e,
                usdtTokenAddress: usdtTokenAddress
            });
    }

    function getOrCreateAnvilEthConfig(
        address usdtTokenAddress
    ) public view returns (NetworkConfig memory) {
        if (activeNetworkConfig.priceFeed != address(0)) {
            return activeNetworkConfig;
        }
        NetworkConfig memory anvilConfig = NetworkConfig({
            priceFeed: address(0),
            usdtTokenAddress: usdtTokenAddress
        });
        return anvilConfig;
    }
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.25;

import {Script, console} from "forge-std/Script.sol";
import {DigitalP2P} from "../src/DigitalP2P.sol";
import {HelperConfig} from "./HelperConfig.s.sol";

contract DeployDigitalP2P is Script {
    function run() external returns (DigitalP2P) {
        vm.startBroadcast();
        DigitalP2P digitalP2P = new DigitalP2P();
        vm.stopBroadcast();
        return digitalP2P;
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {Script, console} from "forge-std/Script.sol";
import {DepositForwarder} from "../src/DepositForwarder.sol";
import {ForwarderFactory} from "../src/ForwarderFactory.sol";

contract DeployForwarder is Script {
    function run() external {
        uint256 deployerKey = vm.envUint("PRIVATE_KEY");
        address vault = vm.envAddress("VAULT_ADDRESS");

        vm.startBroadcast(deployerKey);

        DepositForwarder impl = new DepositForwarder();
        ForwarderFactory factory = new ForwarderFactory(address(impl), vault);
        impl.init(address(factory));

        vm.stopBroadcast();

        console.log("DepositForwarder implementation:", address(impl));
        console.log("ForwarderFactory:", address(factory));
    }
}

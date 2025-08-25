// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import "forge-std/Script.sol";
import { MyOFTTest } from "../src/MyOFTTest.sol";

contract MyOFTTestDeploy is Script {
    function run() external {
        // Replace these env vars with your own values
        address endpoint = vm.envAddress("ENDPOINT_ADDRESS");
        address owner    = vm.envAddress("OWNER_ADDRESS");

        vm.startBroadcast(vm.envUint("PRIVATE_KEY"));
        MyOFTTest oapp = new MyOFTTest(endpoint, owner);
        vm.stopBroadcast();

        console.log("MyOApp deployed to:", address(oapp));
    }
}
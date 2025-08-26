// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import "forge-std/Script.sol";
import { MyOFTTest } from "../src/MyOFTTest.sol";

contract GetTokenFromExisting is Script {
    function run() external {

        address contractAddress = vm.envAddress("AMOY_CONTRACT_ADDRESS");

        vm.startBroadcast(vm.envUint("PRIVATE_KEY"));

        MyOFTTest oapp = MyOFTTest(contractAddress);

        uint256 supply = oapp.totalSupply();
        console.log("Total Supply:", supply);

        address owner = vm.envAddress("TO_ADDRESS");
        
        uint256 balance = oapp.balanceOf(owner);

        console.log("Owner balance:", balance);

        vm.stopBroadcast();
    }
}

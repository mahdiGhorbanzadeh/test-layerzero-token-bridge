// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { OFT } from "@layerzerolabs/oft-evm/contracts/OFT.sol";

/// @notice OFT is an ERC-20 token that extends the OFTCore contract.
contract MyOFTTest is OFT {
    constructor(
        address _lzEndpoint,
        address _owner
    ) OFT("test oft","TOFT", _lzEndpoint, _owner) Ownable(_owner) {
        _mint(_owner, 10000e18);
    }
}
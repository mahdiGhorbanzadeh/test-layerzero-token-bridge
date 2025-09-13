// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.22;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IERC20Burnable } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Burnable.sol";
import { IERC20Permit } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Permit.sol";
import { IAccessControl } from "@openzeppelin/contracts/access/IAccessControl.sol";

/**
 * @title IMTXToken
 * @notice Interface for MTXToken contract
 */
interface IMTXToken is IERC20, IERC20Burnable, IERC20Permit, IAccessControl {
    // Events
    event Blacklisted(address indexed account, bool isBlacklisted);
    event Whitelisted(address indexed account, bool isWhitelisted);
    event ChecksToggled(bool enabled);
    event Paused(address account);
    event Unpaused(address account);
    event RestrictionsDisabled();
    
    function blacklisted(address account) external view returns (bool);
    function whitelisted(address account) external view returns (bool);
    
    function addToBlacklist(address account) external;
    function removeFromBlacklist(address account) external;
    function addToWhitelist(address account) external;
    function removeFromWhitelist(address account) external;
    
    function checksEnabled() external view returns (bool);
    
    function setChecksEnabled(bool enabled) external;
    
    function pause() external;
    function unpause() external;
    function paused() external view returns (bool);
    
    function restrictionsEnabled() external view returns (bool);
    function disableRestrictions() external;
}

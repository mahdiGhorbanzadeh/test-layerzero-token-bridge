// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.22;

import { AccessControl } from "@openzeppelin/contracts/access/AccessControl.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { ERC20Burnable } from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import { OFT } from "@layerzerolabs/oft-evm/contracts/OFT.sol";
import { IMTXToken } from "./IMTXToken.sol";

/// @notice OFT is an ERC-20 token that extends the OFTCore contract.
contract MTXToken is OFT, AccessControl, ERC20Burnable, IMTXToken {
    // Define roles
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant MANAGER_ROLE = keccak256("MANAGER_ROLE");
    
        // Transfer limits (based on 10 billion total supply)
    uint256 public constant MAX_WALLET_BALANCE = 100_000_000 * 10**18; // 1% of 10 billion (100 million tokens)
    uint256 public constant MAX_TRANSFER_AMOUNT = 5_000_000 * 10**18;  // 0.05% of 10 billion (5 million tokens)


    // Blacklist mapping
    mapping(address => bool) public blacklisted;
    
    // Control state for all checks (blacklist, transfer limits, wallet balance limits)
    bool public checksEnabled = true;
    
    /**
     * @notice Modifier to restrict access to manager role
     */
    modifier onlyManager() {
        require(hasRole(MANAGER_ROLE, _msgSender()), "MTXToken: caller is not a manager");
        _;
    }

    constructor(
        address _lzEndpoint,
        address _owner,
        address _admin
    ) OFT("mtx-token","MTX", _lzEndpoint, _admin) Ownable(_owner) {
        _grantRole(DEFAULT_ADMIN_ROLE, _admin);  
        _mint(_admin, 10_000_000_000 * 10**decimals());
    }
        /**
     * @notice Add an address to the blacklist
     * @param account The address to blacklist
     */
    function addToBlacklist(address account) external override onlyManager {
        blacklisted[account] = true;
        emit Blacklisted(account, true);
    }

    /**
     * @notice Remove an address from the blacklist
     * @param account The address to remove from blacklist
     */
    function removeFromBlacklist(address account) external override onlyManager {
        blacklisted[account] = false;
        emit Blacklisted(account, false);
    }

    /**
     * @notice Enable or disable all checks (blacklist, transfer limits, wallet balance limits)
     * @param enabled True to enable all checks, false to disable all checks
     */
    function setChecksEnabled(bool enabled) external onlyAdmin {
        checksEnabled = enabled;
        emit ChecksToggled(enabled);
    }

    /**
     * @notice Override transfer to check blacklist and wallet limits
     */
    function _update(address from, address to, uint256 value) internal override {
        // Only perform checks if checksEnabled is true
        if (checksEnabled) {
            // Check blacklist
            require(!blacklisted[from], "MTXToken: sender is blacklisted");
            require(!blacklisted[to], "MTXToken: recipient is blacklisted");
            
            // Check transfer amount limit (0.05% of total supply)
            require(value <= MAX_TRANSFER_AMOUNT, "MTXToken: transfer amount exceeds maximum allowed");
            
            // Check wallet balance limit (1% of total supply) - only for regular transfers, not minting
            if (from != address(0)) { // Not a mint operation
                require(balanceOf(to) + value <= MAX_WALLET_BALANCE, "MTXToken: recipient would exceed maximum wallet balance");
            }
        }
        
        super._update(from, to, value);
    }
}
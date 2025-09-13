// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.22;

import { AccessControl } from "@openzeppelin/contracts/access/AccessControl.sol";
import { Pausable } from "@openzeppelin/contracts/utils/Pausable.sol";
import { ERC20Burnable } from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import { ERC20Permit } from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import { OFT } from "@layerzerolabs/oft-evm/contracts/OFT.sol";
import { IMTXToken } from "./IMTXToken.sol";

/// @notice OFT is an ERC-20 token that extends the OFTCore contract.
contract MTXToken is OFT, AccessControl, ERC20Burnable, ERC20Permit, Pausable, IMTXToken {
    // Define roles
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant MANAGER_ROLE = keccak256("MANAGER_ROLE");
    
        // Transfer limits (based on 10 billion total supply)
    uint256 public constant MAX_WALLET_BALANCE = 100_000_000 * 10**18; // 1% of 10 billion (100 million tokens)
    uint256 public constant MAX_TRANSFER_AMOUNT = 5_000_000 * 10**18;  // 0.05% of 10 billion (5 million tokens)


    // Blacklist mapping
    mapping(address => bool) public blacklisted;
    
    // Whitelist mapping - whitelisted addresses bypass all checks
    mapping(address => bool) public whitelisted;
    
    
    // Rate limiting control flags
    bool public checkWindowSize = true;
    bool public checkTxInterval = true;
    bool public checkBlockTxLimit = true;
    bool public checkWindowTxLimit = true;
    bool public checkBlackList = true;
    bool public checkMaxTransfer = true;
    bool public checkMaxWalletBalance = true;
    
    // Control flag for all checks (can only be disabled once by admin)
    bool public restrictionsEnabled = true;
    
    // Rate limiting constants
    uint256 private constant MAX_TXS_PER_WINDOW = 3; // Max transactions per 15 minutes
    uint256 private constant WINDOW_SIZE = 15 minutes; // 15 minute window
    uint256 private constant MIN_TX_INTERVAL = 1 minutes; // Minimum time between transactions
    uint256 private constant MAX_TXS_PER_BLOCK = 2; // Max transactions per block
    
    // Rate limiting state
    struct RateLimit {
        uint256 windowStart;
        uint256 txCount;
        uint256 lastTxTime;
        uint256 lastTxBlock;
        uint256 blockTxCount;
    }
    
    mapping(address => RateLimit) private rateLimits;
    
    /**
     * @notice Modifier to restrict access to manager role
     */
    modifier onlyManager() {
        require(hasRole(MANAGER_ROLE, _msgSender()), "MTXToken: caller is not a data manager");
        _;
    }

    /**
     * @notice Modifier to restrict access to admin role
     */
    modifier onlyAdmin() {
        require(hasRole(DEFAULT_ADMIN_ROLE, _msgSender()), "MTXToken: caller is not an admin");
        _;
    }

    constructor(
        address _lzEndpoint,
        address _owner,
        address _admin
    ) OFT("mtx-token","MTX", _lzEndpoint, _admin) ERC20Permit("mtx-token") {
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
     * @notice Add an address to the whitelist
     * @param account The address to whitelist
     */
    function addToWhitelist(address account) external onlyManager {
        whitelisted[account] = true;
        emit Whitelisted(account, true);
    }

    /**
     * @notice Remove an address from the whitelist
     * @param account The address to remove from whitelist
     */
    function removeFromWhitelist(address account) external onlyManager {
        whitelisted[account] = false;
        emit Whitelisted(account, false);
    }

    /**
     * @notice Enable or disable window size check
     * @param enabled True to enable window size check, false to disable
     */
    function setCheckWindowSize(bool enabled) external onlyManager {
        checkWindowSize = enabled;
    }

    /**
     * @notice Enable or disable transaction interval check
     * @param enabled True to enable interval check, false to disable
     */
    function setCheckTxInterval(bool enabled) external onlyManager {
        checkTxInterval = enabled;
    }

    /**
     * @notice Enable or disable block transaction limit check
     * @param enabled True to enable block limit check, false to disable
     */
    function setCheckBlockTxLimit(bool enabled) external onlyManager {
        checkBlockTxLimit = enabled;
    }

    /**
     * @notice Enable or disable window transaction limit check
     * @param enabled True to enable window limit check, false to disable
     */
    function setCheckWindowTxLimit(bool enabled) external onlyManager {
        checkWindowTxLimit = enabled;
    }

    /**
     * @notice Enable or disable blacklist check
     * @param enabled True to enable blacklist check, false to disable
     */
    function setCheckBlackList(bool enabled) external onlyManager {
        checkBlackList = enabled;
    }

    /**
     * @notice Enable or disable maximum transfer amount check
     * @param enabled True to enable max transfer check, false to disable
     */
    function setCheckMaxTransfer(bool enabled) external onlyManager {
        checkMaxTransfer = enabled;
    }

    /**
     * @notice Enable or disable maximum wallet balance check
     * @param enabled True to enable max wallet balance check, false to disable
     */
    function setCheckMaxWalletBalance(bool enabled) external onlyManager {
        checkMaxWalletBalance = enabled;
    }

    /**
     * @notice Pause all token transfers
     */
    function pause() external onlyManager {
        _pause();
    }

    /**
     * @notice Unpause all token transfers
     */
    function unpause() external onlyManager {
        _unpause();
    }

    /**
     * @notice Permanently disable all restrictions (one-time only, admin only)
     * This function can only be called once and makes the token fully unrestricted
     */
    function disableRestrictions() external onlyAdmin {
        require(restrictionsEnabled, "already disabled");
        restrictionsEnabled = false;
        emit RestrictionsDisabled();
    }

    /**
     * @notice Private function to check and update rate limits for an address
     * @param from The address to check rate limits for
     */
    function _checkRateLimit(address from) private {
        
        RateLimit storage rl = rateLimits[from];
        
        uint256 currentTime = block.timestamp;
        uint256 currentBlock = block.number;
        
        if (checkTxInterval) {
            require(currentTime >= rl.lastTxTime + MIN_TX_INTERVAL,
                "MTXToken: must wait 1 minute between transactions");
        }
        
        if (checkBlockTxLimit) {
            if (rl.lastTxBlock == currentBlock) {
                rl.blockTxCount += 1;
            } else {
                rl.blockTxCount = 1;
                rl.lastTxBlock = currentBlock;
            }
            
            require(rl.blockTxCount <= MAX_TXS_PER_BLOCK,
                "MTXToken: exceeded transactions per block limit");
        }
        
        // Check transactions per window limit (if enabled)
        if (checkWindowTxLimit) {

            if (currentTime > rl.windowStart + WINDOW_SIZE) {
                rl.windowStart = currentTime;
                rl.txCount = 0;
            }

            rl.txCount += 1;
            require(rl.txCount <= MAX_TXS_PER_WINDOW,
                "MTXToken: exceeded transactions per window limit");
        }
        
        // Update last transaction time
        rl.lastTxTime = currentTime;
    }

    /**
     * @notice Override transfer to check blacklist and wallet limits
     */
    function _update(address from, address to, uint256 value) internal override {        
        // Only perform checks if restrictionsEnabled is true
        if (restrictionsEnabled) {
            // Check if contract is paused
            require(!paused(), "Pausable: paused");

            if(checkBlackList){
                require(!blacklisted[from], "MTXToken: sender is blacklisted");
                require(!blacklisted[to], "MTXToken: recipient is blacklisted");
            }

            if(from != address(0) && to != address(0)){
                
                if(!whitelisted[to]){
                    if (checkMaxWalletBalance) { // Not a mint operation
                        require(balanceOf(to) + value <= MAX_WALLET_BALANCE, "MTXToken: recipient would exceed maximum wallet balance");
                    }
                }

                if(!whitelisted[from]){

                    if(checkMaxTransfer){
                        require(value <= MAX_TRANSFER_AMOUNT, "MTXToken: transfer amount exceeds maximum allowed");
                    }
                    
                    _checkRateLimit(from);                    
                }
            }
        }
        
        super._update(from, to, value);
    }
}
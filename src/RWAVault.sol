// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import {ERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import {ERC4626Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC4626Upgradeable.sol";

// ERC-4626 vault for RWA tokens, UUPS upgradeable
// yield accrues passively as protocol revenue is sent to the vault
contract RWAVault is
    Initializable,
    ERC20Upgradeable,
    ERC4626Upgradeable,
    OwnableUpgradeable,
    ReentrancyGuardUpgradeable,
    UUPSUpgradeable
{
    using Math for uint256;

    // V1 storage — don't reorder for V2 compatibility
    uint256 public depositCap;   // 0 = unlimited
    bool public depositsPaused;

    uint256[48] private __gap;

    event DepositCapSet(uint256 newCap);
    event DepositsPaused(bool paused);

    error DepositsPaused_();
    error CapExceeded(uint256 requested, uint256 cap);
    error ZeroShares();
    error ZeroAssets();

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(
        address asset_,
        string memory name_,
        string memory symbol_,
        address owner_,
        uint256 depositCap_
    ) external initializer {
        __ERC20_init(name_, symbol_);
        __ERC4626_init(IERC20(asset_));
        __Ownable_init(owner_);
        __ReentrancyGuard_init();
        __UUPSUpgradeable_init();
        depositCap = depositCap_;
    }

    function setDepositCap(uint256 newCap) external onlyOwner {
        depositCap = newCap;
        emit DepositCapSet(newCap);
    }

    function setDepositsPaused(bool paused) external onlyOwner {
        depositsPaused = paused;
        emit DepositsPaused(paused);
    }

    function deposit(uint256 assets, address receiver) public override nonReentrant returns (uint256 shares) {
        if (depositsPaused) revert DepositsPaused_();
        if (assets == 0) revert ZeroAssets();
        _checkCap(assets);
        shares = super.deposit(assets, receiver);
        if (shares == 0) revert ZeroShares();
    }

    function mint(uint256 shares, address receiver) public override nonReentrant returns (uint256 assets) {
        if (depositsPaused) revert DepositsPaused_();
        if (shares == 0) revert ZeroShares();
        assets = previewMint(shares);
        _checkCap(assets);
        assets = super.mint(shares, receiver);
    }

    function withdraw(uint256 assets, address receiver, address owner_) public override nonReentrant returns (uint256 shares) {
        if (assets == 0) revert ZeroAssets();
        shares = super.withdraw(assets, receiver, owner_);
    }

    function redeem(uint256 shares, address receiver, address owner_) public override nonReentrant returns (uint256 assets) {
        if (shares == 0) revert ZeroShares();
        assets = super.redeem(shares, receiver, owner_);
    }

    function _checkCap(uint256 extra) internal view {
        if (depositCap != 0 && totalAssets() + extra > depositCap) {
            revert CapExceeded(totalAssets() + extra, depositCap);
        }
    }

    function _authorizeUpgrade(address) internal override onlyOwner {}

    function decimals() public view override(ERC20Upgradeable, ERC4626Upgradeable) returns (uint8) {
        return super.decimals();
    }
}

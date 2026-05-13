// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";

// holds protocol fees, only the timelock can move funds
contract Treasury is AccessControl {
    using SafeERC20 for IERC20;
    using Address for address payable;

    bytes32 public constant EXECUTOR_ROLE = keccak256("EXECUTOR_ROLE");

    event ERC20Withdrawn(address indexed token, address indexed to, uint256 amount);
    event ETHWithdrawn(address indexed to, uint256 amount);

    error ZeroAddress();
    error ZeroAmount();

    constructor(address timelock_) {
        if (timelock_ == address(0)) revert ZeroAddress();
        _grantRole(DEFAULT_ADMIN_ROLE, timelock_);
        _grantRole(EXECUTOR_ROLE, timelock_);
    }

    function withdrawERC20(address token, address to, uint256 amount) external onlyRole(EXECUTOR_ROLE) {
        if (to == address(0)) revert ZeroAddress();
        if (amount == 0) revert ZeroAmount();
        IERC20(token).safeTransfer(to, amount);
        emit ERC20Withdrawn(token, to, amount);
    }

    function withdrawETH(address payable to, uint256 amount) external onlyRole(EXECUTOR_ROLE) {
        if (to == address(0)) revert ZeroAddress();
        if (amount == 0) revert ZeroAmount();
        to.sendValue(amount);
        emit ETHWithdrawn(to, amount);
    }

    receive() external payable {}
}

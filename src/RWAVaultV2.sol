// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {RWAVault} from "RWAVault.sol";

// V2 upgrade — adds performance fee on yield
// storage layout: extends V1, new vars go after __gap
contract RWAVaultV2 is RWAVault {
    // new V2 storage — placed at slot after V1 gap
    uint256 public performanceFee; // basis points, e.g. 1000 = 10%
    address public feeRecipient;

    event PerformanceFeeSet(uint256 fee, address recipient);
    event FeeCollected(uint256 amount, address recipient);

    error FeeTooHigh();
    error ZeroFeeRecipient();

    function setPerformanceFee(uint256 feeBps, address recipient) external onlyOwner {
        if (feeBps > 3_000) revert FeeTooHigh(); // max 30%
        if (recipient == address(0)) revert ZeroFeeRecipient();
        performanceFee = feeBps;
        feeRecipient = recipient;
        emit PerformanceFeeSet(feeBps, recipient);
    }

    // V2 version identifier
    function version() external pure returns (string memory) {
        return "2.0.0";
    }
}

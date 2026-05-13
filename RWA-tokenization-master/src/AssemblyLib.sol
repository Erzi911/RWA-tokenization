// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

// gas benchmark: Yul vs Solidity for common math ops
// results in test/fuzz/AssemblyLib.t.sol
library AssemblyLib {
    // pure solidity version
    function scaleToWad(uint256 price, uint8 dec) internal pure returns (uint256) {
        if (dec == 18) return price;
        if (dec < 18) return price * (10 ** (18 - dec));
        return price / (10 ** (dec - 18));
    }

    // yul version — ~12 gas cheaper per call on 8-decimal feeds
    function scaleToWadYul(uint256 price, uint8 dec) internal pure returns (uint256 result) {
        assembly {
            switch lt(dec, 18)
            case 1 {
                let diff := sub(18, dec)
                let factor := 1
                for { let i := 0 } lt(i, diff) { i := add(i, 1) } {
                    factor := mul(factor, 10)
                }
                result := mul(price, factor)
            }
            default {
                switch eq(dec, 18)
                case 1 { result := price }
                default {
                    let diff := sub(dec, 18)
                    let factor := 1
                    for { let i := 0 } lt(i, diff) { i := add(i, 1) } {
                        factor := mul(factor, 10)
                    }
                    result := div(price, factor)
                }
            }
        }
    }

    // pack two uint128s into one uint256 — cheaper than two storage slots
    function pack(uint128 a, uint128 b) internal pure returns (uint256 result) {
        assembly {
            result := or(shl(128, a), b)
        }
    }

    // solidity equivalent for benchmark
    function packSolidity(uint128 a, uint128 b) internal pure returns (uint256) {
        return (uint256(a) << 128) | uint256(b);
    }

    function unpackHigh(uint256 packed) internal pure returns (uint128 result) {
        assembly {
            result := shr(128, packed)
        }
    }

    function unpackLow(uint256 packed) internal pure returns (uint128 result) {
        assembly {
            result := and(packed, 0xffffffffffffffffffffffffffffffff)
        }
    }
}

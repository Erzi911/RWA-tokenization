// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {AssemblyLib} from "../../src/AssemblyLib.sol";

contract AssemblyLibFuzzTest is Test {
    // yul and solidity must always return the same result
    function testFuzz_scaleToWad_yulMatchesSolidity(uint256 price, uint8 dec) public pure {
        dec = uint8(bound(dec, 0, 18)); // keep reasonable range
        price = bound(price, 0, 1e36);

        uint256 sol = AssemblyLib.scaleToWad(price, dec);
        uint256 yul = AssemblyLib.scaleToWadYul(price, dec);
        assertEq(sol, yul);
    }

    // pack/unpack roundtrip
    function testFuzz_pack_roundtrip(uint128 a, uint128 b) public pure {
        uint256 packed = AssemblyLib.pack(a, b);
        assertEq(AssemblyLib.unpackHigh(packed), a);
        assertEq(AssemblyLib.unpackLow(packed), b);
    }

    // pack yul must match pack solidity
    function testFuzz_pack_yulMatchesSolidity(uint128 a, uint128 b) public pure {
        assertEq(AssemblyLib.pack(a, b), AssemblyLib.packSolidity(a, b));
    }
}

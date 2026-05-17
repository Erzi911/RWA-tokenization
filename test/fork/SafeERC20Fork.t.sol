// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console2} from "forge-std/Test.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {RWAVault} from "src/RWAVault.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

// forge test --match-path test/fork/SafeERC20Fork.t.sol --fork-url $BASE_SEPOLIA_RPC_URL -vvv
contract SafeERC20ForkTest is Test {
    using SafeERC20 for IERC20;

    address constant USDC       = 0x036CbD53842c5426634e7929541eC2318f3dCF7e;
    address constant USDC_WHALE = 0x44e2deC86B9F0e0266E9AA66e10323A2bd69CF9A;

    RWAVault internal vault;
    address  internal admin = makeAddr("admin");

    modifier onlyFork() {
        if (USDC.code.length == 0) return;
        _;
    }

    function setUp() public {
        if (USDC.code.length == 0) return;

        RWAVault impl = new RWAVault();
        bytes memory initData = abi.encodeCall(
            RWAVault.initialize,
            (USDC, "USDC Vault", "vUSDC", admin, 0)
        );
        vault = RWAVault(address(new ERC1967Proxy(address(impl), initData)));
    }

    function test_depositAndWithdraw() public onlyFork {
        uint256 amount = 100e6;

        vm.startPrank(USDC_WHALE);
        IERC20(USDC).approve(address(vault), amount);
        uint256 shares = vault.deposit(amount, USDC_WHALE);
        vm.stopPrank();

        assertGt(shares, 0);
        console2.log("Shares received:", shares);

        vm.prank(USDC_WHALE);
        uint256 returned = vault.redeem(shares, USDC_WHALE, USDC_WHALE);
        assertGe(returned, amount - 1);
        console2.log("USDC returned:", returned);
    }

    function test_safeTransfer_noRevert() public onlyFork {
        uint256 amount = 50e6;
        vm.prank(USDC_WHALE);
        IERC20(USDC).safeTransfer(admin, amount);
        assertEq(IERC20(USDC).balanceOf(admin), amount);
    }

    function test_vaultTotalAssets() public onlyFork {
        uint256 amount = 200e6;
        vm.startPrank(USDC_WHALE);
        IERC20(USDC).approve(address(vault), amount);
        vault.deposit(amount, USDC_WHALE);
        vm.stopPrank();
        assertEq(vault.totalAssets(), amount);
    }
}

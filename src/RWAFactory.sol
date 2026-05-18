// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {RWAToken} from "./RWAToken.sol";
import {RWAVault} from "./RWAVault.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

// deploys matched RWAToken + RWAVault pairs
// token via CREATE, vault proxy via CREATE2 (deterministic address)
contract RWAFactory is Ownable {
    address public immutable vaultImplementation;

    struct AssetInfo {
        address token;
        address vault;
        bool active;
    }

    mapping(bytes32 => AssetInfo) public assets;
    bytes32[] public assetIds;

    event AssetDeployed(bytes32 indexed id, address token, address vault);

    error AssetAlreadyExists(bytes32 id);
    error AssetNotFound(bytes32 id);

    constructor(address vaultImpl_, address owner_) Ownable(owner_) {
        vaultImplementation = vaultImpl_;
    }

    function deployAsset(
        string calldata name,
        string calldata symbol,
        address minter,
        uint256 depositCap
    ) external onlyOwner returns (address token, address vault) {
        bytes32 id = keccak256(abi.encodePacked(name, symbol));
        if (assets[id].token != address(0)) revert AssetAlreadyExists(id);

        // CREATE — normal deployment
        RWAToken t = new RWAToken(name, symbol, address(this));
        t.grantRole(t.MINTER_ROLE(), minter);

        // CREATE2 — deterministic vault address from salt
        bytes memory initData = abi.encodeCall(
            RWAVault.initialize,
            (address(t), string.concat("v", name), string.concat("v", symbol), owner(), depositCap)
        );
        vault = address(new ERC1967Proxy{salt: id}(vaultImplementation, initData));
        token = address(t);

        assets[id] = AssetInfo(token, vault, true);
        assetIds.push(id);

        emit AssetDeployed(id, token, vault);
    }

    function predictVaultAddress(string calldata name, string calldata symbol) external view returns (address) {
        bytes32 id = keccak256(abi.encodePacked(name, symbol));
        bytes32 bytecodeHash = keccak256(
            abi.encodePacked(
                type(ERC1967Proxy).creationCode,
                abi.encode(vaultImplementation, bytes(""))
            )
        );
        return address(uint160(uint256(keccak256(abi.encodePacked(bytes1(0xff), address(this), id, bytecodeHash)))));
    }

    function getAsset(bytes32 id) external view returns (AssetInfo memory) {
        if (assets[id].token == address(0)) revert AssetNotFound(id);
        return assets[id];
    }

    function totalAssets() external view returns (uint256) {
        return assetIds.length;
    }
}

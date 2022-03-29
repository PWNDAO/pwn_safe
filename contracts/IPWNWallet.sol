// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.9;

import "@pwnfinance/multitoken/contracts/MultiToken.sol";


interface IPWNWallet {
	function transferAsset(MultiToken.Asset memory asset, address to) external;
	function hasApprovalsFor(address assetAddress) external view returns (bool);
}

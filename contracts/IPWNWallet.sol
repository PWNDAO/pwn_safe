// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.9;

interface IPWNWallet {
	function transferAsset(address to, address tokenContract, uint256 tokenId) external;
	function safeTransferAsset(address to, address tokenContract, uint256 tokenId) external;
	function safeTransferAsset(address to, address tokenContract, uint256 tokenId, bytes calldata data) external;
}

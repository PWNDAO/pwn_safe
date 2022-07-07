// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.9;

import "MultiToken/MultiToken.sol";

/**
 * @title PWN Wallet Interface
 * @author PWN Finance
 */
interface IPWNWallet {

	/**
	 * @dev AssetTransferRights contract can call this function to force transfer of an asset with tokenized transfer rights.
	 * Callable only by AssetTransferRights contract.
	 *
	 * @param asset MultiToken.Asset struct representing asset which should be transferred
	 * @param to Address of a recipient
	 */
	function transferAsset(MultiToken.Asset memory asset, address to) external;

	/**
	 * @dev Utility function used by AssetTransferRights contract to get information
	 * about approvals for some asset contract on a wallet.
	 *
	 * @param assetAddress Address of an asset contract
	 * @return True if wallet has at least one operator for given asset contract
	 */
	function hasApprovalsFor(address assetAddress) external view returns (bool);

}

// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.15;

/**
 * @title Asset Transfer Rights Guard Interface
 * @author PWN Finance
 */
interface IAssetTransferRightsGuard {

	/**
	 * @dev Utility function used by AssetTransferRights contract to get information
	 * about approvals for some asset contract on a wallet.
	 *
	 * @param safeAddres Safe ... TODO
	 * @param assetAddress Address of an asset contract
	 * @return True if wallet has at least one operator for given asset contract
	 */
	function hasOperatorFor(address safeAddres, address assetAddress) external view returns (bool);

}

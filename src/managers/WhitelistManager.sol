// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.15;


/// TODO: Doc
abstract contract WhitelistManager {

	/*----------------------------------------------------------*|
	|*  # VARIABLES & CONSTANTS DEFINITIONS                     *|
	|*----------------------------------------------------------*/

	/**
	 * @notice Stored flag that incidates, whether ATR token minting is enabled only to whitelisted assets
	 */
	bool internal useWhitelist;

	/**
	 * @notice Whitelist of asset addresses, which are enabled to mint their transfer rights
	 *
	 * @dev Used only if `useWhitelist` flag is set to true
	 */
	mapping (address => bool) internal isWhitelisted;


	/*----------------------------------------------------------*|
	|*  # MODIFIERS                                             *|
	|*----------------------------------------------------------*/

	/// TODO: Doc
	modifier onlyWhitelistManager() virtual;


	/*----------------------------------------------------------*|
	|*  # CONSTRUCTOR                                           *|
	|*----------------------------------------------------------*/

	constructor() {

	}


	/*----------------------------------------------------------*|
	|*  # SETTERS                                               *|
	|*----------------------------------------------------------*/

	/**
	 * @notice Set if ATR token minting is restricted by whitelist
	 *
	 * @dev Set `useWhitelist` stored flag
	 *
	 * @param _useWhitelist New `useWhitelist` flag value
	 */
	function setUseWhitelist(bool _useWhitelist) external onlyWhitelistManager {
		useWhitelist = _useWhitelist;
	}

	/**
	 * @notice Set if asset address is whitelisted
	 *
	 * @dev Set `isWhitelisted` mapping value
	 *
	 * @param assetAddress Address of whitelisted asset
	 * @param _isWhitelisted New `isWhitelisted` mapping value
	 */
	function setIsWhitelisted(address assetAddress, bool _isWhitelisted) external onlyWhitelistManager {
		isWhitelisted[assetAddress] = _isWhitelisted;
	}

}

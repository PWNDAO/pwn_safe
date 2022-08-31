// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.15;

import "../guard/IAssetTransferRightsGuard.sol";


/**
 * @title Asset Transfer Rights Guard Manager
 * @notice Contract responsible for managing stored Asset Transfer Rights Guard address
 */
abstract contract AssetTransferRightsGuardManager {

	/*----------------------------------------------------------*|
	|*  # VARIABLES & CONSTANTS DEFINITIONS                     *|
	|*----------------------------------------------------------*/

	IAssetTransferRightsGuard internal atrGuard;


	/*----------------------------------------------------------*|
	|*  # MODIFIERS                                             *|
	|*----------------------------------------------------------*/

	/**
	 * @dev Restrict access only to guard manager.
	 */
	modifier onlyGuardManager() virtual;


	/*----------------------------------------------------------*|
	|*  # CONSTRUCTOR                                           *|
	|*----------------------------------------------------------*/

	constructor() {

	}


	/*----------------------------------------------------------*|
	|*  # SETTERS                                               *|
	|*----------------------------------------------------------*/

	/**
	 * @dev Set new Asset Transfer Rights Guard.
	 * @param _atrGuard Address of new Asset Transfer Rights Guard.
	 */
	function setAssetTransferRightsGuard(address _atrGuard) external onlyGuardManager {
		atrGuard = IAssetTransferRightsGuard(_atrGuard);
	}

}

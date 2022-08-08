// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.15;

import "../IAssetTransferRightsGuard.sol";


/// TODO: Doc
abstract contract AssetTransferRightsGuardManager {

	/*----------------------------------------------------------*|
	|*  # VARIABLES & CONSTANTS DEFINITIONS                     *|
	|*----------------------------------------------------------*/

	/// TODO: Doc
	IAssetTransferRightsGuard public atrGuard;


	/*----------------------------------------------------------*|
	|*  # MODIFIERS                                             *|
	|*----------------------------------------------------------*/

	/// TODO: Doc
	modifier onlyGuardManager() virtual;


	/*----------------------------------------------------------*|
	|*  # CONSTRUCTOR                                           *|
	|*----------------------------------------------------------*/

	constructor() {

	}


	/*----------------------------------------------------------*|
	|*  # SETTERS                                               *|
	|*----------------------------------------------------------*/

	/// TODO: Doc
	function setAssetTransferRightsGuard(address _atrGuard) external onlyGuardManager {
		atrGuard = IAssetTransferRightsGuard(_atrGuard);
	}

}

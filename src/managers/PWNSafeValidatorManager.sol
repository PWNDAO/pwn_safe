// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.15;

import "../factory/IPWNSafeValidator.sol";


/// TODO: Doc
abstract contract PWNSafeValidatorManager {

	/*----------------------------------------------------------*|
	|*  # VARIABLES & CONSTANTS DEFINITIONS                     *|
	|*----------------------------------------------------------*/

	IPWNSafeValidator internal safeValidator;


	/*----------------------------------------------------------*|
	|*  # MODIFIERS                                             *|
	|*----------------------------------------------------------*/

	/// TODO: Doc
	modifier onlyValidatorManager() virtual;


	/*----------------------------------------------------------*|
	|*  # CONSTRUCTOR                                           *|
	|*----------------------------------------------------------*/

	constructor() {

	}


	/*----------------------------------------------------------*|
	|*  # SETTERS                                               *|
	|*----------------------------------------------------------*/

	/// TODO: Doc
	function setPWNSafeValidator(address _safeValidator) external onlyValidatorManager {
		safeValidator = IPWNSafeValidator(_safeValidator);
	}

}

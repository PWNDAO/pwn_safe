// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity 0.8.15;

import "../factory/IPWNSafeValidator.sol";


/**
 * @title PWNSafe Validator Manager
 * @notice Contract responsible for managing PWNSafe validator.
 */
abstract contract PWNSafeValidatorManager {

	/*----------------------------------------------------------*|
	|*  # VARIABLES & CONSTANTS DEFINITIONS                     *|
	|*----------------------------------------------------------*/

	IPWNSafeValidator internal safeValidator;


	/*----------------------------------------------------------*|
	|*  # MODIFIERS                                             *|
	|*----------------------------------------------------------*/

	/**
	 * @dev Restrict access only to validator manager.
	 */
	modifier onlyValidatorManager() virtual;


	/*----------------------------------------------------------*|
	|*  # CONSTRUCTOR                                           *|
	|*----------------------------------------------------------*/

	constructor() {

	}


	/*----------------------------------------------------------*|
	|*  # SETTERS                                               *|
	|*----------------------------------------------------------*/

	/**
	 * @dev Set new PWNSafe validator.
	 * @param _safeValidator Address of new PWNSafe validator.
	 */
	function setPWNSafeValidator(address _safeValidator) external onlyValidatorManager {
		safeValidator = IPWNSafeValidator(_safeValidator);
	}

}

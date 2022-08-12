// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.15;

interface IPWNSafeValidator {
	/// TODO: Doc
	function isValidSafe(address safe) external view returns (bool);
}

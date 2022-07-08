// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.15;

import "openzeppelin-contracts/contracts/proxy/Clones.sol";
import "./PWNWallet.sol";

/**
 * @title PWN Wallet factory
 * @author PWN Finance
 * @dev Simple factory, that deploys minimal proxy contracts (clones) https://eips.ethereum.org/EIPS/eip-1167[EIP 1167]
 */
contract PWNWalletFactory {
	using Clones for address;


	/*----------------------------------------------------------*|
	|*  # VARIABLES & CONSTANTS DEFINITIONS                     *|
	|*----------------------------------------------------------*/

	/**
	 * @notice Mapping of valid pwn wallet addresses
	 * @dev Is used by AssetTransferRights contract to check that tokenized asset is transferred to valid PWN Wallet
	 * */
	mapping (address => bool) public isValidWallet;

	/**
	 * @dev Address of wallets master implementation
	 */
	address immutable internal _masterImplementation;

	/**
	 * @dev Address of AssetTransferRights contract
	 */
	address immutable internal _atr;


	/*----------------------------------------------------------*|
	|*  # EVENTS & ERRORS DEFINITIONS                           *|
	|*----------------------------------------------------------*/

	/**
	 * @notice Is emitted when new wallet is deployed
	 *
	 * @param walletAddress Address of a new wallet
	 * @param owner Address of a wallet owner
	 */
	event NewWallet(address indexed walletAddress, address indexed owner);


	/*----------------------------------------------------------*|
	|*  # MODIFIERS                                             *|
	|*----------------------------------------------------------*/

	// No modifiers defined


	/*----------------------------------------------------------*|
	|*  # CONSTRUCTOR                                           *|
	|*----------------------------------------------------------*/

	constructor(address atr) {
		_atr = atr;
		_masterImplementation = address(new PWNWallet());
	}


	/*----------------------------------------------------------*|
	|*  # PWN WALLET FACTORY                                    *|
	|*----------------------------------------------------------*/

	/**
	 * @notice Deploy new PWN Wallet
	 *
	 * @dev Deploy minimal proxy contract and point it to wallets master implementation.
	 * Emits {NewWallet} event.
	 */
	function newWallet() external returns (address) {
		address walletAddress = _masterImplementation.clone();
		isValidWallet[walletAddress] = true;

		PWNWallet(walletAddress).initialize(msg.sender, _atr);

		emit NewWallet(walletAddress, msg.sender);

		return walletAddress;
	}

}

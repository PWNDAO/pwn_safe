// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.9;

import "@openzeppelin/contracts/proxy/Clones.sol";
import "./PWNWallet.sol";

contract PWNWalletFactory {
	using Clones for address;

	// Used to check that tokenized asset is transferred to another PWN Wallet
	mapping (address => bool) public isValidWallet;

	address immutable internal _masterImplementation;
	address immutable internal _atr;

	event NewWallet(address indexed walletAddress, address indexed owner);


	constructor(address atr) {
		_atr = atr;
		_masterImplementation = address(new PWNWallet());
	}


	function newWallet() external {
		address walletAddress = _masterImplementation.clone();
		isValidWallet[walletAddress] = true;

		PWNWallet(walletAddress).initialize(msg.sender, _atr);

		emit NewWallet(walletAddress, msg.sender);
	}

}

// SPDX-License-Identifier: None
pragma solidity 0.8.9;

import "@openzeppelin/contracts/proxy/Clones.sol";
import "./PWNWallet.sol";

contract PWNWalletFactory {
	using Clones for address;

	mapping (address => bool) public isValidWallet;

	address immutable internal _masterImplementation;
	address immutable internal _atr;

	event NewWallet(address indexed walletAddress);


	constructor(address atr) {
		_masterImplementation = address(new PWNWallet());
		_atr = atr;
	}


	function newWallet() external {
		address walletAddress = _masterImplementation.clone();
		isValidWallet[walletAddress] = true;

		PWNWallet(walletAddress).setConstructorValues(msg.sender, _atr, address(this));

		emit NewWallet(walletAddress);
	}

}

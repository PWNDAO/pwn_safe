// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.15;

import "forge-std/Test.sol";
import "../src/PWNWallet.sol";
import "../src/PWNWalletFactory.sol";


/*----------------------------------------------------------*|
|*  # NEW WALLET                                            *|
|*----------------------------------------------------------*/

contract PWNWalletFactory_newWallet_Test is Test {

	PWNWalletFactory factory;
	address constant atr = address(0xa74);

	event NewWallet(address indexed walletAddress, address indexed owner);

	function setUp() external {
		factory = new PWNWalletFactory(atr);
	}


	function test_shouldDeployNewMinimalProxyContract() external {
		address wallet = factory.newWallet();

		// Minimal proxy code should mathce regex 0x363d3d373d3d3d363d73.{40}5af43d82803e903d91602b57fd5bf3
		bytes memory code = wallet.code;
		bytes memory mask = "\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff";
		bytes memory result = "\x36\x3d\x3d\x37\x3d\x3d\x3d\x36\x3d\x73\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x5a\xf4\x3d\x82\x80\x3e\x90\x3d\x91\x60\x2b\x57\xfd\x5b\xf3";

		assertEq(code.length, result.length);
		for (uint256 i; i < code.length; ++i) {
			assertEq(code[i] & mask[i], result[i]);
		}
	}

	function test_shouldSetNewContractAddressAsValidWallet() external {
		address wallet = factory.newWallet();

		assertEq(factory.isValidWallet(wallet), true);
	}

	function test_shouldCallInitializeOnNewlyDeployedWallet() external {
		address wallet = factory.newWallet();

		vm.expectRevert("Initializable: contract is already initialized");
		PWNWallet(wallet).initialize(address(0x02), address(0x03));
	}

	function test_shouldEmitNewWalletEvent() external {
		address owner = address(0xb0b);

		vm.expectEmit(false, true, false, false);
		emit NewWallet(address(0x01), owner);
		vm.prank(owner);
		factory.newWallet();
	}

}


/*----------------------------------------------------------*|
|*  # IS VALID WALLET                                       *|
|*----------------------------------------------------------*/

contract PWNWalletFactory_isValidWallet_Test is Test {
	using stdStorage for StdStorage;

	PWNWalletFactory factory;
	address constant atr = address(0xa74);

	function setUp() external {
		factory = new PWNWalletFactory(atr);
	}


	function test_shouldReturnFalse_whenAddressIsNotValidWallet() external {
		assertEq(factory.isValidWallet(address(0xfa3e)), false);
	}

	function test_shouldReturnTrue_whenAddressIsValidWallet() external {
		address wallet = factory.newWallet();

		assertEq(factory.isValidWallet(wallet), true);
	}

}

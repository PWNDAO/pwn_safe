// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.15;

import "forge-std/Test.sol";
import "../src/PWNWallet.sol";
import "../src/PWNWalletFactory.sol";


contract PWNWalletFactoryTest is Test {

	function _validWalletSlotFor(address walletAddr) internal pure returns (bytes32) {
		return keccak256(
			abi.encode(
				walletAddr, // Wallet address as a mapping key
				uint256(0) // isValidWallet mapping position
			)
		);
	}

}


/*----------------------------------------------------------*|
|*  # NEW WALLET                                            *|
|*----------------------------------------------------------*/

contract PWNWalletFactory_newWallet_Test is PWNWalletFactoryTest {

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
		bytes memory mask = hex"ffffffffffffffffffff0000000000000000000000000000000000000000ffffffffffffffffffffffffffffff";
		bytes memory result = hex"363d3d373d3d3d363d7300000000000000000000000000000000000000005af43d82803e903d91602b57fd5bf3";

		assertEq(code.length, result.length);
		for (uint256 i; i < code.length; ++i) {
			assertEq(code[i] & mask[i], result[i]);
		}
	}

	function test_shouldSetNewContractAddressAsValidWallet() external {
		address wallet = factory.newWallet();

		bytes32 isValid = vm.load(address(factory), _validWalletSlotFor(wallet));
		assertEq(uint256(isValid), 1);
	}

	function test_shouldCallInitializeOnNewlyDeployedWallet() external {
		address wallet = factory.newWallet();

		bytes32 initializedValue = (vm.load(address(wallet), bytes32(0)) >> 160) & bytes32(uint256(0xff));
		assertEq(uint256(initializedValue), 1);
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

contract PWNWalletFactory_isValidWallet_Test is PWNWalletFactoryTest {
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
		address wallet = address(0x07abcd);
		vm.store(address(factory), _validWalletSlotFor(wallet), bytes32(uint256(1)));

		assertEq(factory.isValidWallet(wallet), true);
	}

}

// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.15;

import "forge-std/Test.sol";
import "../src/PWNWallet.sol";
import "../src/PWNWalletFactory.sol";
import "../src/AssetTransferRights.sol";
import "../src/test/T20.sol";
import "../src/test/T721.sol";
import "../src/test/T1155.sol";
import "MultiToken/MultiToken.sol";


/*----------------------------------------------------------*|
|*  # ERC20                                                 *|
|*----------------------------------------------------------*/

contract UseCases_ERC20_Test is Test {

	AssetTransferRights atr = new AssetTransferRights();

	PWNWallet wallet;
	PWNWallet walletOther;
	T20 t20;
	address constant alice = address(0xa11ce);
	address constant bob = address(0xb0b);
	address constant erc1820Registry = address(0x1820a4B7618BdE71Dce8cdc73aAB6C95905faD24);

	function setUp() external {
		wallet = PWNWallet(atr.walletFactory().newWallet());
		walletOther = PWNWallet(atr.walletFactory().newWallet());

		t20 = new T20();
		atr.setIsWhitelisted(address(t20), true);

		// ERC1820 Registry
		vm.etch(erc1820Registry, bytes("data"));
		vm.mockCall(
			erc1820Registry,
			abi.encodeWithSignature("getInterfaceImplementer(address,bytes32)"),
			abi.encode(address(0))
		);
	}


	/**
	 * 1:  mint asset
	 * 2:  approve 1/3 to first address
	 * 3:  approve 1/3 to second address
	 * 4:  fail to mint ATR token for 1/3
	 * 5:  first address transfers asset
	 * 6:  resolve internal state
	 * 7:  fail to mint ATR token for 1/3
	 * 8:  set approvel of second address to 0
	 * 9:  mint ATR token for 1/3
	 * 10: fail to approve asset
	 */
	function test_UC_ERC20_1() external {
		// 1:
		t20.mint(address(wallet), 900e18);

		// 2:
		wallet.execute(
			address(t20),
			abi.encodeWithSelector(t20.approve.selector, alice, 300e18)
		);

		// 3:
		wallet.execute(
			address(t20),
			abi.encodeWithSelector(t20.approve.selector, bob, 300e18)
		);

		// 4:
		vm.expectRevert("Some asset from collection has an approval");
		wallet.mintAssetTransferRightsToken(
			MultiToken.Asset(MultiToken.Category.ERC20, address(t20), 0, 300e18)
		);

		// 5:
		vm.prank(alice);
		t20.transferFrom(address(wallet), alice, 300e18);

		// 6:
		wallet.resolveInvalidApproval(address(t20), alice);

		// 7:
		vm.expectRevert("Some asset from collection has an approval");
		wallet.mintAssetTransferRightsToken(
			MultiToken.Asset(MultiToken.Category.ERC20, address(t20), 0, 300e18)
		);

		// 8:
		wallet.execute(
			address(t20),
			abi.encodeWithSelector(t20.approve.selector, bob, 0)
		);

		// 9:
		wallet.mintAssetTransferRightsToken(
			MultiToken.Asset(MultiToken.Category.ERC20, address(t20), 0, 300e18)
		);

		// 10:
		vm.expectRevert("Some asset from collection has transfer right token minted");
		wallet.execute(
			address(t20),
			abi.encodeWithSelector(t20.approve.selector, bob, 300e18)
		);
	}

	/**
	 * 1:  mint asset
	 * 2:  mint ATR token for 1/3
	 * 3:  fail to approve asset
	 * 4:  transfer ATR token to other wallet
	 * 5:  transfer asset via ATR token
	 * 6:  approve 1/3 to first address
	 * 7:  transfer ATR token back to wallet
	 * 8:  fail to transfer tokenized asset back via ATR token
	 * 9:  first address transfers asset
	 * 10: resolve internal state
	 * 11: transfer tokenized asset back via ATR token
	 */
	function test_UC_ERC20_2() external {
		// 1:
		t20.mint(address(wallet), 900e18);

		// 2:
		wallet.mintAssetTransferRightsToken(
			MultiToken.Asset(MultiToken.Category.ERC20, address(t20), 0, 300e18)
		);

		// 3:
		vm.expectRevert("Some asset from collection has transfer right token minted");
		wallet.execute(
			address(t20),
			abi.encodeWithSelector(t20.approve.selector, alice, 300e18)
		);

		// 4:
		wallet.transferAtrTokenFrom(address(wallet), address(walletOther), 1);

		// 5:
		walletOther.transferAssetFrom(address(wallet), 1, false);

		// 6:
		wallet.execute(
			address(t20),
			abi.encodeWithSelector(t20.approve.selector, alice, 300e18)
		);

		// 7:
		walletOther.transferAtrTokenFrom(address(walletOther), address(wallet), 1);

		// 8:
		vm.expectRevert("Receiver has approvals set for an asset");
		wallet.transferAssetFrom(address(walletOther), 1, false);

		// 9:
		vm.prank(alice);
		t20.transferFrom(address(wallet), alice, 300e18);

		// 10:
		wallet.resolveInvalidApproval(address(t20), alice);

		// 11:
		wallet.transferAssetFrom(address(walletOther), 1, false);
	}

	/**
	 * 1: mint asset
	 * 2: mint ATR token for 1/3
	 * 3: burn 1/2 of assets
	 * 4: fail to burn 1/2 of assets
	 * 5: burn ATR token for 1/3
	 * 6: burn 1/2 of assets
	 */
	function test_UC_ERC20_3() external {
		// 1:
		t20.mint(address(wallet), 600e18);

		// 2:
		wallet.mintAssetTransferRightsToken(
			MultiToken.Asset(MultiToken.Category.ERC20, address(t20), 0, 200e18)
		);

		// 3:
		wallet.execute(
			address(t20),
			abi.encodeWithSelector(t20.burn.selector, address(wallet), 300e18)
		);

		// 4:
		vm.expectRevert("Insufficient tokenized balance");
		wallet.execute(
			address(t20),
			abi.encodeWithSelector(t20.burn.selector, address(wallet), 300e18)
		);

		// 5:
		wallet.burnAssetTransferRightsToken(1);

		// 6:
		wallet.execute(
			address(t20),
			abi.encodeWithSelector(t20.burn.selector, address(wallet), 300e18)
		);
	}

}


/*----------------------------------------------------------*|
|*  # ERC721                                                *|
|*----------------------------------------------------------*/

contract UseCases_ERC721_Test is Test {

	AssetTransferRights atr = new AssetTransferRights();

	PWNWallet wallet;
	T721 t721;
	address constant alice = address(0xa11ce);
	address constant bob = address(0xb0b);
	address constant erc1820Registry = address(0x1820a4B7618BdE71Dce8cdc73aAB6C95905faD24);

	function setUp() external {
		wallet = PWNWallet(atr.walletFactory().newWallet());

		t721 = new T721();
		atr.setIsWhitelisted(address(t721), true);

		// ERC1820 Registry
		vm.etch(erc1820Registry, bytes("data"));
		vm.mockCall(
			erc1820Registry,
			abi.encodeWithSignature("getInterfaceImplementer(address,bytes32)"),
			abi.encode(address(0))
		);
	}


	/**
	 * 1:  mint asset 1
	 * 2:  approve asset 1 to first address
	 * 3:  mint asset 2
	 * 4:  mint asset 3
	 * 5:  mint ATR token for asset 2
	 * 6:  fail to mint ATR token for asset 1
	 * 7:  fail to approve asset 3
	 * 8:  set second address as wallets operator for ATR tokens
	 * 9:  second address transfers ATR token 1 to self
	 * 10: fail to transfer tokenized asset 2 via ATR token 1 to second address without burning ATR token
	 * 11: transfer tokenized asset 2 via ATR token 1 to second address and burn ATR token
	 * 12: approve asset 3 to first address
	 */
	function test_UC_ERC721_1() external {
		// 1:
		t721.mint(address(wallet), 1);

		// 2:
		wallet.execute(
			address(t721),
			abi.encodeWithSelector(t721.approve.selector, alice, 1)
		);

		// 3:
		t721.mint(address(wallet), 2);

		// 4:
		t721.mint(address(wallet), 3);

		// 5:
		wallet.mintAssetTransferRightsToken(
			MultiToken.Asset(MultiToken.Category.ERC721, address(t721), 2, 1)
		);

		// 6:
		vm.expectRevert("Tokenized asset has an approved address");
		wallet.mintAssetTransferRightsToken(
			MultiToken.Asset(MultiToken.Category.ERC721, address(t721), 1, 1)
		);

		// 7:
		vm.expectRevert("Some asset from collection has transfer right token minted");
		wallet.execute(
			address(t721),
			abi.encodeWithSelector(t721.approve.selector, alice, 3)
		);

		// 8:
		wallet.execute(
			address(atr),
			abi.encodeWithSelector(atr.setApprovalForAll.selector, bob, true)
		);

		// 9:
		vm.prank(bob);
		atr.transferFrom(address(wallet), bob, 1);

		// 10:
		vm.expectRevert("Attempting to transfer asset to non PWN Wallet address");
		vm.prank(bob);
		atr.transferAssetFrom(address(wallet), 1, false);

		// 11:
		vm.prank(bob);
		atr.transferAssetFrom(address(wallet), 1, true);

		// 12:
		wallet.execute(
			address(t721),
			abi.encodeWithSelector(t721.approve.selector, alice, 3)
		);
	}

	/**
	 * 1:  mint asset id 1
	 * 2:  mint asset id 2
	 * 3:  set first address as wallet operator for asset
	 * 4:  fail to mint ATR token for asset id 1
	 * 5:  remove first address as wallet operator for asset
	 * 6:  mint ATR token 1 for asset id 1
	 * 7:  fail to set first address as wallet operator for asset
	 * 8:  transfer ATR token 1 to first address
	 * 9:  transfer tokenized asset id 1 to first address and burn ATR token
	 * 10: set first address as wallet operator for asset
	 */
	function test_UC_ERC721_2() external {
		// 1:
		t721.mint(address(wallet), 1);

		// 2:
		t721.mint(address(wallet), 2);

		// 3:
		wallet.execute(
			address(t721),
			abi.encodeWithSelector(t721.setApprovalForAll.selector, alice, true)
		);

		// 4:
		vm.expectRevert("Some asset from collection has an approval");
		wallet.mintAssetTransferRightsToken(
			MultiToken.Asset(MultiToken.Category.ERC721, address(t721), 1, 1)
		);

		// 5:
		wallet.execute(
			address(t721),
			abi.encodeWithSelector(t721.setApprovalForAll.selector, alice, false)
		);

		// 6:
		wallet.mintAssetTransferRightsToken(
			MultiToken.Asset(MultiToken.Category.ERC721, address(t721), 1, 1)
		);

		// 7:
		vm.expectRevert("Some asset from collection has transfer right token minted");
		wallet.execute(
			address(t721),
			abi.encodeWithSelector(t721.setApprovalForAll.selector, alice, true)
		);

		// 8:
		wallet.transferAtrTokenFrom(address(wallet), alice, 1);

		// 9:
		vm.prank(alice);
		atr.transferAssetFrom(address(wallet), 1, true);

		// 10:
		wallet.execute(
			address(t721),
			abi.encodeWithSelector(t721.setApprovalForAll.selector, alice, true)
		);
	}

}


/*----------------------------------------------------------*|
|*  # ERC1155                                               *|
|*----------------------------------------------------------*/

contract UseCases_ERC1155_Test is Test {

	AssetTransferRights atr = new AssetTransferRights();

	PWNWallet wallet;
	T1155 t1155;
	address constant alice = address(0xa11ce);
	address constant bob = address(0xb0b);
	address constant erc1820Registry = address(0x1820a4B7618BdE71Dce8cdc73aAB6C95905faD24);

	function setUp() external {
		wallet = PWNWallet(atr.walletFactory().newWallet());

		t1155 = new T1155();
		atr.setIsWhitelisted(address(t1155), true);

		// ERC1820 Registry
		vm.etch(erc1820Registry, bytes("data"));
		vm.mockCall(
			erc1820Registry,
			abi.encodeWithSignature("getInterfaceImplementer(address,bytes32)"),
			abi.encode(address(0))
		);
	}


	/**
	 * 1:  mint asset id 1 amount 600
	 * 2:  mint asset id 2 amount 100
	 * 3:  set first address as wallet operator for asset
	 * 4:  fail to mint ATR token for asset id 1 amount 600
	 * 5:  remove first address as wallet operator for asset
	 * 6:  mint ATR token 1 for asset id 1 amount 600
	 * 7:  fail to set first address as wallet operator for asset
	 * 8:  transfer ATR token 1 to first address
	 * 9:  transfer tokenized asset id 1 amount 600 to first address and burn ATR token
	 * 10: set first address as wallet operator for asset
	 */
	function test_UC_ERC1155_1() external {
		// 1:
		t1155.mint(address(wallet), 1, 600);

		// 2:
		t1155.mint(address(wallet), 2, 100);

		// 3:
		wallet.execute(
			address(t1155),
			abi.encodeWithSelector(t1155.setApprovalForAll.selector, alice, true)
		);

		// 4:
		vm.expectRevert("Some asset from collection has an approval");
		wallet.mintAssetTransferRightsToken(
			MultiToken.Asset(MultiToken.Category.ERC1155, address(t1155), 1, 600)
		);

		// 5:
		wallet.execute(
			address(t1155),
			abi.encodeWithSelector(t1155.setApprovalForAll.selector, alice, false)
		);

		// 6:
		wallet.mintAssetTransferRightsToken(
			MultiToken.Asset(MultiToken.Category.ERC1155, address(t1155), 1, 600)
		);

		// 7:
		vm.expectRevert("Some asset from collection has transfer right token minted");
		wallet.execute(
			address(t1155),
			abi.encodeWithSelector(t1155.setApprovalForAll.selector, alice, true)
		);

		// 8:
		wallet.transferAtrTokenFrom(address(wallet), alice, 1);

		// 9:
		vm.prank(alice);
		atr.transferAssetFrom(address(wallet), 1, true);

		// 10:
		wallet.execute(
			address(t1155),
			abi.encodeWithSelector(t1155.setApprovalForAll.selector, alice, true)
		);
	}

}

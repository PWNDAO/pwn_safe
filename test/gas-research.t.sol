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


abstract contract GasResearchTest is Test {

	AssetTransferRights atr;
	PWNWallet wallet;
	PWNWallet walletOther;
	T20 t20;
	T721 t721;
	T1155 t1155;
	address constant alice = address(0xa11ce);
	address constant bob = address(0xb0b);
	address constant erc1820Registry = address(0x1820a4B7618BdE71Dce8cdc73aAB6C95905faD24);


	constructor() {
		// ERC1820 Registry
		vm.etch(erc1820Registry, bytes("data"));
		vm.mockCall(
			erc1820Registry,
			abi.encodeWithSignature("getInterfaceImplementer(address,bytes32)"),
			abi.encode(address(0))
		);
	}


	function superSetUp() internal {
		atr = new AssetTransferRights();
		wallet = PWNWallet(atr.walletFactory().newWallet());
		walletOther = PWNWallet(atr.walletFactory().newWallet());

		t20 = new T20();
		t721 = new T721();
		t1155 = new T1155();
	}

}


contract GasResearch_MintNewATRToken_Test is GasResearchTest {

	function setUp() external {
		superSetUp();
	}


	function test_mintERC20() external {
		t20.mint(address(wallet), 1000);

		emit log_string("ERC20 mint:");

		uint256 left;
		for (uint256 i; i < 100; ++i) {
			left = gasleft();
			wallet.mintAssetTransferRightsToken(
				MultiToken.Asset(MultiToken.Category.ERC20, address(t20), 0, 10)
			);
			emit log_uint(left - gasleft());
		}
	}

	function test_mintERC721() external {
		emit log_string("ERC721 mint:");

		uint256 left;
		for (uint256 i; i < 100; ++i) {
			t721.mint(address(wallet), i);
			left = gasleft();
			wallet.mintAssetTransferRightsToken(
				MultiToken.Asset(MultiToken.Category.ERC721, address(t721), i, 1)
			);
			emit log_uint(left - gasleft());
		}
	}

	function test_mintERC1155_FT() external {
		emit log_string("ERC1155 FT mint:");

		uint256 left;
		for (uint256 i; i < 100; ++i) {
			t1155.mint(address(wallet), 42, 10);
			left = gasleft();
			wallet.mintAssetTransferRightsToken(
				MultiToken.Asset(MultiToken.Category.ERC1155, address(t1155), 42, 10)
			);
			emit log_uint(left - gasleft());
		}
	}

	function test_mintERC1155_NFT() external {
		emit log_string("ERC1155 NFT mint:");

		uint256 left;
		for (uint256 i; i < 100; ++i) {
			t1155.mint(address(wallet), i, 10);
			left = gasleft();
			wallet.mintAssetTransferRightsToken(
				MultiToken.Asset(MultiToken.Category.ERC1155, address(t1155), i, 10)
			);
			emit log_uint(left - gasleft());
		}
	}

}


contract GasResearch_TransferAsset_Test is GasResearchTest {

	function setUp() external {
		superSetUp();
	}


	function test_transferERC20() external {
		t20.mint(address(wallet), 1000);

		emit log_string("ERC20 transfer:");

		uint256 left;
		uint256 atrId;
		for (uint256 i; i < 100; ++i) {
			atrId = wallet.mintAssetTransferRightsToken(
				MultiToken.Asset(MultiToken.Category.ERC20, address(t20), 0, 10)
			);

			left = gasleft();
			wallet.execute(
				address(atr),
				abi.encodeWithSignature("transferFrom(address,address,uint256)", address(wallet), alice, atrId)
			);

			emit log_uint(left - gasleft());
		}
	}

	function test_transferERC721() external {
		emit log_string("ERC721 transfer:");

		uint256 left;
		uint256 atrId;
		for (uint256 i; i < 100; ++i) {
			t721.mint(address(wallet), i);
			atrId = wallet.mintAssetTransferRightsToken(
				MultiToken.Asset(MultiToken.Category.ERC721, address(t721), i, 1)
			);

			left = gasleft();
			wallet.execute(
				address(atr),
				abi.encodeWithSignature("transferFrom(address,address,uint256)", address(wallet), alice, atrId)
			);

			emit log_uint(left - gasleft());
		}
	}

	function test_transferERC1155_FT() external {
		emit log_string("ERC1155 FT transfer:");

		uint256 left;
		uint256 atrId;
		for (uint256 i; i < 100; ++i) {
			t1155.mint(address(wallet), 42, 10);
			atrId = wallet.mintAssetTransferRightsToken(
				MultiToken.Asset(MultiToken.Category.ERC1155, address(t1155), 42, 10)
			);

			left = gasleft();
			wallet.execute(
				address(atr),
				abi.encodeWithSignature("transferFrom(address,address,uint256)", address(wallet), alice, atrId)
			);

			emit log_uint(left - gasleft());
		}
	}

	function test_transferERC1155_NFT() external {
		emit log_string("ERC1155 NFT transfer:");

		uint256 left;
		uint256 atrId;
		for (uint256 i; i < 100; ++i) {
			t1155.mint(address(wallet), i, 10);
			atrId = wallet.mintAssetTransferRightsToken(
				MultiToken.Asset(MultiToken.Category.ERC1155, address(t1155), i, 10)
			);

			left = gasleft();
			wallet.execute(
				address(atr),
				abi.encodeWithSignature("transferFrom(address,address,uint256)", address(wallet), alice, atrId)
			);

			emit log_uint(left - gasleft());
		}
	}

}

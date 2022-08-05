// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.15;

import "forge-std/Test.sol";
import "../src/AssetTransferRights.sol";
import "../src/PWNWallet.sol";
import "../src/PWNWalletFactory.sol";
import "../src/test/T20.sol";
import "../src/test/T721.sol";
import "../src/test/T1155.sol";
import "../src/test/ContractWallet.sol";
import "MultiToken/MultiToken.sol";


abstract contract AssetTransferRightsTest is Test {

	bytes32 constant USE_WHITELIST_SLOT = bytes32(uint256(7)); // useWhitelist flag position
	bytes32 constant IS_WHITELISTED_SLOT = bytes32(uint256(8)); // isWhitelisted mapping position
	bytes32 constant LAST_TOKEN_ID_SLOT = bytes32(uint256(9)); // lastTokenId property position
	bytes32 constant ASSETS_SLOT = bytes32(uint256(11)); // _assets mapping position
	bytes32 constant OWNED_ASSET_ATR_IDS_SLOT = bytes32(uint256(12)); // _ownedAssetATRIds mapping position
	bytes32 constant OWNED_FROM_COLLECTION_SLOT = bytes32(uint256(13)); // _ownedFromCollection mapping position
	bytes32 constant REVOKED_PERMISSION_SLOT = bytes32(uint256(14)); // revokedPermissions mapping position

	AssetTransferRights atr;
	PWNWalletFactory factory;
	PWNWallet wallet;
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
		factory = new PWNWalletFactory(address(atr));
		wallet = PWNWallet(factory.newWallet());

		atr.setUseWhitelist(false);

		t20 = new T20();
		t721 = new T721();
		t1155 = new T1155();
	}


	function _isWhitelistedSlotFor(address assetAddress) internal pure returns (bytes32) {
		return keccak256(
			abi.encode(
				assetAddress, // Asset address as a mapping key
				IS_WHITELISTED_SLOT
			)
		);
	}

	function _assetStructSlotFor(uint256 atrId) internal pure returns (bytes32) {
		return keccak256(
			abi.encode(
				atrId, // ATR token id as a mapping key
				ASSETS_SLOT
			)
		);
	}

	function _atrIdsSetSlotFor(address owner) internal pure returns (bytes32) {
		return keccak256(
			abi.encode(
				owner, // Owner address as a mapping key
				OWNED_ASSET_ATR_IDS_SLOT
			)
		);
	}

	function _atrIdsValuesSlotFor(address owner) internal pure returns (bytes32) {
		// Hash array position to get position of a first item in the array
		return keccak256(
			abi.encode(
				_atrIdsSetSlotFor(owner)
			)
		);
	}

	function _ownedFromCollectionSlotFor(address owner, address assetAddress) internal pure returns (bytes32) {
		return keccak256(
			abi.encode(
				assetAddress, // Asset address as a mapping key
				keccak256(
					abi.encode(
						owner, // Owner address as a mapping key
						OWNED_FROM_COLLECTION_SLOT
					)
				)
			)
		);
	}

	function _tokenizedBalanceSlotFor(address owner, address assetAddress, uint256 assetId) internal pure returns (bytes32) {
		return keccak256(
			abi.encode(
				assetId, // Asest id as a mapping key
				uint256(_ownedFromCollectionSlotFor(owner, assetAddress)) + 2 // tokenized balance mapping position
			)
		);
	}

	function _revokedPermissionsSlotFor(bytes32 permissionHash) internal pure returns (bytes32) {
		return keccak256(
			abi.encode(
				permissionHash, // Permission hash as a mapping key
				REVOKED_PERMISSION_SLOT
			)
		);
	}

}


/*----------------------------------------------------------*|
|*  # MINT                                                  *|
|*----------------------------------------------------------*/

contract AssetTransferRights_Mint_Test is AssetTransferRightsTest {

	function setUp() external {
		superSetUp();
	}


	// ---> Basic checks
	function test_shouldFail_whenNotPWNWallet() external {
		vm.expectRevert("Caller is not a PWN Wallet");
		vm.prank(alice);
		atr.mintAssetTransferRightsToken(
			MultiToken.Asset(MultiToken.Category.ERC721, address(t721), 42, 1)
		);
	}

	function test_shouldFail_whenNotAssetOwner() external {
		t721.mint(alice, 42);

		vm.expectRevert("Insufficient balance to tokenize");
		vm.prank(address(wallet));
		atr.mintAssetTransferRightsToken(
			MultiToken.Asset(MultiToken.Category.ERC721, address(t721), 42, 1)
		);
	}

	function test_shouldFail_whenZeroAddressAsset() external {
		vm.expectRevert("Attempting to tokenize zero address asset");
		vm.prank(address(wallet));
		atr.mintAssetTransferRightsToken(
			MultiToken.Asset(MultiToken.Category.ERC721, address(0), 42, 1)
		);
	}

	function test_shouldFail_whenATRToken() external {
		vm.expectRevert("Attempting to tokenize ATR token");
		vm.prank(address(wallet));
		atr.mintAssetTransferRightsToken(
			MultiToken.Asset(MultiToken.Category.ERC721, address(atr), 42, 1)
		);
	}

	function test_shouldFail_whenUsingWhitelist_whenAssetNotWhitelisted() external {
		t721.mint(address(wallet), 42);
		atr.setUseWhitelist(true);

		vm.expectRevert("Asset is not whitelisted");
		vm.prank(address(wallet));
		atr.mintAssetTransferRightsToken(
			MultiToken.Asset(MultiToken.Category.ERC721, address(t721), 42, 1)
		);
	}

	function test_shouldPass_whenUsingWhitelist_whenAssetWhitelisted() external {
		t721.mint(address(wallet), 42);
		atr.setUseWhitelist(true);
		atr.setIsWhitelisted(address(t721), true);

		vm.prank(address(wallet));
		atr.mintAssetTransferRightsToken(
			MultiToken.Asset(MultiToken.Category.ERC721, address(t721), 42, 1)
		);
	}

	function test_shouldFail_whenInvalidMultiTokenAsset() external {
		vm.expectRevert("MultiToken.Asset is not valid");
		vm.prank(address(wallet));
		atr.mintAssetTransferRightsToken(
			MultiToken.Asset(MultiToken.Category.ERC721, address(t721), 42, 0)
		);
	}
	// <--- Basic checks

	// ---> Insufficient balance
	function test_shouldFail_whenERC20NotEnoughtBalance() external {
		t20.mint(address(wallet), 99e18);

		vm.expectRevert("Insufficient balance to tokenize");
		vm.prank(address(wallet));
		atr.mintAssetTransferRightsToken(
			MultiToken.Asset(MultiToken.Category.ERC20, address(t20), 0, 100e18)
		);
	}

	function test_shouldFail_whenERC20NotEnoughtUntokenizedBalance() external {
		t20.mint(address(wallet), 99e18);

		vm.prank(address(wallet));
		atr.mintAssetTransferRightsToken(
			MultiToken.Asset(MultiToken.Category.ERC20, address(t20), 0, 90e18)
		);

		vm.expectRevert("Insufficient balance to tokenize");
		vm.prank(address(wallet));
		atr.mintAssetTransferRightsToken(
			MultiToken.Asset(MultiToken.Category.ERC20, address(t20), 0, 10e18)
		);
	}

	function test_shouldFail_whenERC721AlreadyTokenized() external {
		t721.mint(address(wallet), 42);

		vm.prank(address(wallet));
		atr.mintAssetTransferRightsToken(
			MultiToken.Asset(MultiToken.Category.ERC721, address(t721), 42, 1)
		);

		vm.expectRevert("Insufficient balance to tokenize");
		vm.prank(address(wallet));
		atr.mintAssetTransferRightsToken(
			MultiToken.Asset(MultiToken.Category.ERC721, address(t721), 42, 1)
		);
	}

	function test_shouldFail_whenERC1155NotEnoughtBalance() external {
		t1155.mint(address(wallet), 42, 99);

		vm.expectRevert("Insufficient balance to tokenize");
		vm.prank(address(wallet));
		atr.mintAssetTransferRightsToken(
			MultiToken.Asset(MultiToken.Category.ERC1155, address(t1155), 42, 100)
		);
	}

	function test_shouldFail_whenERC1155NotEnoughtUntokenizedBalance() external {
		t1155.mint(address(wallet), 42, 99);

		vm.prank(address(wallet));
		atr.mintAssetTransferRightsToken(
			MultiToken.Asset(MultiToken.Category.ERC1155, address(t1155), 42, 90)
		);

		vm.expectRevert("Insufficient balance to tokenize");
		vm.prank(address(wallet));
		atr.mintAssetTransferRightsToken(
			MultiToken.Asset(MultiToken.Category.ERC1155, address(t1155), 42, 10)
		);
	}
	// <--- Insufficient balance

	// ---> Approvals
	function test_shouldFail_whenERC20AssetIsApproved() external {
		t20.mint(address(wallet), 99e18);

		wallet.execute(
			address(t20),
			abi.encodeWithSelector(t20.approve.selector, alice, 1e18)
		);

		vm.expectRevert("Some asset from collection has an approval");
		vm.prank(address(wallet));
		atr.mintAssetTransferRightsToken(
			MultiToken.Asset(MultiToken.Category.ERC20, address(t20), 0, 10e18)
		);
	}

	function test_shouldFail_whenERC721AssetIsApproved() external {
		t721.mint(address(wallet), 42);

		wallet.execute(
			address(t721),
			abi.encodeWithSelector(t721.approve.selector, alice, 42)
		);

		vm.expectRevert("Tokenized asset has an approved address");
		vm.prank(address(wallet));
		atr.mintAssetTransferRightsToken(
			MultiToken.Asset(MultiToken.Category.ERC721, address(t721), 42, 1)
		);
	}

	function test_shouldFail_whenERC721OperatorIsSet() external {
		t721.mint(address(wallet), 42);

		wallet.execute(
			address(t721),
			abi.encodeWithSelector(t721.setApprovalForAll.selector, alice, true)
		);

		vm.expectRevert("Some asset from collection has an approval");
		vm.prank(address(wallet));
		atr.mintAssetTransferRightsToken(
			MultiToken.Asset(MultiToken.Category.ERC721, address(t721), 42, 1)
		);
	}

	function test_shouldFail_whenERC1155OperatorIsSet() external {
		t1155.mint(address(wallet), 42, 100);

		wallet.execute(
			address(t1155),
			abi.encodeWithSelector(t1155.setApprovalForAll.selector, alice, true)
		);

		vm.expectRevert("Some asset from collection has an approval");
		vm.prank(address(wallet));
		atr.mintAssetTransferRightsToken(
			MultiToken.Asset(MultiToken.Category.ERC1155, address(t1155), 42, 10)
		);
	}
	// <--- Approvals

	// ---> Asset category check with ERC165
	function test_shouldFail_whenERC20asERC721withERC165() external {
		vm.expectRevert("Invalid provided category");
		atr.mintAssetTransferRightsToken(
			MultiToken.Asset(MultiToken.Category.ERC721, address(t20), 132, 1)
		);
	}

	function test_shouldFail_whenERC20asERC1155withERC165() external {
		vm.expectRevert("Invalid provided category");
		atr.mintAssetTransferRightsToken(
			MultiToken.Asset(MultiToken.Category.ERC1155, address(t20), 132, 132)
		);
	}

	function test_shouldFail_whenERC721asERC20withERC165() external {
		vm.expectRevert("Invalid provided category");
		atr.mintAssetTransferRightsToken(
			MultiToken.Asset(MultiToken.Category.ERC20, address(t721), 0, 1)
		);
	}

	function test_shouldFail_whenERC721asERC1155withERC165() external {
		vm.expectRevert("Invalid provided category");
		atr.mintAssetTransferRightsToken(
			MultiToken.Asset(MultiToken.Category.ERC1155, address(t721), 132, 1)
		);
	}

	function test_shouldFail_whenERC1155asERC20withERC165() external {
		vm.expectRevert("Invalid provided category");
		atr.mintAssetTransferRightsToken(
			MultiToken.Asset(MultiToken.Category.ERC20, address(t1155), 0, 132)
		);
	}

	function test_shouldFail_whenERC1155asERC721withERC165() external {
		vm.expectRevert("Invalid provided category");
		atr.mintAssetTransferRightsToken(
			MultiToken.Asset(MultiToken.Category.ERC721, address(t1155), 132, 1)
		);
	}

	function test_shouldPass_whenERC20asERC20withERC165() external {
		t20.mint(address(wallet), 132);

		vm.prank(address(wallet));
		atr.mintAssetTransferRightsToken(
			MultiToken.Asset(MultiToken.Category.ERC20, address(t20), 0, 132)
		);
	}

	function test_shouldPass_whenERC721asERC721withERC165() external {
		t721.mint(address(wallet), 132);

		vm.prank(address(wallet));
		atr.mintAssetTransferRightsToken(
			MultiToken.Asset(MultiToken.Category.ERC721, address(t721), 132, 1)
		);
	}

	function test_shouldPass_whenERC1155asERC1155withERC165() external {
		t1155.mint(address(wallet), 132, 132);

		vm.prank(address(wallet));
		atr.mintAssetTransferRightsToken(
			MultiToken.Asset(MultiToken.Category.ERC1155, address(t1155), 132, 132)
		);
	}
	// <--- Asset category check with ERC165

	// ---> Asset category check without ERC165
	function test_shouldFail_whenERC20asERC721withoutERC165() external {
		t20.supportERC165(false);

		vm.expectRevert("Invalid provided category");
		atr.mintAssetTransferRightsToken(
			MultiToken.Asset(MultiToken.Category.ERC721, address(t20), 132, 1)
		);
	}

	function test_shouldFail_whenERC20asERC1155withoutERC165() external {
		t20.supportERC165(false);

		vm.expectRevert("Invalid provided category");
		atr.mintAssetTransferRightsToken(
			MultiToken.Asset(MultiToken.Category.ERC1155, address(t20), 132, 132)
		);
	}

	function test_shouldFail_whenERC721asERC20withoutERC165() external {
		t721.supportERC165(false);

		vm.expectRevert("Invalid provided category");
		atr.mintAssetTransferRightsToken(
			MultiToken.Asset(MultiToken.Category.ERC20, address(t721), 0, 1)
		);
	}

	function test_shouldFail_whenERC721asERC1155withoutERC165() external {
		t721.supportERC165(false);

		vm.expectRevert("Invalid provided category");
		atr.mintAssetTransferRightsToken(
			MultiToken.Asset(MultiToken.Category.ERC1155, address(t721), 132, 1)
		);
	}

	function test_shouldFail_whenERC1155asERC20withoutERC165() external {
		t1155.supportERC165(false);

		vm.expectRevert("Invalid provided category");
		atr.mintAssetTransferRightsToken(
			MultiToken.Asset(MultiToken.Category.ERC20, address(t1155), 0, 132)
		);
	}

	function test_shouldFail_whenERC1155asERC721withoutERC165() external {
		t1155.supportERC165(false);

		vm.expectRevert("Invalid provided category");
		atr.mintAssetTransferRightsToken(
			MultiToken.Asset(MultiToken.Category.ERC721, address(t1155), 132, 1)
		);
	}

	function test_shouldPass_whenERC20asERC20withoutERC165() external {
		t20.supportERC165(false);
		t20.mint(address(wallet), 132);

		vm.prank(address(wallet));
		atr.mintAssetTransferRightsToken(
			MultiToken.Asset(MultiToken.Category.ERC20, address(t20), 0, 132)
		);
	}

	function test_shouldFail_whenERC721asERC721withoutERC165() external {
		t721.supportERC165(false);
		t721.mint(address(wallet), 132);

		vm.expectRevert("Invalid provided category");
		vm.prank(address(wallet));
		atr.mintAssetTransferRightsToken(
			MultiToken.Asset(MultiToken.Category.ERC721, address(t721), 132, 1)
		);
	}

	function test_shouldFail_whenERC1155asERC1155withoutERC165() external {
		t1155.supportERC165(false);
		t1155.mint(address(wallet), 132, 132);

		vm.expectRevert("Invalid provided category");
		vm.prank(address(wallet));
		atr.mintAssetTransferRightsToken(
			MultiToken.Asset(MultiToken.Category.ERC1155, address(t1155), 132, 132)
		);
	}
	// <--- Asset category check without ERC165

	// ---> Process
	function test_shouldPass_whenERC20SufficientBalance() external {
		t20.mint(address(wallet), 99e18);

		vm.prank(address(wallet));
		atr.mintAssetTransferRightsToken(
			MultiToken.Asset(MultiToken.Category.ERC20, address(t20), 0, 10e18)
		);
	}

	function test_shouldPass_whenERC721SufficientBalance() external {
		t721.mint(address(wallet), 42);

		vm.prank(address(wallet));
		atr.mintAssetTransferRightsToken(
			MultiToken.Asset(MultiToken.Category.ERC721, address(t721), 42, 1)
		);
	}

	function test_shouldPass_whenERC1155SufficientBalance() external {
		t1155.mint(address(wallet), 42, 100);

		vm.prank(address(wallet));
		atr.mintAssetTransferRightsToken(
			MultiToken.Asset(MultiToken.Category.ERC1155, address(t1155), 42, 10)
		);
	}

	function test_shouldIncreaseATRTokenId() external {
		uint256 lastAtrId = 736;
		vm.store(address(atr), LAST_TOKEN_ID_SLOT, bytes32(lastAtrId));
		t721.mint(address(wallet), 42);

		vm.prank(address(wallet));
		atr.mintAssetTransferRightsToken(
			MultiToken.Asset(MultiToken.Category.ERC721, address(t721), 42, 1)
		);

		bytes32 atrId = vm.load(address(atr), LAST_TOKEN_ID_SLOT);
		assertEq(uint256(atrId), lastAtrId + 1);
	}

	function test_shouldStoreTokenizedAssetData() external {
		uint256 lastAtrId = 736;
		vm.store(address(atr), LAST_TOKEN_ID_SLOT, bytes32(lastAtrId));
		t721.mint(address(wallet), 42);

		vm.prank(address(wallet));
		uint256 atrId = atr.mintAssetTransferRightsToken(
			MultiToken.Asset(MultiToken.Category.ERC721, address(t721), 42, 1)
		);

		bytes32 assetStructSlot = _assetStructSlotFor(atrId);

		// Category + address
		bytes32 addrAndCategory = vm.load(address(atr), bytes32(uint256(assetStructSlot) + 0));
		bytes32 assetCategory = addrAndCategory & bytes32(uint256(0xff));
		bytes32 assetAddress = addrAndCategory >> 8;
		assertEq(assetCategory, bytes32(uint256(1)));
		assertEq(assetAddress, bytes32(uint256(uint160(address(t721)))));
		// Id
		bytes32 assetId = vm.load(address(atr), bytes32(uint256(assetStructSlot) + 1));
		assertEq(uint256(assetId), 42);
		// Amount
		bytes32 assetAmount = vm.load(address(atr), bytes32(uint256(assetStructSlot) + 2));
		assertEq(uint256(assetAmount), 1);
	}

	function test_shouldStoreTokenizedAssetOwner() external {
		uint256 lastTokenId = 736;
		vm.store(address(atr), LAST_TOKEN_ID_SLOT, bytes32(lastTokenId));
		t721.mint(address(wallet), 42);

		vm.prank(address(wallet));
		atr.mintAssetTransferRightsToken(
			MultiToken.Asset(MultiToken.Category.ERC721, address(t721), 42, 1)
		);

		bytes32 valuesSlot = _atrIdsValuesSlotFor(address(wallet));
		bytes32 storedId = vm.load(address(atr), valuesSlot); // Expecting one item -> first item (index 0) will be our ATR token
		assertEq(uint256(storedId), lastTokenId + 1);
	}

	function test_shouldMintATRToken() external {
		t721.mint(address(wallet), 42);

		vm.prank(address(wallet));
		uint256 atrId = atr.mintAssetTransferRightsToken(
			MultiToken.Asset(MultiToken.Category.ERC721, address(t721), 42, 1)
		);

		assertEq(atr.ownerOf(atrId), address(wallet));
	}
	// <--- Process
}


/*----------------------------------------------------------*|
|*  # MINT BATCH                                            *|
|*----------------------------------------------------------*/

contract AssetTransferRights_MintBatch_Test is AssetTransferRightsTest {

	function setUp() external {
		superSetUp();
	}


	function test_shouldAcceptEmptyList() external {
		MultiToken.Asset[] memory assets;
		atr.mintAssetTransferRightsTokenBatch(assets);
	}

	function test_shouldTokenizeAllItemsInList() external {
		t20.mint(address(wallet), 776e18);
		t721.mint(address(wallet), 42);

		MultiToken.Asset[] memory assets = new MultiToken.Asset[](2);
		assets[0] = MultiToken.Asset(MultiToken.Category.ERC721, address(t721), 42, 1);
		assets[1] = MultiToken.Asset(MultiToken.Category.ERC20, address(t20), 0, 776e18);

		vm.prank(address(wallet));
		atr.mintAssetTransferRightsTokenBatch(assets);

		assertEq(atr.ownerOf(1), address(wallet));
		assertEq(atr.ownerOf(2), address(wallet));
	}

}


/*----------------------------------------------------------*|
|*  # BURN                                                  *|
|*----------------------------------------------------------*/

contract AssetTransferRights_Burn_Test is AssetTransferRightsTest {

	uint256 tokenId = 42;
	uint256 atrId;

	function setUp() external {
		superSetUp();
		t721.mint(address(wallet), tokenId);

		vm.prank(address(wallet));
		atrId = atr.mintAssetTransferRightsToken(
			MultiToken.Asset(MultiToken.Category.ERC721, address(t721), tokenId, 1)
		);
	}


	function test_shouldFail_whenATRTokenDoesNotExist() external {
		vm.expectRevert("Asset transfer rights are not tokenized");
		vm.prank(alice);
		atr.burnAssetTransferRightsToken(atrId + 1);
	}

	function test_shouldFail_whenSenderNotATRTokenOwner() external {
		vm.expectRevert("Caller is not ATR token owner");
		vm.prank(alice);
		atr.burnAssetTransferRightsToken(atrId);
	}

	function test_shouldFail_whenSenderIsNotTokenizedAssetOwner() external {
		wallet.transferAtrTokenFrom(address(wallet), alice, atrId);

		vm.expectRevert("Insufficient balance of a tokenize asset");
		vm.prank(alice);
		atr.burnAssetTransferRightsToken(atrId);
	}

	function test_shouldClearStoredTokenizedAssetData() external {
		vm.prank(address(wallet));
		atr.burnAssetTransferRightsToken(atrId);

		bytes32 assetStructSlot = _assetStructSlotFor(atrId);

		// Category + address
		bytes32 addrAndCategory = vm.load(address(atr), bytes32(uint256(assetStructSlot) + 0));
        assertEq(uint256(addrAndCategory), 0);
        // Id
        bytes32 assetId = vm.load(address(atr), bytes32(uint256(assetStructSlot) + 1));
        assertEq(uint256(assetId), 0);
        // Amount
        bytes32 assetAmount = vm.load(address(atr), bytes32(uint256(assetStructSlot) + 2));
        assertEq(uint256(assetAmount), 0);
	}

	function test_shouldRemoveStoredTokenizedAssetInfoFromSendersWallet() external {
		vm.prank(address(wallet));
		atr.burnAssetTransferRightsToken(atrId);

		bytes32 setSize = vm.load(address(atr), _atrIdsSetSlotFor(address(wallet)));
		bytes32 valuesSlot = _atrIdsValuesSlotFor(address(wallet));

		for (uint256 i; i < uint256(setSize); ++i) {
			bytes32 storedId = vm.load(address(atr), bytes32(uint256(valuesSlot) + i));
			if (uint256(storedId) == atrId) {
				revert("ATR token is stored after burn");
			}
		}
	}

	function test_shouldBurnATRToken() external {
		vm.prank(address(wallet));
		atr.burnAssetTransferRightsToken(atrId);

		vm.expectRevert("ERC721: invalid token ID");
		atr.ownerOf(atrId);
	}

}


/*----------------------------------------------------------*|
|*  # BURN BATCH                                            *|
|*----------------------------------------------------------*/

contract AssetTransferRights_BurnBatch_Test is AssetTransferRightsTest {

	function setUp() external {
		superSetUp();
	}


	function test_shouldAcceptEmptyList() external {
		uint256[] memory atrIds;

		vm.prank(address(wallet));
		atr.burnAssetTransferRightsTokenBatch(atrIds);
	}

	function test_shouldBurnAllItemsInList() external {
		t721.mint(address(wallet), 42);
		t1155.mint(address(wallet), 132, 600);

		uint256[] memory atrIds = new uint256[](2);

		vm.prank(address(wallet));
		atrIds[0] = atr.mintAssetTransferRightsToken(
			MultiToken.Asset(MultiToken.Category.ERC721, address(t721), 42, 1)
		);

		vm.prank(address(wallet));
		atrIds[1] = atr.mintAssetTransferRightsToken(
			MultiToken.Asset(MultiToken.Category.ERC1155, address(t1155), 132, 600)
		);

		vm.prank(address(wallet));
		atr.burnAssetTransferRightsTokenBatch(atrIds);

		vm.expectRevert("ERC721: invalid token ID");
		atr.ownerOf(atrIds[0]);

		vm.expectRevert("ERC721: invalid token ID");
		atr.ownerOf(atrIds[1]);
	}

}


/*----------------------------------------------------------*|
|*  # TRANSFER ASSET FROM                                   *|
|*----------------------------------------------------------*/

contract AssetTransferRights_TransferAssetFrom_Test is AssetTransferRightsTest {

	PWNWallet walletOther;
	uint256 atrId;

	function setUp() external {
		superSetUp();

		walletOther = PWNWallet(factory.newWallet());

		atrId = _mintAndTransfer721();
	}

	// ---> Helpers
	function _mintAndTransfer20() internal returns (uint256) {
		t20.mint(address(walletOther), 600e18);

		uint256 _atrId = walletOther.mintAssetTransferRightsToken(
			MultiToken.Asset(MultiToken.Category.ERC20, address(t20), 0, 600e18)
		);

		walletOther.transferAtrTokenFrom(address(walletOther), address(wallet), _atrId);

		return _atrId;
	}

	function _mintAndTransfer721() internal returns (uint256) {
		t721.mint(address(walletOther), 42);

		uint256 _atrId = walletOther.mintAssetTransferRightsToken(
			MultiToken.Asset(MultiToken.Category.ERC721, address(t721), 42, 1)
		);

		walletOther.transferAtrTokenFrom(address(walletOther), address(wallet), _atrId);

		return _atrId;
	}

	function _mintAndTransfer1155() internal returns (uint256) {
		t1155.mint(address(walletOther), 42, 600);

		uint256 _atrId = walletOther.mintAssetTransferRightsToken(
			MultiToken.Asset(MultiToken.Category.ERC1155, address(t1155), 42, 600)
		);

		walletOther.transferAtrTokenFrom(address(walletOther), address(wallet), _atrId);

		return _atrId;
	}
	// <--- Helpers


	// ---> Basic checks
	function test_shouldFail_whenTokenRightsAreNotTokenized() external {
		vm.expectRevert("Transfer rights are not tokenized");
		vm.prank(address(wallet));
		atr.transferAssetFrom(address(walletOther), 4, false);
	}

	function test_shouldFail_whenSenderIsNotATRTokenOwner() external {
		PWNWallet walletEmpty = PWNWallet(factory.newWallet());

		vm.expectRevert("Caller is not ATR token owner");
		vm.prank(address(walletEmpty));
		atr.transferAssetFrom(address(walletOther), atrId, false);
	}

	function test_shouldFail_whenAssetIsNotInWallet() external {
		PWNWallet walletEmpty = PWNWallet(factory.newWallet());

		vm.expectRevert("Asset is not in a target wallet");
		vm.prank(address(wallet));
		atr.transferAssetFrom(address(walletEmpty), atrId, false);
	}

	function test_shouldFail_whenTransferringToSameAddress() external {
		wallet.transferAtrTokenFrom(address(wallet), address(walletOther), atrId);

		vm.expectRevert("Attempting to transfer asset to the same address");
		vm.prank(address(walletOther));
		atr.transferAssetFrom(address(walletOther), atrId, false);
	}
	// <--- Basic checks

	// ---> Process
	function test_shouldRemoveStoredTokenizedAssetInfoFromSendersWallet() external {
		vm.prank(address(wallet));
		atr.transferAssetFrom(address(walletOther), atrId, false);

		bytes32 setSize = vm.load(address(atr), _atrIdsSetSlotFor(address(walletOther)));
		bytes32 valuesSlot = _atrIdsValuesSlotFor(address(walletOther));

		for (uint256 i; i < uint256(setSize); ++i) {
			bytes32 storedId = vm.load(address(atr), bytes32(uint256(valuesSlot) + i));
			if (uint256(storedId) == atrId) {
				revert("ATR token is stored after transferAssetFrom");
			}
		}
	}

	function test_shouldTransferERC20Asset() external {
		atrId = _mintAndTransfer20();

		vm.prank(address(wallet));
		atr.transferAssetFrom(address(walletOther), atrId, false);

		assertEq(t20.balanceOf(address(wallet)), 600e18);
		assertEq(t20.balanceOf(address(walletOther)), 0);
	}

	function test_shouldTransferERC721Asset() external {
		vm.prank(address(wallet));
		atr.transferAssetFrom(address(walletOther), atrId, false);

		assertEq(t721.ownerOf(42), address(wallet));
	}

	function test_shouldTransferERC1155Asset() external {
		atrId = _mintAndTransfer1155();

		vm.prank(address(wallet));
		atr.transferAssetFrom(address(walletOther), atrId, false);

		assertEq(t1155.balanceOf(address(wallet), 42), 600);
		assertEq(t1155.balanceOf(address(walletOther), 42), 0);
	}
	// <--- Process

	// ---> Without `burnToken` flag
	function test_shouldStoreThatRecipientHasTokenizedAsset_whenWithoutBurnFlag() external {
		vm.prank(address(wallet));
		atr.transferAssetFrom(address(walletOther), atrId, false);

		bytes32 setSize = vm.load(address(atr), _atrIdsSetSlotFor(address(wallet)));
		bytes32 valuesSlot = _atrIdsValuesSlotFor(address(wallet));

		bool find;
		for (uint256 i; i < uint256(setSize); ++i) {
			bytes32 storedId = vm.load(address(atr), bytes32(uint256(valuesSlot) + i));
			if (uint256(storedId) == atrId) {
				find = true;
				break;
			}
		}

		if (!find) {
			revert("ATR token is not stored after transferAssetFrom");
		}
	}

	function test_shouldFail_whenRecipientHasApprovalForAsset_whenWithoutBurnFlag() external {
		vm.mockCall(
			address(wallet),
			abi.encodeWithSelector(wallet.hasApprovalsFor.selector),
			abi.encode(true)
		);

		vm.expectRevert("Receiver has approvals set for an asset");
		vm.prank(address(wallet));
		atr.transferAssetFrom(address(walletOther), atrId, false);
	}

	function test_shouldFail_whenTransferringToNotPWNWallet_whenWithoutBurnFlag() external {
		wallet.transferAtrTokenFrom(address(wallet), alice, atrId);

		vm.expectRevert("Attempting to transfer asset to non PWN Wallet address");
		vm.prank(alice);
		atr.transferAssetFrom(address(walletOther), atrId, false);
	}
	// <--- Without `burnToken` flag

	// ---> With `burnToken` flag
	function test_shouldClearStoredTokenizedAssetData_whenWithBurnFlag() external {
		wallet.transferAtrTokenFrom(address(wallet), alice, atrId);

		vm.prank(alice);
		atr.transferAssetFrom(address(walletOther), atrId, true);

		bytes32 assetStructSlot = _assetStructSlotFor(atrId);

		// Category + address
		bytes32 addrAndCategory = vm.load(address(atr), bytes32(uint256(assetStructSlot) + 0));
        assertEq(uint256(addrAndCategory), 0);
        // Id
        bytes32 assetId = vm.load(address(atr), bytes32(uint256(assetStructSlot) + 1));
        assertEq(uint256(assetId), 0);
        // Amount
        bytes32 assetAmount = vm.load(address(atr), bytes32(uint256(assetStructSlot) + 2));
        assertEq(uint256(assetAmount), 0);
	}

	function test_shouldBurnATRToken_whenWithBurnFlag() external {
		wallet.transferAtrTokenFrom(address(wallet), alice, atrId);

		vm.prank(alice);
		atr.transferAssetFrom(address(walletOther), atrId, true);

		vm.expectRevert("ERC721: invalid token ID");
		atr.ownerOf(atrId);
	}

	function test_shouldTransferAssetToAnyWallet_whenWithBurnFlag() external {
		wallet.transferAtrTokenFrom(address(wallet), alice, atrId);

		vm.prank(alice);
		atr.transferAssetFrom(address(walletOther), atrId, true);

		assertEq(t721.ownerOf(42), alice);
	}
	// <--- With `burnToken` flag

}


/*----------------------------------------------------------*|
|*  # TRANSFER ASSET WITH PERMISSION FROM                   *|
|*----------------------------------------------------------*/

contract AssetTransferRights_TransferAssetWithPermissionFrom_Test is AssetTransferRightsTest {

	uint256 ownerPK = 1;
	uint256 ownerOtherPK = 2;
	address owner = vm.addr(ownerPK);
	address ownerOther = vm.addr(ownerOtherPK);
	PWNWallet walletOther;
	uint256 atrId;

	event RecipientPermissionRevoked(bytes32 indexed permissionHash);

	function setUp() external {
		superSetUp();

		walletOther = PWNWallet(factory.newWallet());

		atrId = _mint721();

		wallet.transferOwnership(owner);
		walletOther.transferOwnership(ownerOther);
	}

	// ---> Helpers
	function _mint20() internal returns (uint256) {
		t20.mint(address(walletOther), 600e18);

		uint256 _atrId = walletOther.mintAssetTransferRightsToken(
			MultiToken.Asset(MultiToken.Category.ERC20, address(t20), 0, 600e18)
		);

		return _atrId;
	}

	function _mint721() internal returns (uint256) {
		t721.mint(address(walletOther), 42);

		uint256 _atrId = walletOther.mintAssetTransferRightsToken(
			MultiToken.Asset(MultiToken.Category.ERC721, address(t721), 42, 1)
		);

		return _atrId;
	}

	function _mint1155() internal returns (uint256) {
		t1155.mint(address(walletOther), 42, 600);

		uint256 _atrId = walletOther.mintAssetTransferRightsToken(
			MultiToken.Asset(MultiToken.Category.ERC1155, address(t1155), 42, 600)
		);

		return _atrId;
	}

	function _signPermission(AssetTransferRights.RecipientPermission memory permission, uint256 privateKey) internal returns (bytes memory permissionSignature, bytes32 permissionHash) {
		permissionHash = atr.recipientPermissionHash(permission);
		(uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, permissionHash);
		permissionSignature = abi.encodePacked(r, s, v);
	}
	// <--- Helpers


	// ---> Basic checks
	function test_shouldFail_whenTokenRightsAreNotTokenized() external {
		AssetTransferRights.RecipientPermission memory permission = AssetTransferRights.RecipientPermission(
			owner, address(wallet), 0, keccak256("nonce")
		);
		(bytes memory permissionSignature, ) = _signPermission(permission, ownerPK);

		vm.expectRevert("Transfer rights are not tokenized");
		vm.prank(address(walletOther));
		atr.transferAssetWithPermissionFrom(address(walletOther), atrId + 1, false, permission, permissionSignature);
	}

	function test_shouldFail_whenSenderIsNotATRTokenOwner() external {
		AssetTransferRights.RecipientPermission memory permission = AssetTransferRights.RecipientPermission(
			owner, address(wallet), 0, keccak256("nonce")
		);
		(bytes memory permissionSignature, ) = _signPermission(permission, ownerPK);

		vm.expectRevert("Caller is not ATR token owner");
		vm.prank(owner);
		atr.transferAssetWithPermissionFrom(address(walletOther), atrId, false, permission, permissionSignature);
	}

	function test_shouldFail_whenAssetIsNotInWallet() external {
		AssetTransferRights.RecipientPermission memory permission = AssetTransferRights.RecipientPermission(
			owner, address(wallet), 0, keccak256("nonce")
		);

		(bytes memory permissionSignature, ) = _signPermission(permission, ownerPK);

		PWNWallet walletEmpty = PWNWallet(factory.newWallet());

		vm.expectRevert("Asset is not in a target wallet");
		vm.prank(address(walletOther));
		atr.transferAssetWithPermissionFrom(address(walletEmpty), atrId, false, permission, permissionSignature);
	}

	function test_shouldFail_whenTransferringToSameAddress() external {
		AssetTransferRights.RecipientPermission memory permission = AssetTransferRights.RecipientPermission(
			ownerOther, address(walletOther), 0, keccak256("nonce")
		);

		(bytes memory permissionSignature, ) = _signPermission(permission, ownerOtherPK);

		vm.expectRevert("Attempting to transfer asset to the same address");
		vm.prank(address(walletOther));
		atr.transferAssetWithPermissionFrom(address(walletOther), atrId, false, permission, permissionSignature);
	}
	// <--- Basic checks

	// ---> Process
	function test_shouldRemoveStoredTokenizedAssetInfoFromSendersWallet() external {
		AssetTransferRights.RecipientPermission memory permission = AssetTransferRights.RecipientPermission(
			owner, address(wallet), 0, keccak256("nonce")
		);
		(bytes memory permissionSignature, ) = _signPermission(permission, ownerPK);

		vm.prank(address(walletOther));
		atr.transferAssetWithPermissionFrom(address(walletOther), atrId, true, permission, permissionSignature);

		bytes32 setSize = vm.load(address(atr), _atrIdsSetSlotFor(address(walletOther)));
		bytes32 valuesSlot = _atrIdsValuesSlotFor(address(walletOther));

		bool find;
		for (uint256 i; i < uint256(setSize); ++i) {
			bytes32 storedId = vm.load(address(atr), bytes32(uint256(valuesSlot) + i));
			if (uint256(storedId) == atrId) {
				find = true;
				break;
			}
		}

		if (find) {
			revert("ATR token is stored after transferAssetWithPermissionFrom");
		}
	}

	function test_shouldRevokePermission() external {
		AssetTransferRights.RecipientPermission memory permission = AssetTransferRights.RecipientPermission(
			owner, address(wallet), 0, keccak256("nonce")
		);
		(bytes memory permissionSignature, bytes32 permissionHash) = _signPermission(permission, ownerPK);

		vm.prank(address(walletOther));
		atr.transferAssetWithPermissionFrom(address(walletOther), atrId, true, permission, permissionSignature);

		bytes32 permissionSlot = _revokedPermissionsSlotFor(permissionHash);
		bytes32 isRevoked = vm.load(address(atr), permissionSlot);

		assertEq(uint256(isRevoked), 1);
	}
	// <--- Process

	// ---> Permission checks
	function test_shouldFail_whenPermissionIsExpired() external {
		AssetTransferRights.RecipientPermission memory permission = AssetTransferRights.RecipientPermission(
			owner, address(wallet), 1, keccak256("nonce")
		);
		(bytes memory permissionSignature, bytes32 permissionHash) = _signPermission(permission, ownerPK);

		bytes32 revokedPermissionSlot = _revokedPermissionsSlotFor(permissionHash);
		vm.store(address(atr), revokedPermissionSlot, bytes32(uint256(1)));

		vm.expectRevert("Recipient permission is expired");
		vm.prank(address(walletOther));
		atr.transferAssetWithPermissionFrom(address(walletOther), atrId, false, permission, permissionSignature);
	}

	function test_shouldFail_whenPermissionIsRevoked() external {
		AssetTransferRights.RecipientPermission memory permission = AssetTransferRights.RecipientPermission(
			owner, address(wallet), 0, keccak256("nonce")
		);
		(bytes memory permissionSignature, bytes32 permissionHash) = _signPermission(permission, ownerPK);

		bytes32 revokedPermissionSlot = _revokedPermissionsSlotFor(permissionHash);
		vm.store(address(atr), revokedPermissionSlot, bytes32(uint256(1)));

		vm.expectRevert("Recipient permission is revoked");
		vm.prank(address(walletOther));
		atr.transferAssetWithPermissionFrom(address(walletOther), atrId, false, permission, permissionSignature);
	}

	function test_shouldFail_whenPermissionNotSignedByStatedEOAWalletOwner() external {
		AssetTransferRights.RecipientPermission memory permission = AssetTransferRights.RecipientPermission(
			owner, address(wallet), 0, keccak256("nonce")
		);
		(bytes memory permissionSignature, ) = _signPermission(permission, ownerOtherPK);

		vm.expectRevert("Permission signer is not stated as wallet owner");
		vm.prank(address(walletOther));
		atr.transferAssetWithPermissionFrom(address(walletOther), atrId, false, permission, permissionSignature);
	}

	function test_shouldFail_whenPermissionNotSignedByStatedContractWalletOwner() external {
		vm.prank(owner);
		ContractWallet contractWallet = new ContractWallet();

		vm.prank(owner);
		wallet.transferOwnership(address(contractWallet));

		AssetTransferRights.RecipientPermission memory permission = AssetTransferRights.RecipientPermission(
			address(contractWallet), address(wallet), 0, keccak256("nonce")
		);
		(bytes memory permissionSignature, ) = _signPermission(permission, ownerOtherPK);

		vm.expectRevert("Signature on behalf of contract is invalid");
		vm.prank(address(walletOther));
		atr.transferAssetWithPermissionFrom(address(walletOther), atrId, false, permission, permissionSignature);
	}

	function test_shouldFail_whenStatedWalletOwnerIsNotRealOwner() external {
		vm.prank(owner);
		wallet.transferOwnership(alice);

		AssetTransferRights.RecipientPermission memory permission = AssetTransferRights.RecipientPermission(
			owner, address(wallet), 0, keccak256("nonce")
		);
		(bytes memory permissionSignature, ) = _signPermission(permission, ownerPK);

		vm.expectRevert("Permission signer is not wallet owner");
		vm.prank(address(walletOther));
		atr.transferAssetWithPermissionFrom(address(walletOther), atrId, false, permission, permissionSignature);
	}

	function test_shouldEmitRecipientPermissionRevokedEvent() external {
		AssetTransferRights.RecipientPermission memory permission = AssetTransferRights.RecipientPermission(
			owner, address(wallet), 0, keccak256("nonce")
		);
		(bytes memory permissionSignature, bytes32 permissionHash) = _signPermission(permission, ownerPK);

		vm.expectEmit(true, false, false, false);
		emit RecipientPermissionRevoked(permissionHash);

		vm.prank(address(walletOther));
		atr.transferAssetWithPermissionFrom(address(walletOther), atrId, false, permission, permissionSignature);
	}
	// <--- Permission checks

	// ---> EOA caller
	function test_shouldTransferERC20Asset_whenCallerIsEOA() external {
		AssetTransferRights.RecipientPermission memory permission = AssetTransferRights.RecipientPermission(
			owner, address(wallet), 0, keccak256("nonce")
		);
		(bytes memory permissionSignature, ) = _signPermission(permission, ownerPK);

		vm.startPrank(ownerOther);
		atrId = _mint20();
		walletOther.transferAtrTokenFrom(address(walletOther), alice, atrId);
		vm.stopPrank();

		vm.prank(alice);
		atr.transferAssetWithPermissionFrom(address(walletOther), atrId, false, permission, permissionSignature);

		assertEq(t20.balanceOf(address(wallet)), 600e18);
		assertEq(t20.balanceOf(address(walletOther)), 0);
	}

	function test_shouldTransferERC721Asset_whenCallerIsEOA() external {
		AssetTransferRights.RecipientPermission memory permission = AssetTransferRights.RecipientPermission(
			owner, address(wallet), 0, keccak256("nonce")
		);
		(bytes memory permissionSignature, ) = _signPermission(permission, ownerPK);

		vm.prank(ownerOther);
		walletOther.transferAtrTokenFrom(address(walletOther), alice, atrId);

		vm.prank(alice);
		atr.transferAssetWithPermissionFrom(address(walletOther), atrId, false, permission, permissionSignature);

		assertEq(t721.ownerOf(42), address(wallet));
	}

	function test_shouldTransferERC1155Asset_whenCallerIsEOA() external {
		AssetTransferRights.RecipientPermission memory permission = AssetTransferRights.RecipientPermission(
			owner, address(wallet), 0, keccak256("nonce")
		);
		(bytes memory permissionSignature, ) = _signPermission(permission, ownerPK);

		vm.startPrank(ownerOther);
		atrId = _mint1155();
		walletOther.transferAtrTokenFrom(address(walletOther), alice, atrId);
		vm.stopPrank();

		vm.prank(alice);
		atr.transferAssetWithPermissionFrom(address(walletOther), atrId, false, permission, permissionSignature);

		assertEq(t1155.balanceOf(address(wallet), 42), 600);
		assertEq(t1155.balanceOf(address(walletOther), 42), 0);
	}
	// <--- EOA caller

	// ---> Contract wallet caller
	function test_shouldTransferERC20Asset_whenCallerIsContractWallet() external {
		AssetTransferRights.RecipientPermission memory permission = AssetTransferRights.RecipientPermission(
			owner, address(wallet), 0, keccak256("nonce")
		);
		(bytes memory permissionSignature, ) = _signPermission(permission, ownerPK);

		ContractWallet contractWallet = new ContractWallet();

		vm.startPrank(ownerOther);
		atrId = _mint20();
		walletOther.transferAtrTokenFrom(address(walletOther), address(contractWallet), atrId);
		vm.stopPrank();

		vm.prank(address(contractWallet));
		atr.transferAssetWithPermissionFrom(address(walletOther), atrId, false, permission, permissionSignature);

		assertEq(t20.balanceOf(address(wallet)), 600e18);
		assertEq(t20.balanceOf(address(walletOther)), 0);
	}

	function test_shouldTransferERC721Asset_whenCallerIsContractWallet() external {
		AssetTransferRights.RecipientPermission memory permission = AssetTransferRights.RecipientPermission(
			owner, address(wallet), 0, keccak256("nonce")
		);
		(bytes memory permissionSignature, ) = _signPermission(permission, ownerPK);

		ContractWallet contractWallet = new ContractWallet();

		vm.prank(ownerOther);
		walletOther.transferAtrTokenFrom(address(walletOther), address(contractWallet), atrId);

		vm.prank(address(contractWallet));
		atr.transferAssetWithPermissionFrom(address(walletOther), atrId, false, permission, permissionSignature);

		assertEq(t721.ownerOf(42), address(wallet));
	}

	function test_shouldTransferERC1155Asset_whenCallerIsContractWallet() external {
		AssetTransferRights.RecipientPermission memory permission = AssetTransferRights.RecipientPermission(
			owner, address(wallet), 0, keccak256("nonce")
		);
		(bytes memory permissionSignature, ) = _signPermission(permission, ownerPK);

		ContractWallet contractWallet = new ContractWallet();

		vm.startPrank(ownerOther);
		atrId = _mint1155();
		walletOther.transferAtrTokenFrom(address(walletOther), address(contractWallet), atrId);
		vm.stopPrank();

		vm.prank(address(contractWallet));
		atr.transferAssetWithPermissionFrom(address(walletOther), atrId, false, permission, permissionSignature);

		assertEq(t1155.balanceOf(address(wallet), 42), 600);
		assertEq(t1155.balanceOf(address(walletOther), 42), 0);
	}
	// <--- Contract wallet caller

	// ---> Without `burnToken` flag
	function test_shouldStoreThatRecipientHasTokenizedAsset_whenWithoutBurnFlag() external {
		AssetTransferRights.RecipientPermission memory permission = AssetTransferRights.RecipientPermission(
			owner, address(wallet), 0, keccak256("nonce")
		);
		(bytes memory permissionSignature, ) = _signPermission(permission, ownerPK);

		vm.prank(address(walletOther));
		atr.transferAssetWithPermissionFrom(address(walletOther), atrId, false, permission, permissionSignature);

		bytes32 setSize = vm.load(address(atr), _atrIdsSetSlotFor(address(wallet)));
		bytes32 valuesSlot = _atrIdsValuesSlotFor(address(wallet));

		bool find;
		for (uint256 i; i < uint256(setSize); ++i) {
			bytes32 storedId = vm.load(address(atr), bytes32(uint256(valuesSlot) + i));
			if (uint256(storedId) == atrId) {
				find = true;
				break;
			}
		}

		if (!find) {
			revert("ATR token is not stored after transferAssetFrom");
		}
	}

	function test_shouldFail_whenRecipientHasApprovalForAsset_whenWithoutBurnFlag() external {
		AssetTransferRights.RecipientPermission memory permission = AssetTransferRights.RecipientPermission(
			owner, address(wallet), 0, keccak256("nonce")
		);
		(bytes memory permissionSignature, ) = _signPermission(permission, ownerPK);

		vm.mockCall(
			address(wallet),
			abi.encodeWithSelector(wallet.hasApprovalsFor.selector),
			abi.encode(true)
		);

		vm.expectRevert("Receiver has approvals set for an asset");
		vm.prank(address(walletOther));
		atr.transferAssetWithPermissionFrom(address(walletOther), atrId, false, permission, permissionSignature);
	}

	function test_shouldFail_whenTransferringToNotPWNWallet_whenWithoutBurnFlag() external {
		AssetTransferRights.RecipientPermission memory permission = AssetTransferRights.RecipientPermission(
			owner, owner, 0, keccak256("nonce")
		);
		(bytes memory permissionSignature, ) = _signPermission(permission, ownerPK);

		vm.expectRevert("Attempting to transfer asset to non PWN Wallet address");
		vm.prank(address(walletOther));
		atr.transferAssetWithPermissionFrom(address(walletOther), atrId, false, permission, permissionSignature);
	}
	// <--- Without `burnToken` flag

	// ---> With `burnToken` flag
	function test_shouldClearStoredTokenizedAssetData_whenWithBurnFlag() external {
		AssetTransferRights.RecipientPermission memory permission = AssetTransferRights.RecipientPermission(
			owner, address(wallet), 0, keccak256("nonce")
		);
		(bytes memory permissionSignature, ) = _signPermission(permission, ownerPK);

		vm.prank(address(walletOther));
		atr.transferAssetWithPermissionFrom(address(walletOther), atrId, true, permission, permissionSignature);

		bytes32 assetStructSlot = _assetStructSlotFor(atrId);

		// Category + address
		bytes32 addrAndCategory = vm.load(address(atr), bytes32(uint256(assetStructSlot) + 0));
        assertEq(uint256(addrAndCategory), 0);
        // Id
        bytes32 assetId = vm.load(address(atr), bytes32(uint256(assetStructSlot) + 1));
        assertEq(uint256(assetId), 0);
        // Amount
        bytes32 assetAmount = vm.load(address(atr), bytes32(uint256(assetStructSlot) + 2));
        assertEq(uint256(assetAmount), 0);
	}

	function test_shouldBurnATRToken_whenWithBurnFlag() external {
		AssetTransferRights.RecipientPermission memory permission = AssetTransferRights.RecipientPermission(
			owner, address(wallet), 0, keccak256("nonce")
		);
		(bytes memory permissionSignature, ) = _signPermission(permission, ownerPK);

		vm.prank(address(walletOther));
		atr.transferAssetWithPermissionFrom(address(walletOther), atrId, true, permission, permissionSignature);

		vm.expectRevert("ERC721: invalid token ID");
		atr.ownerOf(atrId);
	}

	function test_shouldTransferAssetToAnyWallet_whenWithBurnFlag() external {
		AssetTransferRights.RecipientPermission memory permission = AssetTransferRights.RecipientPermission(
			owner, owner, 0, keccak256("nonce")
		);
		(bytes memory permissionSignature, ) = _signPermission(permission, ownerPK);

		vm.prank(address(walletOther));
		atr.transferAssetWithPermissionFrom(address(walletOther), atrId, true, permission, permissionSignature);

		assertEq(t721.ownerOf(42), owner);
	}
	// <--- With `burnToken` flag
}


/*----------------------------------------------------------*|
|*  # REVOKE RECIPIENT PERMISSION                           *|
|*----------------------------------------------------------*/

contract AssetTransferRights_RevokeRecipientPermission_Test is AssetTransferRightsTest {

	uint256 ownerPK = 1;
	address owner = vm.addr(ownerPK);
	bytes32 permissionHash;
	bytes permissionSignature;

	event RecipientPermissionRevoked(bytes32 indexed permissionHash);

	function setUp() external {
		superSetUp();

		AssetTransferRights.RecipientPermission memory permission = AssetTransferRights.RecipientPermission(
			owner, address(wallet), 0, keccak256("nonce")
		);
		permissionHash = atr.recipientPermissionHash(permission);
		(uint8 v, bytes32 r, bytes32 s) = vm.sign(ownerPK, permissionHash);
		permissionSignature = abi.encodePacked(r, s, v);
	}


	function test_shouldFail_whenCallerIsNotPermissionSigned() external {
		vm.expectRevert("Sender is not a recipient permission signer");
		vm.prank(alice);
		atr.revokeRecipientPermission(permissionHash, permissionSignature);
	}

	function test_shouldFail_whenPermissionIsRevoked() external {
		bytes32 revokedPermissionSlot = _revokedPermissionsSlotFor(permissionHash);
		vm.store(address(atr), revokedPermissionSlot, bytes32(uint256(1)));

		vm.expectRevert("Recipient permission is revoked");
		vm.prank(owner);
		atr.revokeRecipientPermission(permissionHash, permissionSignature);
	}

	function test_shouldRevokePermission() external {
		vm.prank(owner);
		atr.revokeRecipientPermission(permissionHash, permissionSignature);

		bytes32 revokedPermissionSlot = _revokedPermissionsSlotFor(permissionHash);
		bytes32 isRevoked = vm.load(address(atr), revokedPermissionSlot);

		assertEq(uint256(isRevoked), 1);
	}

	function test_shouldEmitRecipientPermissionRevokedEvent() external {
		vm.expectEmit(true, false, false, false);
		emit RecipientPermissionRevoked(permissionHash);

		vm.prank(owner);
		atr.revokeRecipientPermission(permissionHash, permissionSignature);
	}

}


/*----------------------------------------------------------*|
|*  # CHECK TOKENIZED BALANCE                               *|
|*----------------------------------------------------------*/

contract AssetTransferRights_CheckTokenizedBalance_Test is AssetTransferRightsTest {

	function setUp() external {
		superSetUp();
	}


	function test_shouldFail_whenInsufficientBalanceOfFungibleAsset() external {
		t20.mint(address(wallet), 300e18);

		vm.prank(address(wallet));
		atr.mintAssetTransferRightsToken(
			MultiToken.Asset(MultiToken.Category.ERC20, address(t20), 0, 300e18)
		);

		vm.mockCall(
			address(t20),
			abi.encodeWithSelector(t20.balanceOf.selector),
			abi.encode(uint256(100e18))
		);

		vm.expectRevert("Insufficient tokenized balance");
		atr.checkTokenizedBalance(address(wallet));
	}

	function test_shouldFail_whenMissingTokenizedNonFungibleAsset() external {
		t721.mint(address(wallet), 42);

		vm.prank(address(wallet));
		atr.mintAssetTransferRightsToken(
			MultiToken.Asset(MultiToken.Category.ERC721, address(t721), 42, 1)
		);

		vm.mockCall(
			address(t721),
			abi.encodeWithSelector(t721.ownerOf.selector),
			abi.encode(address(alice))
		);

		vm.expectRevert("Insufficient tokenized balance");
		atr.checkTokenizedBalance(address(wallet));
	}

	function test_shouldFail_whenInsufficientBalanceOfSemifungibleAsset() external {
		t1155.mint(address(wallet), 42, 300);

		vm.prank(address(wallet));
		atr.mintAssetTransferRightsToken(
			MultiToken.Asset(MultiToken.Category.ERC1155, address(t1155), 42, 300)
		);

		vm.mockCall(
			address(t1155),
			abi.encodeWithSelector(t1155.balanceOf.selector),
			abi.encode(uint256(100))
		);

		vm.expectRevert("Insufficient tokenized balance");
		atr.checkTokenizedBalance(address(wallet));
	}

	function test_shouldPass_whenSufficientBalanceOfFungibleAsset() external {
		t20.mint(address(wallet), 300e18);

		vm.prank(address(wallet));
		atr.mintAssetTransferRightsToken(
			MultiToken.Asset(MultiToken.Category.ERC20, address(t20), 0, 300e18)
		);

		vm.mockCall(
			address(t20),
			abi.encodeWithSelector(t20.balanceOf.selector),
			abi.encode(uint256(500e18))
		);

		atr.checkTokenizedBalance(address(wallet));
	}

	function test_shouldPass_whenHoldingTokenizedNonFungibleAsset() external {
		t721.mint(address(wallet), 42);

		vm.prank(address(wallet));
		atr.mintAssetTransferRightsToken(
			MultiToken.Asset(MultiToken.Category.ERC721, address(t721), 42, 1)
		);

		atr.checkTokenizedBalance(address(wallet));
	}

	function test_shouldPass_whenSufficientBalanceOfSemifungibleAsset() external {
		t1155.mint(address(wallet), 42, 300);

		vm.prank(address(wallet));
		atr.mintAssetTransferRightsToken(
			MultiToken.Asset(MultiToken.Category.ERC1155, address(t1155), 42, 300)
		);

		vm.mockCall(
			address(t1155),
			abi.encodeWithSelector(t1155.balanceOf.selector),
			abi.encode(uint256(400))
		);

		atr.checkTokenizedBalance(address(wallet));
	}

}


/*----------------------------------------------------------*|
|*  # RECOVER INVALID TOKENIZED BALANCE                     *|
|*----------------------------------------------------------*/

contract AssetTransferRights_RecoverInvalidTokenizedBalance_Test is AssetTransferRightsTest {

	function setUp() external {
		superSetUp();
	}


	function test_shouldFail_whenWalletIsNotATRTokenOwner() external {
		vm.expectRevert("Asset is not in callers wallet");
		vm.prank(address(wallet));
		atr.recoverInvalidTokenizedBalance(12);
	}

	function test_shouldFail_whenTokenizedBalanceIsNotSmallerThenActualBalance() external {
		t721.mint(address(wallet), 42);

		vm.prank(address(wallet));
		uint256 atrId = atr.mintAssetTransferRightsToken(
			MultiToken.Asset(MultiToken.Category.ERC721, address(t721), 42, 1)
		);

		vm.expectRevert("Tokenized balance is not invalid");
		vm.prank(address(wallet));
		atr.recoverInvalidTokenizedBalance(atrId);
	}

	function test_shouldDecreaseTokenizedBalance() external {
		t20.mint(address(wallet), 500e18);

		vm.prank(address(wallet));
		uint256 atrId = atr.mintAssetTransferRightsToken(
			MultiToken.Asset(MultiToken.Category.ERC20, address(t20), 0, 300e18)
		);

		vm.prank(address(wallet));
		atr.mintAssetTransferRightsToken(
			MultiToken.Asset(MultiToken.Category.ERC20, address(t20), 0, 200e18)
		);

		vm.mockCall(
			address(t20),
			abi.encodeWithSelector(t20.balanceOf.selector),
			abi.encode(uint256(200e18))
		);

		vm.prank(address(wallet));
		atr.recoverInvalidTokenizedBalance(atrId);

		bytes32 tokenizedBalance = vm.load(
			address(atr),
			_tokenizedBalanceSlotFor(address(wallet), address(t20), 0)
		);
		assertEq(uint256(tokenizedBalance), 200e18);
	}

	function test_shouldRemoveATRTokenFromWallet() external {
		t721.mint(address(wallet), 42);

		vm.prank(address(wallet));
		uint256 atrId = atr.mintAssetTransferRightsToken(
			MultiToken.Asset(MultiToken.Category.ERC721, address(t721), 42, 1)
		);

		vm.mockCall(
			address(t721),
			abi.encodeWithSelector(t721.ownerOf.selector),
			abi.encode(alice)
		);

		vm.prank(address(wallet));
		atr.recoverInvalidTokenizedBalance(atrId);

		bytes32 setSize = vm.load(address(atr), _atrIdsSetSlotFor(address(wallet)));
		bytes32 valuesSlot = _atrIdsValuesSlotFor(address(wallet));

		for (uint256 i; i < uint256(setSize); ++i) {
			bytes32 storedId = vm.load(address(atr), bytes32(uint256(valuesSlot) + i));
			if (uint256(storedId) == atrId) {
				revert("ATR token is stored after recover");
			}
		}
	}

}


/*----------------------------------------------------------*|
|*  # SET USE WHITELIST                                     *|
|*----------------------------------------------------------*/

contract AssetTransferRights_SetUseWhitelist_Test is AssetTransferRightsTest {

	function setUp() external {
		superSetUp();
	}


	function test_shouldFail_whenCallerIsNotOwner() external {
		vm.expectRevert("Ownable: caller is not the owner");
		vm.prank(alice);
		atr.setUseWhitelist(true);
	}

	function test_shouldSetUseWhitelistStoredValue() external {
		vm.store(address(atr), USE_WHITELIST_SLOT, bytes32(uint256(0)));

		atr.setUseWhitelist(true);

		assertEq(
			vm.load(address(atr), USE_WHITELIST_SLOT),
			bytes32(uint256(1))
		);
	}

}


/*----------------------------------------------------------*|
|*  # SET IS WHITELISTED                                    *|
|*----------------------------------------------------------*/

contract AssetTransferRights_SetIsWhitelisted_Test is AssetTransferRightsTest {

	function setUp() external {
		superSetUp();
	}


	function test_shouldFail_whenCallerIsNotOwner() external {
		vm.expectRevert("Ownable: caller is not the owner");
		vm.prank(alice);
		atr.setIsWhitelisted(address(0x07), true);
	}

	function test_shouldSetIsWhitelistedMappingValue() external {
		address assetAddress = address(0x11223344aabbcc);
		vm.store(address(atr), _isWhitelistedSlotFor(assetAddress), bytes32(uint256(0)));

		atr.setIsWhitelisted(assetAddress, true);

		assertEq(
			vm.load(address(atr), _isWhitelistedSlotFor(assetAddress)),
			bytes32(uint256(1))
		);
	}

}


/*----------------------------------------------------------*|
|*  # GET ASSET                                             *|
|*----------------------------------------------------------*/

contract AssetTransferRights_GetAsset_Test is AssetTransferRightsTest {

	function setUp() external {
		superSetUp();
	}


	function test_shouldReturnStoredAsset() external {
		uint256 atrId = 14;
		bytes32 addrAndCategory = (bytes32(uint256(uint160(alice))) << 8) | bytes32(uint256(1));
		bytes32 id = bytes32(uint256(42));
		bytes32 amount = bytes32(uint256(300));

		// Mock asset
		bytes32 assetSlot = _assetStructSlotFor(atrId);
		vm.store(address(atr), bytes32(uint256(assetSlot) + 0), addrAndCategory);
		vm.store(address(atr), bytes32(uint256(assetSlot) + 1), id);
		vm.store(address(atr), bytes32(uint256(assetSlot) + 2), amount);

		MultiToken.Asset memory asset = atr.getAsset(atrId);

		assertEq(asset.category == MultiToken.Category.ERC721, true);
		assertEq(asset.assetAddress == alice, true);
		assertEq(asset.id == uint256(id), true);
		assertEq(asset.amount == uint256(amount), true);
	}

}


/*----------------------------------------------------------*|
|*  # OWNED ASSET ATR IDS                                   *|
|*----------------------------------------------------------*/

contract AssetTransferRights_OwnedAssetATRIds_Test is AssetTransferRightsTest {

	function setUp() external {
		superSetUp();
	}


	function test_shouldReturnListOfTokenizedAssetsInSendersWalletRepresentedByATRTokenIds() external {
		// Mock number of items
		bytes32 idsSlot = _atrIdsSetSlotFor(alice);
		vm.store(address(atr), idsSlot, bytes32(uint256(3)));

		// Mock items
		bytes32 valuesSlot = _atrIdsValuesSlotFor(alice);
		vm.store(address(atr), bytes32(uint256(valuesSlot) + 0), bytes32(uint256(32)));
		vm.store(address(atr), bytes32(uint256(valuesSlot) + 1), bytes32(uint256(83)));
		vm.store(address(atr), bytes32(uint256(valuesSlot) + 2), bytes32(uint256(98321)));

		uint256[] memory ids = atr.ownedAssetATRIds(alice);

		assertEq(ids[0], 32);
		assertEq(ids[1], 83);
		assertEq(ids[2], 98321);
	}

}


/*----------------------------------------------------------*|
|*  # OWNED FROM COLLECTION                                 *|
|*----------------------------------------------------------*/

contract AssetTransferRights_OwnedFromCollection_Test is AssetTransferRightsTest {

	function setUp() external {
		superSetUp();
	}


	function test_shouldReturnNumberOfTokenizedAssetsFromGivenContractAddress() external {
		// Mock owned assets from collection
		bytes32 ownedFromCollectionSlot = _ownedFromCollectionSlotFor(alice, address(0x1234));
		vm.store(address(atr), ownedFromCollectionSlot, bytes32(uint256(4)));

		uint256 ownedAssetsFromCollection = atr.ownedFromCollection(alice, address(0x1234));

		assertEq(ownedAssetsFromCollection, 4);
	}

}


/*----------------------------------------------------------*|
|*  # RECIPIENT PERMISSION HASH                             *|
|*----------------------------------------------------------*/

contract AssetTransferRights_RecipientPermissionHash_Test is AssetTransferRightsTest {

	function setUp() external {
		superSetUp();
	}


	function test_shouldReturnRecipientPermissionTypedStructHash() external {
		bytes32 hash = bytes32(0x23d078422db7a423860f681ae629d66abc333d56a38cf0120b7027c7dbcdf20a);
		AssetTransferRights.RecipientPermission memory permission = AssetTransferRights.RecipientPermission(
			alice, address(wallet), 1, keccak256("nonce")
		);

		bytes32 permissionHash = atr.recipientPermissionHash(permission);

		assertEq(permissionHash, hash);
	}

}

// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.15;

import "forge-std/Test.sol";

import "@openzeppelin/interfaces/IERC20.sol";
import "@openzeppelin/interfaces/IERC721.sol";
import "@openzeppelin/interfaces/IERC1155.sol";

import "MultiToken/MultiToken.sol";

import "@pwn-safe/module/AssetTransferRights.sol";

import "@pwn-safe-test/helpers/TokenizedAssetManagerStorageHelper.sol";


abstract contract AssetTransferRightsTest is TokenizedAssetManagerStorageHelper {

	bytes32 internal constant GRANTED_PERMISSION_SLOT = bytes32(uint256(6)); // `grantedPermissions` mapping position
	bytes32 internal constant REVOKED_PERMISSION_NONCE_SLOT = bytes32(uint256(7)); // `revokedPermissionNonces` mapping position
	bytes32 internal constant ATR_TOKEN_OWNER_SLOT = bytes32(uint256(10)); // `_owners` ERC721 mapping position
	bytes32 internal constant ATR_TOKEN_BALANCES_SLOT = bytes32(uint256(11)); // `_balances` ERC721 mapping position
	bytes32 internal constant LAST_TOKEN_ID_SLOT = bytes32(uint256(14)); // `lastTokenId` property position

	event TransferViaATR(address indexed from, address indexed to, uint256 indexed atrTokenId, MultiToken.Asset asset);

	AssetTransferRights atr;
	address payable safe = payable(address(0xff));
	address token = address(0x070ce2);
	address alice = address(0xa11ce);
	address bob = address(0xb0b);
	address guard = address(0x1111);
	address safeValidator = address(0x2222);
	address whitelist = makeAddr("whitelist");

	uint256 erc20Amount = 100e18;
	uint256 erc1155Amount = 100;

	constructor() {
		vm.etch(guard, bytes("data"));
		vm.etch(safeValidator, bytes("data"));
		vm.etch(token, bytes("data"));
	}

	function setUp() virtual public {
		atr = new AssetTransferRights(whitelist);
		setAtr(address(atr));

		atr.initialize(safeValidator, guard);

		_mockDependencyContracts();
	}


	function _mockToken(MultiToken.Category category) internal {
		vm.clearMockedCalls();

		_mockDependencyContracts();

		if (category == MultiToken.Category.ERC721 || category == MultiToken.Category.ERC1155) {
			vm.mockCall(
				token,
				abi.encodeWithSignature("supportsInterface(bytes4)", bytes4(0xffffffff)),
				abi.encode(false)
			);
			vm.mockCall(
				token,
				abi.encodeWithSignature("supportsInterface(bytes4)", bytes4(0x01ffc9a7)),
				abi.encode(true)
			);
		}

		if (category == MultiToken.Category.ERC20) {
			vm.mockCall(
				token,
				abi.encodeWithSignature("balanceOf(address)"),
				abi.encode(erc20Amount)
			);
		} else if (category == MultiToken.Category.ERC721) {
			vm.mockCall(
				token,
				abi.encodeWithSignature("getApproved(uint256)"),
				abi.encode(0)
			);
			vm.mockCall(
				token,
				abi.encodeWithSignature("ownerOf(uint256)"),
				abi.encode(safe)
			);
			vm.mockCall(
				token,
				abi.encodeWithSignature("supportsInterface(bytes4)", type(IERC721).interfaceId),
				abi.encode(true)
			);
		} else if (category == MultiToken.Category.ERC1155) {
			vm.mockCall(
				token,
				abi.encodeWithSignature("balanceOf(address,uint256)"),
				abi.encode(erc1155Amount)
			);
			vm.mockCall(
				token,
				abi.encodeWithSignature("supportsInterface(bytes4)", type(IERC1155).interfaceId),
				abi.encode(true)
			);
		} else if (category == MultiToken.Category.CryptoKitties) {
			vm.mockCall(
				token,
				abi.encodeWithSignature("supportsInterface(bytes4)", bytes4(0x9a20483d)),
				abi.encode(true)
			);
		}
	}


	function _mockDependencyContracts() private {
		vm.mockCall(
			guard,
			abi.encodeWithSignature("hasOperatorFor(address,address)"),
			abi.encode(false)
		);
		vm.mockCall(
			safeValidator,
			abi.encodeWithSignature("isValidSafe(address)", safe),
			abi.encode(true)
		);
		vm.mockCall(
			safeValidator,
			abi.encodeWithSignature("isValidSafe(address)"),
			abi.encode(false)
		);
		vm.mockCall(
			whitelist,
			abi.encodeWithSignature("canBeTokenized(address)"),
			abi.encode(true)
		);
	}

}


/*----------------------------------------------------------*|
|*  # CONSTRUCTOR                                           *|
|*----------------------------------------------------------*/

contract AssetTransferRights_Constructor_Test is AssetTransferRightsTest {

	function test_shouldSetCorrectMetadata() external {
		atr = new AssetTransferRights(whitelist);

		bytes32 nameValue = vm.load(address(atr), bytes32(uint256(8)));
		bytes32 symbolValue = vm.load(address(atr), bytes32(uint256(9)));
		// Asset Transfer Rights
		assertEq(nameValue, 0x4173736574205472616e7366657220526967687473000000000000000000002a);
		// ATR
		assertEq(symbolValue, 0x4154520000000000000000000000000000000000000000000000000000000006);
	}

	function test_shouldStoreParameters() external {
		address otherWhitelist = makeAddr("other whitelist");

		atr = new AssetTransferRights(otherWhitelist);

		bytes32 whitelistValue = vm.load(address(atr), bytes32(uint256(17)));
		assertEq(whitelistValue, bytes32(uint256(uint160(otherWhitelist))));
	}

}


/*----------------------------------------------------------*|
|*  # INITIALIZABLE                                         *|
|*----------------------------------------------------------*/

contract AssetTransferRights_Initialize_Test is AssetTransferRightsTest {

	function setUp() override public {
		atr = new AssetTransferRights(whitelist);
	}


	function test_shouldStoreParameters() external {
		atr.initialize(safeValidator, guard);

		bytes32 safeValidatorValue = vm.load(address(atr), bytes32(uint256(15)));
		bytes32 guardValue = vm.load(address(atr), bytes32(uint256(16)));
		assertEq(safeValidatorValue, bytes32(uint256(uint160(safeValidator))));
		assertEq(guardValue, bytes32(uint256(uint160(guard))));
	}

	function test_shouldFail_whenCalledTwice() external {
		atr.initialize(safeValidator, guard);

		vm.expectRevert("Initializable: contract is already initialized");
		atr.initialize(safeValidator, guard);
	}

	function test_shouldSetContractAsInitialized() external {
		atr.initialize(safeValidator, guard);

		// `_initialized` valus is stored in the first slot with 20 bytes offset and take 1 byte
		uint256 initializedValue = uint256(vm.load(address(atr), bytes32(uint256(0))) >> 160) & 0xff;
		assertEq(initializedValue, 1);
	}

}


/*----------------------------------------------------------*|
|*  # MINT ASSET TRANSFER RIGHTS TOKEN                      *|
|*----------------------------------------------------------*/

contract AssetTransferRights_MintAssetTransferRightsToken_Test is AssetTransferRightsTest {

	// ---> Basic checks
	function test_shouldFail_whenCallerIsNotPWNSafe() external {
		_mockToken(MultiToken.Category.ERC721);

		vm.expectRevert("Caller is not a PWNSafe");
		vm.prank(alice);
		atr.mintAssetTransferRightsToken(MultiToken.ERC721(token, 42));
	}

	function test_shouldFail_whenZeroAddressAsset() external {
		_mockToken(MultiToken.Category.ERC721);

		vm.expectRevert("Asset is not valid");
		vm.prank(safe);
		atr.mintAssetTransferRightsToken(MultiToken.ERC721(address(0), 42));
	}

	function test_shouldFail_whenATRToken() external {
		_mockToken(MultiToken.Category.ERC721);

		vm.expectRevert("Attempting to tokenize ATR token");
		vm.prank(safe);
		atr.mintAssetTransferRightsToken(MultiToken.ERC721(address(atr), 42));
	}

	function test_shouldFail_whenUsingWhitelist_whenAssetIsNotWhitelisted() external {
		_mockToken(MultiToken.Category.ERC721);
		vm.mockCall(
			whitelist,
			abi.encodeWithSignature("canBeTokenized(address)", token),
			abi.encode(false)
		);

		vm.expectRevert("Asset is not whitelisted");
		vm.prank(safe);
		atr.mintAssetTransferRightsToken(MultiToken.ERC721(token, 42));
	}

	function test_shouldPass_whenUsingWhitelist_whenAssetWhitelisted() external {
		_mockToken(MultiToken.Category.ERC721);
		vm.mockCall(
			whitelist,
			abi.encodeWithSignature("canBeTokenized(address)", token),
			abi.encode(true)
		);

		vm.prank(safe);
		atr.mintAssetTransferRightsToken(MultiToken.ERC721(token, 42));
	}

	function test_shouldFail_whenNotAssetOwner() external {
		_mockToken(MultiToken.Category.ERC721);
		vm.mockCall(
			token,
			abi.encodeWithSignature("ownerOf(uint256)"),
			abi.encode(alice)
		);

		vm.expectRevert("Insufficient balance to tokenize");
		vm.prank(safe);
		atr.mintAssetTransferRightsToken(MultiToken.ERC721(token, 42));
	}

	function test_shouldFail_whenInvalidMultiTokenAsset() external {
		_mockToken(MultiToken.Category.ERC721);

		vm.expectRevert("Asset is not valid");
		vm.prank(safe);
		atr.mintAssetTransferRightsToken(MultiToken.Asset(MultiToken.Category.ERC721, token, 42, 1));
	}
	// <--- Basic checks

	// ---> Insufficient balance
	function test_shouldFail_whenERC20HasNotEnoughtBalance() external {
		_mockToken(MultiToken.Category.ERC20);

		vm.expectRevert("Insufficient balance to tokenize");
		vm.prank(safe);
		atr.mintAssetTransferRightsToken(MultiToken.ERC20(token, erc20Amount + 1e18));
	}

	function test_shouldFail_whenERC20HasNotEnoughtUntokenizedBalance() external {
		MultiToken.Asset memory asset = MultiToken.ERC20(token, erc20Amount - 20e18);
		_tokenizeAssetUnderId(safe, 1, asset);
		_mockToken(MultiToken.Category.ERC20);

		vm.expectRevert("Insufficient balance to tokenize");
		vm.prank(safe);
		atr.mintAssetTransferRightsToken(MultiToken.ERC20(token, 21e18));
	}

	function test_shouldFail_whenERC721IsAlreadyTokenized() external {
		MultiToken.Asset memory asset = MultiToken.ERC721(token, 42);
		_tokenizeAssetUnderId(safe, 1, asset);
		_mockToken(MultiToken.Category.ERC721);

		vm.expectRevert("Insufficient balance to tokenize");
		vm.prank(safe);
		atr.mintAssetTransferRightsToken(MultiToken.ERC721(token, 42));
	}

	function test_shouldFail_whenERC1155HasNotEnoughtBalance() external {
		_mockToken(MultiToken.Category.ERC1155);

		vm.expectRevert("Insufficient balance to tokenize");
		vm.prank(safe);
		atr.mintAssetTransferRightsToken(MultiToken.ERC1155(token, 42, erc1155Amount + 10));
	}

	function test_shouldFail_whenERC1155HasNotEnoughtUntokenizedBalance() external {
		MultiToken.Asset memory asset = MultiToken.ERC1155(token, 42, erc1155Amount - 10);
		_tokenizeAssetUnderId(safe, 1, asset);
		_mockToken(MultiToken.Category.ERC1155);

		vm.expectRevert("Insufficient balance to tokenize");
		vm.prank(safe);
		atr.mintAssetTransferRightsToken(MultiToken.ERC1155(token, 42, 11));
	}
	// <--- Insufficient balance

	// ---> Approvals
	function test_shouldFail_whenAssetHasOperator() external {
		_mockToken(MultiToken.Category.ERC20);

		vm.mockCall(
			guard,
			abi.encodeWithSignature("hasOperatorFor(address,address)", safe, token),
			abi.encode(true)
		);

		vm.expectRevert("Some asset from collection has an approval");
		vm.prank(safe);
		atr.mintAssetTransferRightsToken(
			MultiToken.ERC20(token, erc20Amount)
		);
	}

	function test_shouldFail_whenERC721AssetIsApproved() external {
		_mockToken(MultiToken.Category.ERC721);

		vm.mockCall(
			token,
			abi.encodeWithSignature("getApproved(uint256)", 42),
			abi.encode(alice)
		);

		vm.expectRevert("Asset has an approved address");
		vm.prank(safe);
		atr.mintAssetTransferRightsToken(
			MultiToken.ERC721(token, 42)
		);
	}
	// <--- Approvals

	// ---> Asset category check
	function test_shouldFail_whenCryptoKitties() external {
		_mockToken(MultiToken.Category.CryptoKitties);

		vm.expectRevert("Invalid provided category");
		vm.prank(safe);
		atr.mintAssetTransferRightsToken(MultiToken.CryptoKitties(token, 132));
	}

	function test_shouldFail_whenERC20asERC721() external {
		_mockToken(MultiToken.Category.ERC20);

		vm.expectRevert("Asset is not valid");
		vm.prank(safe);
		atr.mintAssetTransferRightsToken(MultiToken.ERC721(token, 132));
	}

	function test_shouldFail_whenERC20asERC1155() external {
		_mockToken(MultiToken.Category.ERC20);

		vm.expectRevert("Asset is not valid");
		vm.prank(safe);
		atr.mintAssetTransferRightsToken(MultiToken.ERC1155(token, 132, erc1155Amount));
	}

	function test_shouldFail_whenERC721asERC20() external {
		_mockToken(MultiToken.Category.ERC721);

		vm.expectRevert("Asset is not valid");
		vm.prank(safe);
		atr.mintAssetTransferRightsToken(MultiToken.ERC20(token, erc20Amount));
	}

	function test_shouldFail_whenERC721asERC1155() external {
		_mockToken(MultiToken.Category.ERC721);

		vm.expectRevert("Asset is not valid");
		vm.prank(safe);
		atr.mintAssetTransferRightsToken(MultiToken.ERC1155(token, 132, erc1155Amount));
	}

	function test_shouldFail_whenERC1155asERC20() external {
		_mockToken(MultiToken.Category.ERC1155);

		vm.expectRevert("Asset is not valid");
		vm.prank(safe);
		atr.mintAssetTransferRightsToken(MultiToken.ERC20(token, erc20Amount));
	}

	function test_shouldFail_whenERC1155asERC721() external {
		_mockToken(MultiToken.Category.ERC1155);

		vm.expectRevert("Asset is not valid");
		vm.prank(safe);
		atr.mintAssetTransferRightsToken(MultiToken.ERC721(token, 132));
	}
	// <--- Asset category check

	// ---> Process
	function test_shouldPass_whenERC20SufficientBalance() external {
		_mockToken(MultiToken.Category.ERC20);

		vm.prank(safe);
		atr.mintAssetTransferRightsToken(MultiToken.ERC20(token, erc20Amount));
	}

	function test_shouldPass_whenERC721SufficientBalance() external {
		_mockToken(MultiToken.Category.ERC721);

		vm.prank(safe);
		atr.mintAssetTransferRightsToken(MultiToken.ERC721(token, 42));
	}

	function test_shouldPass_whenERC1155SufficientBalance() external {
		_mockToken(MultiToken.Category.ERC1155);

		vm.prank(safe);
		atr.mintAssetTransferRightsToken(MultiToken.ERC1155(token, 42, erc1155Amount));
	}

	function test_shouldIncreaseATRTokenId() external {
		_mockToken(MultiToken.Category.ERC721);
		uint256 lastAtrId = 736;
		vm.store(address(atr), LAST_TOKEN_ID_SLOT, bytes32(lastAtrId));

		vm.prank(safe);
		atr.mintAssetTransferRightsToken(MultiToken.ERC721(token, 42));

		bytes32 atrId = vm.load(address(atr), LAST_TOKEN_ID_SLOT);
		assertEq(uint256(atrId), lastAtrId + 1);
	}

	function test_shouldStoreTokenizedAssetData() external {
		_mockToken(MultiToken.Category.ERC721);

		vm.prank(safe);
		uint256 atrId = atr.mintAssetTransferRightsToken(MultiToken.ERC721(token, 42));

		bytes32 assetSlot = _assetStructSlotFor(atrId);

		// Category + address
		bytes32 addrAndCategory = vm.load(address(atr), bytes32(uint256(assetSlot) + 0));
		bytes32 assetCategory = addrAndCategory & bytes32(uint256(0xff));
		bytes32 assetAddress = addrAndCategory >> 8;
		assertEq(uint256(assetCategory), 1);
		assertEq(uint256(assetAddress), uint256(uint160(token)));
		// Id
		bytes32 assetId = vm.load(address(atr), bytes32(uint256(assetSlot) + 1));
		assertEq(uint256(assetId), 42);
		// Amount
		bytes32 assetAmount = vm.load(address(atr), bytes32(uint256(assetSlot) + 2));
		assertEq(uint256(assetAmount), 0);
	}

	function test_shouldStoreTokenizedAssetOwner() external {
		uint256 lastTokenId = 736;
		vm.store(address(atr), LAST_TOKEN_ID_SLOT, bytes32(lastTokenId));
		_mockToken(MultiToken.Category.ERC721);

		vm.prank(safe);
		atr.mintAssetTransferRightsToken(MultiToken.ERC721(token, 42));

		bytes32 valuesSlot = _assetsInSafeFirstValueSlotFor(safe);
		// Expecting one item -> first item (index 0) will be our ATR token
		bytes32 storedId = vm.load(address(atr), valuesSlot);
		assertEq(uint256(storedId), lastTokenId + 1);
	}

	function test_shouldMintATRToken() external {
		_mockToken(MultiToken.Category.ERC721);

		vm.prank(safe);
		uint256 atrId = atr.mintAssetTransferRightsToken(MultiToken.ERC721(token, 42));

		assertEq(atr.ownerOf(atrId), safe);
	}

	function test_shouldEmit_TransferViaATR() external {
		_mockToken(MultiToken.Category.ERC721);
		MultiToken.Asset memory asset = MultiToken.ERC721(token, 42);

		vm.expectEmit(true, true, true, true);
		emit TransferViaATR(address(0), safe, 1, asset);

		vm.prank(safe);
		atr.mintAssetTransferRightsToken(asset);
	}
	// <--- Process

}


/*----------------------------------------------------------*|
|*  # MINT ASSET TRANSFER RIGHTS TOKEN BATCH                *|
|*----------------------------------------------------------*/

contract AssetTransferRights_MintAssetTransferRightsTokenBatch_Test is AssetTransferRightsTest {

	function test_shouldAcceptEmptyList() external {
		MultiToken.Asset[] memory assets;
		atr.mintAssetTransferRightsTokenBatch(assets);
	}

	function test_shouldTokenizeAllItemsInList() external {
		_mockToken(MultiToken.Category.ERC1155);

		MultiToken.Asset[] memory assets = new MultiToken.Asset[](2);
		assets[0] = MultiToken.ERC1155(token, 42, erc1155Amount / 2);
		assets[1] = MultiToken.ERC1155(token, 42, erc1155Amount / 2);

		vm.prank(safe);
		atr.mintAssetTransferRightsTokenBatch(assets);

		assertEq(atr.ownerOf(1), safe);
		assertEq(atr.ownerOf(2), safe);
	}

}


/*----------------------------------------------------------*|
|*  # BURN ASSET TRANSFER RIGHTS TOKEN                      *|
|*----------------------------------------------------------*/

contract AssetTransferRights_BurnAssetTransferRightsToken_Test is AssetTransferRightsTest {

	uint256 tokenId = 42;
	uint256 atrId = 5;
	MultiToken.Asset asset = MultiToken.ERC721(token, tokenId);

	function setUp() override public {
		super.setUp();

		_tokenizeAssetUnderId(safe, atrId, asset);
		_mockToken(MultiToken.Category.ERC721);

		bytes32 atrTokenOwnerSlot = keccak256(abi.encode(atrId, ATR_TOKEN_OWNER_SLOT));
		vm.store(address(atr), atrTokenOwnerSlot, bytes32(uint256(uint160(address(safe)))));

		bytes32 atrTokenBalancesSlot = keccak256(abi.encode(safe, ATR_TOKEN_BALANCES_SLOT));
		vm.store(address(atr), atrTokenBalancesSlot, bytes32(uint256(1)));
	}


	function test_shouldFail_whenATRTokenDoesNotExist() external {
		vm.expectRevert("Asset transfer rights are not tokenized");
		vm.prank(safe);
		atr.burnAssetTransferRightsToken(atrId + 1);
	}

	function test_shouldFail_whenCallerNotATRTokenOwner() external {
		bytes32 atrTokenOwnerSlot = keccak256(abi.encode(atrId, ATR_TOKEN_OWNER_SLOT));
		vm.store(address(atr), atrTokenOwnerSlot, bytes32(uint256(uint160(alice))));

		vm.expectRevert("Caller is not ATR token owner");
		vm.prank(safe);
		atr.burnAssetTransferRightsToken(atrId);
	}

	function test_shouldFail_whenSenderNotTokenizedAssetOwner() external {
		vm.mockCall(
			token,
			abi.encodeWithSignature("ownerOf(uint256)", tokenId),
			abi.encode(alice)
		);

		vm.expectRevert("Insufficient balance of a tokenize asset");
		vm.prank(safe);
		atr.burnAssetTransferRightsToken(atrId);
	}

	function test_shouldRemoveStoredTokenizedAssetFromSafe() external {
		vm.prank(safe);
		atr.burnAssetTransferRightsToken(atrId);

		bytes32 atrIdValue = vm.load(address(atr), _assetsInSafeFirstValueSlotFor(safe));
		assertEq(uint256(atrIdValue), 0);
		bytes32 atrIdIndexValue = vm.load(address(atr), _assetsInSafeIndexeSlotFor(safe, atrId));
		assertEq(uint256(atrIdIndexValue), 0);
	}

	function test_shouldDecreaseTokenizedBalance() external {
		vm.prank(safe);
		atr.burnAssetTransferRightsToken(atrId);

		bytes32 tokenizedBalanceValue = vm.load(address(atr), _tokenizedBalanceValuesSlotFor(safe, token, tokenId));
		assertEq(uint256(tokenizedBalanceValue), 0);
		bytes32 indexValue = vm.load(address(atr), _tokenizedBalanceKeyIndexesSlotFor(safe, token, tokenId));
		assertEq(uint256(indexValue), 0);
	}

	function test_shouldClearStoredTokenizedAssetData() external {
		vm.prank(safe);
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

	function test_shouldBurnATRToken() external {
		vm.prank(safe);
		atr.burnAssetTransferRightsToken(atrId);

		// Load atr token owner
		bytes32 owner = vm.load(address(atr), keccak256(abi.encode(atrId, ATR_TOKEN_OWNER_SLOT)));
		assertEq(owner, 0);
	}

	// Invalid ATR token is token without known holder of underlying asset.
	// This can happen after recovering safe from stalking attack,
	// where malicious asset is force-transferred from safe without proper transfer rights.
	function test_shouldPass_whenATRTokenIsInvalid_whenCallerDoNotHaveStoredTokenizedAssetInSafe() external {
		uint256 invalidAtrTokenId = 7;
		// Store invalid ATR token owner
		bytes32 atrTokenOwnerSlot = keccak256(abi.encode(invalidAtrTokenId, ATR_TOKEN_OWNER_SLOT));
		vm.store(address(atr), atrTokenOwnerSlot, bytes32(uint256(uint160(address(safe)))));
		// Store that ATR token is invalid
		bytes32 isInvalidSlot = keccak256(abi.encode(invalidAtrTokenId, IS_INVALID_SLOT));
		vm.store(address(atr), isInvalidSlot, bytes32(uint256(1)));
		// Store asset under invalid ATR token
		_storeAssetUnderAtrId(
			MultiToken.ERC721(token, tokenId),
			invalidAtrTokenId
		);
		// Mock other owner of the asset than safe
		vm.mockCall(
			token,
			abi.encodeWithSignature("ownerOf(uint256)", tokenId),
			abi.encode(alice)
		);

		vm.prank(safe);
		atr.burnAssetTransferRightsToken(invalidAtrTokenId);
	}

	function test_shouldEmit_TransferViaATR_whenNotInvalid() external {
		vm.expectEmit(true, true, true, true);
		emit TransferViaATR(safe, address(0), atrId, asset);

		vm.prank(safe);
		atr.burnAssetTransferRightsToken(atrId);
	}

}


/*----------------------------------------------------------*|
|*  # BURN ASSET TRANSFER RIGHTS TOKEN BATCH                *|
|*----------------------------------------------------------*/

contract AssetTransferRights_BurnAssetTransferRightsTokenBatch_Test is AssetTransferRightsTest {

	function test_shouldAcceptEmptyList() external {
		uint256[] memory atrIds;

		vm.prank(safe);
		atr.burnAssetTransferRightsTokenBatch(atrIds);
	}

	function test_shouldBurnAllItemsInList() external {
		uint256[] memory atrIds = new uint256[](2);
		atrIds[0] = 42;
		atrIds[1] = 192;

		MultiToken.Asset[] memory assets = new MultiToken.Asset[](2);
		assets[0] = MultiToken.ERC1155(token, 31, erc1155Amount);
		assets[1] = MultiToken.ERC1155(token, 1, erc1155Amount);

		_mockToken(MultiToken.Category.ERC1155);
		_tokenizeAssetsUnderIds(safe, atrIds, assets);

		// Store ATR token 42 owner
		vm.store(address(atr), keccak256(abi.encode(atrIds[0], ATR_TOKEN_OWNER_SLOT)), bytes32(uint256(uint160(address(safe)))));
		// Store ATR token 192 owner
		vm.store(address(atr), keccak256(abi.encode(atrIds[1], ATR_TOKEN_OWNER_SLOT)), bytes32(uint256(uint160(address(safe)))));
		// Store safes ATR token balance
		vm.store(address(atr), keccak256(abi.encode(safe, ATR_TOKEN_BALANCES_SLOT)), bytes32(uint256(2)));

		vm.prank(safe);
		atr.burnAssetTransferRightsTokenBatch(atrIds);

		// Check ATR 42 owner
		bytes32 owner42 = vm.load(address(atr), keccak256(abi.encode(atrIds[0], ATR_TOKEN_OWNER_SLOT)));
		assertEq(owner42, 0);

		// Check ATR 192 owner
		bytes32 owner192 = vm.load(address(atr), keccak256(abi.encode(atrIds[1], ATR_TOKEN_OWNER_SLOT)));
		assertEq(owner192, 0);
	}

}


/*----------------------------------------------------------*|
|*  # CLAIM ASSET FROM                                      *|
|*----------------------------------------------------------*/

contract AssetTransferRights_ClaimAssetFrom_Test is AssetTransferRightsTest {

	uint256 atrId = 5;
	uint256 atrId2 = 102;
	uint256 tokenId = 42;
	MultiToken.Asset asset = MultiToken.ERC1155(token, tokenId, erc1155Amount / 2);

	function setUp() override public {
		super.setUp();

		// Mock state where safe has 2 tokenized assets and alice holds both ATR tokens

		uint256[] memory atrIds = new uint256[](2);
		atrIds[0] = atrId;
		atrIds[1] = atrId2;


		MultiToken.Asset[] memory assets = new MultiToken.Asset[](2);
		assets[0] = asset;
		assets[1] = asset;

		_tokenizeAssetsUnderIds(safe, atrIds, assets);
		_mockToken(MultiToken.Category.ERC1155);

		// ATR 5 & 102 token owner
		vm.store(address(atr), keccak256(abi.encode(atrId, ATR_TOKEN_OWNER_SLOT)), bytes32(uint256(uint160(alice))));
		vm.store(address(atr), keccak256(abi.encode(atrId2, ATR_TOKEN_OWNER_SLOT)), bytes32(uint256(uint160(alice))));
		// alice atr balance
		vm.store(address(atr), keccak256(abi.encode(alice, ATR_TOKEN_BALANCES_SLOT)), bytes32(uint256(2)));

		vm.mockCall(
			safe,
			abi.encodeWithSignature("execTransactionFromModule(address,uint256,bytes,uint8)"),
			abi.encode(true)
		);
	}


	// ---> Basic checks
	function test_shouldFail_whenTransferringToSameAddress() external {
		vm.expectRevert("Attempting to transfer asset to the same address");
		vm.prank(safe);
		atr.claimAssetFrom(safe, atrId, true);
	}

	function test_shouldFail_whenTokenRightsAreNotTokenized() external {
		vm.expectRevert("Transfer rights are not tokenized");
		vm.prank(alice);
		atr.claimAssetFrom(safe, 4, true);
	}

	function test_shouldFail_whenCallerIsNotATRTokenOwner() external {
		vm.expectRevert("Caller is not ATR token owner");
		vm.prank(bob);
		atr.claimAssetFrom(safe, atrId, true);
	}

	function test_shouldFail_whenAssetIsNotInSafe() external {
		address payable otherSafe = payable(address(0xfe));
		vm.mockCall(
			safeValidator,
			abi.encodeWithSignature("isValidSafe(address)", otherSafe),
			abi.encode(true)
		);

		vm.expectRevert("Asset is not in a target safe");
		vm.prank(alice);
		atr.claimAssetFrom(otherSafe, atrId, true);
	}

	function test_shouldFail_whenATRTokenIsInvalid() external {
		bytes32 isInvalidSlot = keccak256(abi.encode(atrId, IS_INVALID_SLOT));
		vm.store(address(atr), isInvalidSlot, bytes32(uint256(1)));

		vm.expectRevert("ATR token is invalid due to recovered invalid tokenized balance");
		vm.prank(alice);
		atr.claimAssetFrom(safe, atrId, true);
	}
	// <--- Basic checks

	// ---> Process
	function test_shouldStoreAssetIsNotInSafe() external {
		vm.prank(alice);
		atr.claimAssetFrom(safe, atrId, true);

		// Atr id is not stored in safe
		bytes32 atrIdIndexValue = vm.load(address(atr), _assetsInSafeIndexeSlotFor(safe, atrId));
		assertEq(uint256(atrIdIndexValue), 0);
		// Atr ids length is one
		bytes32 atrIdsLength = vm.load(address(atr), _assetsInSafeSetSlotFor(safe));
		assertEq(uint256(atrIdsLength), 1);
		// Only stored atr id is the second
		bytes32 firstStoredAtrId = vm.load(address(atr), _assetsInSafeFirstValueSlotFor(safe));
		assertEq(uint256(firstStoredAtrId), atrId2);
	}

	function test_shouldDecreaseAssetsTokenizedBalanceInOriginSafe() external {
		vm.prank(alice);
		atr.claimAssetFrom(safe, atrId, true);

		bytes32 tokenizedBalanceValue = vm.load(address(atr), _tokenizedBalanceValuesSlotFor(safe, token, tokenId));
		assertEq(uint256(tokenizedBalanceValue), erc1155Amount / 2);
	}

	function test_shouldFail_whenExecutionUnsuccessful() external {
		vm.mockCall(
			safe,
			abi.encodeWithSignature("execTransactionFromModule(address,uint256,bytes,uint8)"),
			abi.encode(false)
		);

		vm.expectRevert("Asset transfer failed");
		vm.prank(alice);
		atr.claimAssetFrom(safe, atrId, true);
	}
	// <--- Process

	// ---> With `burnToken` flag
	function test_shouldClearStoredTokenizedAssetData_whenWithBurnFlag() external {
		vm.prank(alice);
		atr.claimAssetFrom(safe, atrId, true);

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
		vm.prank(alice);
		atr.claimAssetFrom(safe, atrId, true);

		// Load atr token owner
		bytes32 owner = vm.load(address(atr), keccak256(abi.encode(atrId, ATR_TOKEN_OWNER_SLOT)));
		assertEq(owner, 0);
	}

	function test_shouldEmit_TransferViaATR_whenWithBurnFlag() external {
		vm.expectEmit(true, true, true, true);
		emit TransferViaATR(safe, address(0), atrId, asset);

		vm.prank(alice);
		atr.claimAssetFrom(safe, atrId, true);
	}
	// <--- With `burnToken` flag

	// ---> Without `burnToken` flag
	function test_shouldFail_whenRecipientIsNotPWNSafe_whenWithoutBurnFlag() external {
		vm.expectRevert("Attempting to transfer asset to non PWNSafe address");
		vm.prank(alice);
		atr.claimAssetFrom(safe, atrId, false);
	}

	function test_shouldFail_whenRecipientHasApprovalForAsset_whenWithoutBurnFlag() external {
		// Alice is safe now
		vm.mockCall(
			safeValidator,
			abi.encodeWithSignature("isValidSafe(address)", alice),
			abi.encode(true)
		);
		vm.mockCall(
			guard,
			abi.encodeWithSignature("hasOperatorFor(address,address)", alice),
			abi.encode(true)
		);

		vm.expectRevert("Receiver has approvals set for an asset");
		vm.prank(alice);
		atr.claimAssetFrom(safe, atrId, false);
	}

	function test_shouldStoreAssetIsInRecipientSafe_whenWithoutBurnFlag() external {
		// Alice is safe now
		vm.mockCall(
			safeValidator,
			abi.encodeWithSignature("isValidSafe(address)", alice),
			abi.encode(true)
		);

		vm.prank(alice);
		atr.claimAssetFrom(safe, atrId, false);

		// Value is under first index
		bytes32 atrIdIndexValue = vm.load(address(atr), _assetsInSafeIndexeSlotFor(alice, atrId));
		assertEq(uint256(atrIdIndexValue), 1);
		// Value is stored under the first index
		bytes32 atrIdValue = vm.load(address(atr), _assetsInSafeFirstValueSlotFor(alice)); // 1 - 1
		assertEq(uint256(atrIdValue), atrId);
	}

	function test_shouldIncreaseAssetsTokenizedBalanceInRecipientSafe_whenWithoutBurnFlag() external {
		// Alice is safe now
		vm.mockCall(
			safeValidator,
			abi.encodeWithSignature("isValidSafe(address)", alice),
			abi.encode(true)
		);

		vm.prank(alice);
		atr.claimAssetFrom(safe, atrId, false);

		bytes32 tokenizedBalanceValue = vm.load(address(atr), _tokenizedBalanceValuesSlotFor(alice, token, tokenId));
		assertEq(uint256(tokenizedBalanceValue), erc1155Amount / 2);
	}

	function test_shouldEmit_TransferViaATR_whenWithoutBurnFlag() external {
		// Alice is safe now
		vm.mockCall(
			safeValidator,
			abi.encodeWithSignature("isValidSafe(address)", alice),
			abi.encode(true)
		);

		vm.expectEmit(true, true, true, true);
		emit TransferViaATR(safe, alice, atrId, asset);

		vm.prank(alice);
		atr.claimAssetFrom(safe, atrId, false);
	}
	// <--- Without `burnToken` flag

}


/*----------------------------------------------------------*|
|*  # TRANSFER ASSET FROM                                   *|
|*----------------------------------------------------------*/

contract AssetTransferRights_TransferAssetFrom_Test is AssetTransferRightsTest {

	uint256 atrId = 5;
	uint256 atrId2 = 102;
	uint256 tokenId = 42;
	MultiToken.Asset asset = MultiToken.ERC1155(token, tokenId, erc1155Amount / 2);

	RecipientPermissionManager.RecipientPermission permission;
	bytes32 permissionHash;

	event RecipientPermissionNonceRevoked(address indexed recipient, bytes32 indexed permissionNonce);

	function setUp() override public {
		super.setUp();

		// Mock state where safe has 2 tokenized assets and alice holds both ATR tokens

		uint256[] memory atrIds = new uint256[](2);
		atrIds[0] = atrId;
		atrIds[1] = atrId2;


		MultiToken.Asset[] memory assets = new MultiToken.Asset[](2);
		assets[0] = asset;
		assets[1] = asset;

		_tokenizeAssetsUnderIds(safe, atrIds, assets);
		_mockToken(MultiToken.Category.ERC1155);

		// ATR 5 & 102 token owner
		vm.store(address(atr), keccak256(abi.encode(atrId, ATR_TOKEN_OWNER_SLOT)), bytes32(uint256(uint160(alice))));
		vm.store(address(atr), keccak256(abi.encode(atrId2, ATR_TOKEN_OWNER_SLOT)), bytes32(uint256(uint160(alice))));
		// alice atr balance
		vm.store(address(atr), keccak256(abi.encode(alice, ATR_TOKEN_BALANCES_SLOT)), bytes32(uint256(2)));

		vm.mockCall(
			safe,
			abi.encodeWithSignature("execTransactionFromModule(address,uint256,bytes,uint8)"),
			abi.encode(true)
		);

		vm.warp(10202);

		permission = RecipientPermissionManager.RecipientPermission(
			MultiToken.Category.ERC1155,
			token,
			tokenId,
			erc1155Amount / 2,
			false,
			bob,
			alice,
			10302,
			false,
			keccak256("nonce")
		);
		permissionHash = atr.recipientPermissionHash(permission);
	}

	function _mockGrantedPermission(bytes32 _permissionHash) internal {
		bytes32 permissionSlot = keccak256(abi.encode(_permissionHash, GRANTED_PERMISSION_SLOT));
		vm.store(address(atr), permissionSlot, bytes32(uint256(1)));
	}

	function _mockRevokedPermissionNonce(address _owner, bytes32 _permissionNonce) internal {
		bytes32 ownersPermissionNonceSlot = keccak256(abi.encode(_owner, REVOKED_PERMISSION_NONCE_SLOT));
		bytes32 permissionNonceSlot = keccak256(abi.encode(_permissionNonce, ownersPermissionNonceSlot));
		vm.store(address(atr), permissionNonceSlot, bytes32(uint256(1)));
	}

	function _valueOfRevokePermissionNonce(address _owner, bytes32 _permissionNonce) internal view returns (bytes32) {
		bytes32 ownersPermissionNonceSlot = keccak256(abi.encode(_owner, REVOKED_PERMISSION_NONCE_SLOT));
		bytes32 permissionNonceSlot = keccak256(abi.encode(_permissionNonce, ownersPermissionNonceSlot));
		return vm.load(address(atr), permissionNonceSlot);
	}


	// ---> Basic checks
	function test_shouldFail_whenTransferringToSameAddress() external {
		permission.recipient = safe;
		permissionHash = atr.recipientPermissionHash(permission);
		_mockGrantedPermission(permissionHash);

		vm.expectRevert("Attempting to transfer asset to the same address");
		vm.prank(alice);
		atr.transferAssetFrom(safe, atrId, true, permission, "");
	}

	function test_shouldFail_whenTokenRightsAreNotTokenized() external {
		_mockGrantedPermission(permissionHash);

		vm.expectRevert("Transfer rights are not tokenized");
		vm.prank(alice);
		atr.transferAssetFrom(safe, 4, true, permission, "");
	}

	function test_shouldFail_whenCallerIsNotATRTokenOwner() external {
		_mockGrantedPermission(permissionHash);

		vm.expectRevert("Caller is not ATR token owner");
		vm.prank(bob);
		atr.transferAssetFrom(safe, atrId, true, permission, "");
	}

	function test_shouldFail_whenATRTokenIsInvalid() external {
		_mockGrantedPermission(permissionHash);
		bytes32 isInvalidSlot = keccak256(abi.encode(atrId, IS_INVALID_SLOT));
		vm.store(address(atr), isInvalidSlot, bytes32(uint256(1)));

		vm.expectRevert("ATR token is invalid due to recovered invalid tokenized balance");
		vm.prank(alice);
		atr.transferAssetFrom(safe, atrId, true, permission, "");
	}
	// <--- Basic checks

	// ---> Permission validation
	function test_shouldFail_whenPermissionIsExpired() external {
		permission.expiration = uint40(block.timestamp) - 100;
		permissionHash = atr.recipientPermissionHash(permission);
		_mockGrantedPermission(permissionHash);

		vm.expectRevert("Recipient permission is expired");
		vm.prank(alice);
		atr.transferAssetFrom(safe, atrId, true, permission, "");
	}

	function test_shouldPass_whenPermissionHasNoExpiration() external {
		permission.expiration = 0;
		permissionHash = atr.recipientPermissionHash(permission);
		_mockGrantedPermission(permissionHash);

		vm.prank(alice);
		atr.transferAssetFrom(safe, atrId, true, permission, "");
	}

	function test_shouldFail_whenCallerIsNotPermittedAgent() external {
		permission.agent = address(0x01);
		permissionHash = atr.recipientPermissionHash(permission);
		_mockGrantedPermission(permissionHash);

		vm.expectRevert("Caller is not permitted agent");
		vm.prank(alice);
		atr.transferAssetFrom(safe, atrId, true, permission, "");
	}

	function test_shouldPass_whenPermittedAgentIsNotStated() external {
		permission.agent = address(0);
		permissionHash = atr.recipientPermissionHash(permission);
		_mockGrantedPermission(permissionHash);

		vm.prank(alice);
		atr.transferAssetFrom(safe, atrId, true, permission, "");
	}

	function test_shouldFail_whenAssetIsNotPermitted() external {
		permission.assetCategory = MultiToken.Category.ERC721;
		permissionHash = atr.recipientPermissionHash(permission);
		_mockGrantedPermission(permissionHash);

		vm.expectRevert("Invalid permitted asset");
		vm.prank(alice);
		atr.transferAssetFrom(safe, atrId, true, permission, "");
	}

	function test_shouldIgnoreAssetIdAndAmount_whenFlagIsTrue() external {
		permission.ignoreAssetIdAndAmount = true;
		permission.assetId = 0;
		permission.assetAmount = 0;
		permissionHash = atr.recipientPermissionHash(permission);
		_mockGrantedPermission(permissionHash);

		vm.prank(alice);
		atr.transferAssetFrom(safe, atrId, true, permission, "");
	}

	function test_shouldFail_whenPermissionHasBeenRevoked() external {
		_mockRevokedPermissionNonce(permission.recipient, permission.nonce);
		_mockGrantedPermission(permissionHash);

		vm.expectRevert("Recipient permission nonce is revoked");
		vm.prank(alice);
		atr.transferAssetFrom(safe, atrId, true, permission, "");
	}

	function test_shouldFail_whenPermissionHasNotBeenGranted_whenERC1271InvalidSignature() external {
		vm.etch(bob, bytes("data"));
		vm.mockCall(
			bob,
			abi.encodeWithSignature("isValidSignature(bytes32,bytes)"),
			abi.encode(bytes4(0xffffffff))
		);

		vm.expectRevert("Signature on behalf of contract is invalid");
		vm.prank(alice);
		atr.transferAssetFrom(safe, atrId, true, permission, "");
	}

	function test_shouldFail_whenPermissionHasNotBeenGranted_whenInvalidSignature() external {
		(uint8 v, bytes32 r, bytes32 s) = vm.sign(6, keccak256("invalid data"));

		vm.expectRevert("Permission signer is not stated as recipient");
		vm.prank(alice);
		atr.transferAssetFrom(safe, atrId, true, permission, abi.encodePacked(r, s, v));
	}

	function test_shouldPass_whenPermissionHasBeenGranted() external {
		_mockGrantedPermission(permissionHash);

		vm.prank(alice);
		atr.transferAssetFrom(safe, atrId, true, permission, "");
	}

	function test_shouldPass_whenERC1271ValidSignature() external {
		vm.etch(bob, bytes("data"));
		vm.mockCall(
			bob,
			abi.encodeWithSignature("isValidSignature(bytes32,bytes)"),
			abi.encode(bytes4(0x1626ba7e))
		);

		vm.prank(alice);
		atr.transferAssetFrom(safe, atrId, true, permission, "");
	}

	function test_shouldPass_whenValidSignature() external {
		uint256 pk = 6;
		address recipient = vm.addr(pk);
		permission.recipient = recipient;
		permissionHash = atr.recipientPermissionHash(permission);
		(uint8 v, bytes32 r, bytes32 s) = vm.sign(pk, permissionHash);

		vm.prank(alice);
		atr.transferAssetFrom(safe, atrId, true, permission, abi.encodePacked(r, s, v));
	}

	function test_shouldNotStoreThatPermissionIsRevoked_whenPersistent() external {
		permission.isPersistent = true;
		permissionHash = atr.recipientPermissionHash(permission);
		_mockGrantedPermission(permissionHash);

		vm.prank(alice);
		atr.transferAssetFrom(safe, atrId, true, permission, "");

		bytes32 permissionNonceRevokedValue = _valueOfRevokePermissionNonce(permission.recipient, permission.nonce);
		assertEq(uint256(permissionNonceRevokedValue), 0);
	}

	function test_shouldStoreThatPermissionIsRevoked_whenNotPersistent() external {
		_mockGrantedPermission(permissionHash);

		vm.prank(alice);
		atr.transferAssetFrom(safe, atrId, true, permission, "");

		bytes32 permissionNonceRevokedValue = _valueOfRevokePermissionNonce(permission.recipient, permission.nonce);
		assertEq(uint256(permissionNonceRevokedValue), 1);
	}

	function test_shouldEmitRecipientPermissionRevokedEvent() external {
		_mockGrantedPermission(permissionHash);

		vm.expectEmit(true, true, false, false);
		emit RecipientPermissionNonceRevoked(permission.recipient, permission.nonce);

		vm.prank(alice);
		atr.transferAssetFrom(safe, atrId, true, permission, "");
	}
	// <--- Permission validation

	// ---> Process
	function test_shouldFail_whenAssetIsNotInSafe() external {
		_mockGrantedPermission(permissionHash);
		address payable otherSafe = payable(address(0xfe));
		vm.mockCall(
			safeValidator,
			abi.encodeWithSignature("isValidSafe(address)", otherSafe),
			abi.encode(true)
		);

		vm.expectRevert("Asset is not in a target safe");
		vm.prank(alice);
		atr.transferAssetFrom(otherSafe, atrId, true, permission, "");
	}

	function test_shouldStoreAssetIsNotInSafe() external {
		_mockGrantedPermission(permissionHash);

		vm.prank(alice);
		atr.transferAssetFrom(safe, atrId, true, permission, "");

		// Atr id is not stored in safe
		bytes32 atrIdIndexValue = vm.load(address(atr), _assetsInSafeIndexeSlotFor(safe, atrId));
		assertEq(uint256(atrIdIndexValue), 0);
		// Atr ids length is one
		bytes32 atrIdsLength = vm.load(address(atr), _assetsInSafeSetSlotFor(safe));
		assertEq(uint256(atrIdsLength), 1);
		// Only stored atr id is the second
		bytes32 firstStoredAtrId = vm.load(address(atr), _assetsInSafeFirstValueSlotFor(safe));
		assertEq(uint256(firstStoredAtrId), atrId2);
	}

	function test_shouldDecreaseAssetsTokenizedBalanceInOriginSafe() external {
		_mockGrantedPermission(permissionHash);

		vm.prank(alice);
		atr.transferAssetFrom(safe, atrId, true, permission, "");

		bytes32 tokenizedBalanceValue = vm.load(address(atr), _tokenizedBalanceValuesSlotFor(safe, token, tokenId));
		assertEq(uint256(tokenizedBalanceValue), erc1155Amount / 2);
	}

	function test_shouldFail_whenExecutionUnsuccessful() external {
		_mockGrantedPermission(permissionHash);

		vm.mockCall(
			safe,
			abi.encodeWithSignature("execTransactionFromModule(address,uint256,bytes,uint8)"),
			abi.encode(false)
		);

		vm.expectRevert("Asset transfer failed");
		vm.prank(alice);
		atr.transferAssetFrom(safe, atrId, true, permission, "");
	}
	// <--- Process

	// ---> With `burnToken` flag
	function test_shouldClearStoredTokenizedAssetData_whenWithBurnFlag() external {
		_mockGrantedPermission(permissionHash);

		vm.prank(alice);
		atr.transferAssetFrom(safe, atrId, true, permission, "");

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
		_mockGrantedPermission(permissionHash);

		vm.prank(alice);
		atr.transferAssetFrom(safe, atrId, true, permission, "");

		// Load atr token owner
		bytes32 owner = vm.load(address(atr), keccak256(abi.encode(atrId, ATR_TOKEN_OWNER_SLOT)));
		assertEq(owner, 0);
	}

	function test_shouldEmit_TransferViaATR_whenWithBurnFlag() external {
		_mockGrantedPermission(permissionHash);

		vm.expectEmit(true, true, true, true);
		emit TransferViaATR(safe, address(0), atrId, asset);

		vm.prank(alice);
		atr.transferAssetFrom(safe, atrId, true, permission, "");
	}
	// <--- With `burnToken` flag

	// ---> Without `burnToken` flag
	function test_shouldFail_whenRecipientIsNotPWNSafe_whenWithoutBurnFlag() external {
		_mockGrantedPermission(permissionHash);

		vm.expectRevert("Attempting to transfer asset to non PWNSafe address");
		vm.prank(alice);
		atr.transferAssetFrom(safe, atrId, false, permission, "");
	}

	function test_shouldFail_whenRecipientHasApprovalForAsset_whenWithoutBurnFlag() external {
		// Bob is safe now
		vm.mockCall(
			safeValidator,
			abi.encodeWithSignature("isValidSafe(address)", bob),
			abi.encode(true)
		);
		vm.mockCall(
			guard,
			abi.encodeWithSignature("hasOperatorFor(address,address)", bob),
			abi.encode(true)
		);
		_mockGrantedPermission(permissionHash);

		vm.expectRevert("Receiver has approvals set for an asset");
		vm.prank(alice);
		atr.transferAssetFrom(safe, atrId, false, permission, "");
	}

	function test_shouldStoreAssetIsInRecipientSafe_whenWithoutBurnFlag() external {
		// Bob is safe now
		vm.mockCall(
			safeValidator,
			abi.encodeWithSignature("isValidSafe(address)", bob),
			abi.encode(true)
		);
		_mockGrantedPermission(permissionHash);

		vm.prank(alice);
		atr.transferAssetFrom(safe, atrId, false, permission, "");

		// Value is under first index
		bytes32 atrIdIndexValue = vm.load(address(atr), _assetsInSafeIndexeSlotFor(bob, atrId));
		assertEq(uint256(atrIdIndexValue), 1);
		// Value is stored under the first index
		bytes32 atrIdValue = vm.load(address(atr), _assetsInSafeFirstValueSlotFor(bob)); // 1 - 1
		assertEq(uint256(atrIdValue), atrId);
	}

	function test_shouldIncreaseAssetsTokenizedBalanceInRecipientSafe_whenWithoutBurnFlag() external {
		// Bob is safe now
		vm.mockCall(
			safeValidator,
			abi.encodeWithSignature("isValidSafe(address)", bob),
			abi.encode(true)
		);
		_mockGrantedPermission(permissionHash);

		vm.prank(alice);
		atr.transferAssetFrom(safe, atrId, false, permission, "");

		bytes32 tokenizedBalanceValue = vm.load(address(atr), _tokenizedBalanceValuesSlotFor(bob, token, tokenId));
		assertEq(uint256(tokenizedBalanceValue), erc1155Amount / 2);
	}

	function test_shouldEmit_TransferViaATR_whenWithoutBurnFlag() external {
		// Bob is safe now
		vm.mockCall(
			safeValidator,
			abi.encodeWithSignature("isValidSafe(address)", bob),
			abi.encode(true)
		);
		_mockGrantedPermission(permissionHash);

		vm.expectEmit(true, true, true, true);
		emit TransferViaATR(safe, bob, atrId, asset);

		vm.prank(alice);
		atr.transferAssetFrom(safe, atrId, false, permission, "");
	}
	// <--- Without `burnToken` flag

}


/*----------------------------------------------------------*|
|*  # TOKEN URI                                             *|
|*----------------------------------------------------------*/

contract AssetTransferRights_TokenUri_Test is AssetTransferRightsTest {

	function test_shouldFail_whenTokenIdIsNotMinted() external {
		vm.expectRevert("ERC721: invalid token ID");
		atr.tokenURI(42);
	}

	function test_shouldReturnStoredMetadataUri() external {
		bytes32 atrTokenOwnerSlot = keccak256(abi.encode(42, ATR_TOKEN_OWNER_SLOT));
		vm.store(address(atr), atrTokenOwnerSlot, bytes32(uint256(uint160(address(safe)))));
		string memory _uri = "test.pwn";
		atr.setMetadataUri(_uri);

		string memory uri = atr.tokenURI(42);

		assertEq(keccak256(abi.encodePacked(uri)), keccak256(abi.encodePacked(_uri)));
	}

}


/*----------------------------------------------------------*|
|*  # SET METEDATA URI                                      *|
|*----------------------------------------------------------*/

contract AssetTransferRights_SetMetadataUri_Test is AssetTransferRightsTest {
	using stdStorage for StdStorage;

	function test_shouldFail_whenCallerIsNotOwner() external {
		address notOwner = address(0x1234567890);

		vm.expectRevert("Ownable: caller is not the owner");
		vm.prank(notOwner);
		atr.setMetadataUri("test.pwn");
	}

	function test_shouldSetMetadataUri() external {
		bytes32 atrTokenOwnerSlot = keccak256(abi.encode(42, ATR_TOKEN_OWNER_SLOT));
		vm.store(address(atr), atrTokenOwnerSlot, bytes32(uint256(uint160(address(safe)))));
		string memory uri = "test.pwn";

		atr.setMetadataUri(uri);

		string memory _uri = atr.tokenURI(42);
		assertEq(keccak256(abi.encodePacked(uri)), keccak256(abi.encodePacked(_uri)));
	}

}

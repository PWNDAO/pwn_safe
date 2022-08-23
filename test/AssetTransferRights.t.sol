// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.15;

import "forge-std/Test.sol";
import "openzeppelin-contracts/contracts/interfaces/IERC20.sol";
import "openzeppelin-contracts/contracts/interfaces/IERC721.sol";
import "openzeppelin-contracts/contracts/interfaces/IERC1155.sol";
import "MultiToken/MultiToken.sol";
import "../src/AssetTransferRights.sol";
import "./helpers/TokenizedAssetManagerStorageHelper.sol";


abstract contract AssetTransferRightsTest is TokenizedAssetManagerStorageHelper {

	bytes32 internal constant ATR_TOKEN_OWNER_SLOT = bytes32(uint256(9)); // `_owners` ERC721 mapping position
	bytes32 internal constant ATR_TOKEN_BALANCES_SLOT = bytes32(uint256(10)); // `_balances` ERC721 mapping position
	bytes32 internal constant LAST_TOKEN_ID_SLOT = bytes32(uint256(13)); // `lastTokenId` property position

	AssetTransferRights atr;
	address safe = address(0xff);
	address token = address(0x070ce2);
	address alice = address(0xa11ce);
	address bob = address(0xb0b);
	address erc1820Registry = address(0x1820a4B7618BdE71Dce8cdc73aAB6C95905faD24);
	address guard = address(0x1111);
	address safeValidator = address(0x2222);

	uint256 erc20Amount = 100e18;
	uint256 erc1155Amount = 100;

	constructor() {
		vm.etch(guard, bytes("data"));
		vm.etch(safeValidator, bytes("data"));
		vm.etch(token, bytes("data"));
	}

	function setUp() virtual public {
		atr = new AssetTransferRights();
		setAtr(address(atr));

		atr.setAssetTransferRightsGuard(guard);
		atr.setPWNSafeValidator(safeValidator);
		atr.setUseWhitelist(false);

		_mockDependencyContracts();
	}


	function _mockToken(MultiToken.Category category) internal {
		_mockToken(category, true);
	}

	function _mockToken(MultiToken.Category category, bool erc165) internal {
		vm.clearMockedCalls();

		_mockDependencyContracts();

		if (erc165) {
			vm.mockCall(
				token,
				abi.encodeWithSignature("supportsInterface(bytes4)", bytes4(0xffffffff)),
				abi.encode(false)
			);
			vm.mockCall(
				token,
				abi.encodeWithSignature("supportsInterface(bytes4)"),
				abi.encode(true)
			);
		}

		if (category == MultiToken.Category.ERC20) {
			vm.mockCall(
				token,
				abi.encodeWithSignature("totalSupply()"),
				abi.encode(1)
			);
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
		} else if (category == MultiToken.Category.ERC1155) {
			vm.mockCall(
				token,
				abi.encodeWithSignature("balanceOf(address,uint256)"),
				abi.encode(erc1155Amount)
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
		atr.mintAssetTransferRightsToken(
			MultiToken.Asset(MultiToken.Category.ERC721, token, 42, 1)
		);
	}

	function test_shouldFail_whenZeroAddressAsset() external {
		_mockToken(MultiToken.Category.ERC721);

		vm.expectRevert("Attempting to tokenize zero address asset");
		vm.prank(safe);
		atr.mintAssetTransferRightsToken(
			MultiToken.Asset(MultiToken.Category.ERC721, address(0), 42, 1)
		);
	}

	function test_shouldFail_whenATRToken() external {
		_mockToken(MultiToken.Category.ERC721);

		vm.expectRevert("Attempting to tokenize ATR token");
		vm.prank(safe);
		atr.mintAssetTransferRightsToken(
			MultiToken.Asset(MultiToken.Category.ERC721, address(atr), 42, 1)
		);
	}

	function test_shouldFail_whenUsingWhitelist_whenAssetIsNotWhitelisted() external {
		_mockToken(MultiToken.Category.ERC721);
		atr.setUseWhitelist(true);

		vm.expectRevert("Asset is not whitelisted");
		vm.prank(safe);
		atr.mintAssetTransferRightsToken(
			MultiToken.Asset(MultiToken.Category.ERC721, token, 42, 1)
		);
	}

	function test_shouldPass_whenUsingWhitelist_whenAssetWhitelisted() external {
		_mockToken(MultiToken.Category.ERC721);
		atr.setUseWhitelist(true);
		atr.setIsWhitelisted(token, true);

		vm.prank(safe);
		atr.mintAssetTransferRightsToken(
			MultiToken.Asset(MultiToken.Category.ERC721, token, 42, 1)
		);
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
		atr.mintAssetTransferRightsToken(
			MultiToken.Asset(MultiToken.Category.ERC721, token, 42, 1)
		);
	}

	function test_shouldFail_whenInvalidMultiTokenAsset() external {
		_mockToken(MultiToken.Category.ERC721);

		vm.expectRevert("Asset is not valid");
		vm.prank(safe);
		atr.mintAssetTransferRightsToken(
			MultiToken.Asset(MultiToken.Category.ERC721, token, 42, 0)
		);
	}
	// <--- Basic checks

	// ---> Insufficient balance
	function test_shouldFail_whenERC20HasNotEnoughtBalance() external {
		_mockToken(MultiToken.Category.ERC20);

		vm.expectRevert("Insufficient balance to tokenize");
		vm.prank(safe);
		atr.mintAssetTransferRightsToken(
			MultiToken.Asset(MultiToken.Category.ERC20, token, 0, erc20Amount + 1e18)
		);
	}

	function test_shouldFail_whenERC20HasNotEnoughtUntokenizedBalance() external {
		MultiToken.Asset memory asset = MultiToken.Asset(MultiToken.Category.ERC20, token, 0, erc20Amount - 20e18);
		_tokenizeAssetUnderId(safe, 1, asset);
		_mockToken(MultiToken.Category.ERC20);

		vm.expectRevert("Insufficient balance to tokenize");
		vm.prank(safe);
		atr.mintAssetTransferRightsToken(
			MultiToken.Asset(MultiToken.Category.ERC20, token, 0, 21e18)
		);
	}

	function test_shouldFail_whenERC721IsAlreadyTokenized() external {
		MultiToken.Asset memory asset = MultiToken.Asset(MultiToken.Category.ERC721, token, 42, 1);
		_tokenizeAssetUnderId(safe, 1, asset);
		_mockToken(MultiToken.Category.ERC721);

		vm.expectRevert("Insufficient balance to tokenize");
		vm.prank(safe);
		atr.mintAssetTransferRightsToken(
			MultiToken.Asset(MultiToken.Category.ERC721, token, 42, 1)
		);
	}

	function test_shouldFail_whenERC1155HasNotEnoughtBalance() external {
		_mockToken(MultiToken.Category.ERC1155);

		vm.expectRevert("Insufficient balance to tokenize");
		vm.prank(safe);
		atr.mintAssetTransferRightsToken(
			MultiToken.Asset(MultiToken.Category.ERC1155, token, 42, erc1155Amount + 10)
		);
	}

	function test_shouldFail_whenERC1155HasNotEnoughtUntokenizedBalance() external {
		MultiToken.Asset memory asset = MultiToken.Asset(MultiToken.Category.ERC1155, token, 42, erc1155Amount - 10);
		_tokenizeAssetUnderId(safe, 1, asset);
		_mockToken(MultiToken.Category.ERC1155);

		vm.expectRevert("Insufficient balance to tokenize");
		vm.prank(safe);
		atr.mintAssetTransferRightsToken(
			MultiToken.Asset(MultiToken.Category.ERC1155, token, 42, 11)
		);
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
			MultiToken.Asset(MultiToken.Category.ERC20, token, 0, erc20Amount)
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
			MultiToken.Asset(MultiToken.Category.ERC721, token, 42, 1)
		);
	}
	// <--- Approvals

	// ---> Asset category check
	function test_shouldFail_whenERC20asERC721_whenWithERC165() external {
		_mockToken(MultiToken.Category.ERC20);

		vm.mockCall(
			token,
			abi.encodeWithSignature("supportsInterface(bytes4)", type(IERC721).interfaceId),
			abi.encode(false)
		);

		vm.expectRevert("Invalid provided category");
		vm.prank(safe);
		atr.mintAssetTransferRightsToken(
			MultiToken.Asset(MultiToken.Category.ERC721, token, 132, 1)
		);
	}

	function test_shouldFail_whenERC20asERC721_whenWithoutERC165() external {
		_mockToken(MultiToken.Category.ERC20, false);

		vm.expectRevert("Invalid provided category");
		vm.prank(safe);
		atr.mintAssetTransferRightsToken(
			MultiToken.Asset(MultiToken.Category.ERC721, token, 132, 1)
		);
	}

	function test_shouldFail_whenERC20asERC1155_whenWithERC165() external {
		_mockToken(MultiToken.Category.ERC20);

		vm.mockCall(
			token,
			abi.encodeWithSignature("supportsInterface(bytes4)", type(IERC1155).interfaceId),
			abi.encode(false)
		);

		vm.expectRevert("Invalid provided category");
		vm.prank(safe);
		atr.mintAssetTransferRightsToken(
			MultiToken.Asset(MultiToken.Category.ERC1155, token, 132, erc1155Amount)
		);
	}

	function test_shouldFail_whenERC20asERC1155_whenWithoutERC165() external {
		_mockToken(MultiToken.Category.ERC20, false);

		vm.expectRevert("Invalid provided category");
		vm.prank(safe);
		atr.mintAssetTransferRightsToken(
			MultiToken.Asset(MultiToken.Category.ERC1155, token, 132, erc1155Amount)
		);
	}

	function test_shouldFail_whenERC721asERC20() external {
		_mockToken(MultiToken.Category.ERC721);

		vm.mockCall(
			token,
			abi.encodeWithSignature("supportsInterface(bytes4)", type(IERC20).interfaceId),
			abi.encode(false)
		);

		vm.expectRevert("Invalid provided category");
		vm.prank(safe);
		atr.mintAssetTransferRightsToken(
			MultiToken.Asset(MultiToken.Category.ERC20, token, 0, erc20Amount)
		);
	}

	function test_shouldFail_whenERC721asERC1155() external {
		_mockToken(MultiToken.Category.ERC721);

		vm.mockCall(
			token,
			abi.encodeWithSignature("supportsInterface(bytes4)", type(IERC1155).interfaceId),
			abi.encode(false)
		);

		vm.expectRevert("Invalid provided category");
		vm.prank(safe);
		atr.mintAssetTransferRightsToken(
			MultiToken.Asset(MultiToken.Category.ERC1155, token, 132, erc1155Amount)
		);
	}

	function test_shouldFail_whenERC1155asERC20() external {
		_mockToken(MultiToken.Category.ERC1155);

		vm.mockCall(
			token,
			abi.encodeWithSignature("supportsInterface(bytes4)", type(IERC20).interfaceId),
			abi.encode(false)
		);

		vm.expectRevert("Invalid provided category");
		vm.prank(safe);
		atr.mintAssetTransferRightsToken(
			MultiToken.Asset(MultiToken.Category.ERC20, token, 0, erc20Amount)
		);
	}

	function test_shouldFail_whenERC1155asERC721() external {
		_mockToken(MultiToken.Category.ERC1155);

		vm.mockCall(
			token,
			abi.encodeWithSignature("supportsInterface(bytes4)", type(IERC721).interfaceId),
			abi.encode(false)
		);

		vm.expectRevert("Invalid provided category");
		vm.prank(safe);
		atr.mintAssetTransferRightsToken(
			MultiToken.Asset(MultiToken.Category.ERC721, token, 132, 1)
		);
	}
	// <--- Asset category check

	// ---> Process
	function test_shouldPass_whenERC20SufficientBalance() external {
		_mockToken(MultiToken.Category.ERC20);

		vm.prank(safe);
		atr.mintAssetTransferRightsToken(
			MultiToken.Asset(MultiToken.Category.ERC20, token, 0, erc20Amount)
		);
	}

	function test_shouldPass_whenERC721SufficientBalance() external {
		_mockToken(MultiToken.Category.ERC721);

		vm.prank(safe);
		atr.mintAssetTransferRightsToken(
			MultiToken.Asset(MultiToken.Category.ERC721, token, 42, 1)
		);
	}

	function test_shouldPass_whenERC1155SufficientBalance() external {
		_mockToken(MultiToken.Category.ERC1155);

		vm.prank(safe);
		atr.mintAssetTransferRightsToken(
			MultiToken.Asset(MultiToken.Category.ERC1155, token, 42, erc1155Amount)
		);
	}

	function test_shouldIncreaseATRTokenId() external {
		_mockToken(MultiToken.Category.ERC721);
		uint256 lastAtrId = 736;
		vm.store(address(atr), LAST_TOKEN_ID_SLOT, bytes32(lastAtrId));

		vm.prank(safe);
		atr.mintAssetTransferRightsToken(
			MultiToken.Asset(MultiToken.Category.ERC721, token, 42, 1)
		);

		bytes32 atrId = vm.load(address(atr), LAST_TOKEN_ID_SLOT);
		assertEq(uint256(atrId), lastAtrId + 1);
	}

	function test_shouldStoreTokenizedAssetData() external {
		_mockToken(MultiToken.Category.ERC721);

		vm.prank(safe);
		uint256 atrId = atr.mintAssetTransferRightsToken(
			MultiToken.Asset(MultiToken.Category.ERC721, token, 42, 1)
		);

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
		assertEq(uint256(assetAmount), 1);
	}

	function test_shouldStoreTokenizedAssetOwner() external {
		uint256 lastTokenId = 736;
		vm.store(address(atr), LAST_TOKEN_ID_SLOT, bytes32(lastTokenId));
		_mockToken(MultiToken.Category.ERC721);

		vm.prank(safe);
		atr.mintAssetTransferRightsToken(
			MultiToken.Asset(MultiToken.Category.ERC721, token, 42, 1)
		);

		bytes32 valuesSlot = _assetsInSafeFirstValueSlotFor(safe);
		// Expecting one item -> first item (index 0) will be our ATR token
		bytes32 storedId = vm.load(address(atr), valuesSlot);
		assertEq(uint256(storedId), lastTokenId + 1);
	}

	function test_shouldMintATRToken() external {
		_mockToken(MultiToken.Category.ERC721);

		vm.prank(safe);
		uint256 atrId = atr.mintAssetTransferRightsToken(
			MultiToken.Asset(MultiToken.Category.ERC721, token, 42, 1)
		);

		assertEq(atr.ownerOf(atrId), safe);
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
		assets[0] = MultiToken.Asset(MultiToken.Category.ERC1155, token, 42, erc1155Amount / 2);
		assets[1] = MultiToken.Asset(MultiToken.Category.ERC1155, token, 42, erc1155Amount / 2);

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

	function setUp() override public {
		super.setUp();

		MultiToken.Asset memory asset = MultiToken.Asset(MultiToken.Category.ERC721, token, tokenId, 1);
		_tokenizeAssetUnderId(safe, atrId, asset);
		_mockToken(MultiToken.Category.ERC721);

		bytes32 atrTokenOwnerSlot = keccak256(abi.encode(atrId, ATR_TOKEN_OWNER_SLOT));
		vm.store(address(atr), atrTokenOwnerSlot, bytes32(uint256(uint160(safe))));

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
		bytes32 atrIdIndexValue = vm.load(address(atr), _assetsInSafeIndexesSlotFor(safe, atrId));
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

}


/*----------------------------------------------------------*|
|*  # MINT ASSET TRANSFER RIGHTS TOKEN BATCH                *|
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
		assets[0] = MultiToken.Asset(MultiToken.Category.ERC1155, token, 31, erc1155Amount);
		assets[1] = MultiToken.Asset(MultiToken.Category.ERC1155, token, 1, erc1155Amount);

		_mockToken(MultiToken.Category.ERC1155);
		_tokenizeAssetsUnderIds(safe, atrIds, assets);

		// Store ATR token 42 owner
		vm.store(address(atr), keccak256(abi.encode(atrIds[0], ATR_TOKEN_OWNER_SLOT)), bytes32(uint256(uint160(safe))));
		// Store ATR token 192 owner
		vm.store(address(atr), keccak256(abi.encode(atrIds[1], ATR_TOKEN_OWNER_SLOT)), bytes32(uint256(uint160(safe))));
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

	function setUp() override public {
		super.setUp();

		// Mock state where safe has 2 tokenized assets and alice holds both ATR tokens

		uint256[] memory atrIds = new uint256[](2);
		atrIds[0] = atrId;
		atrIds[1] = atrId2;

		MultiToken.Asset memory asset = MultiToken.Asset(MultiToken.Category.ERC1155, token, tokenId, erc1155Amount / 2);
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
		address otherSafe = address(0xfe);
		vm.mockCall(
			safeValidator,
			abi.encodeWithSignature("isValidSafe(address)", otherSafe),
			abi.encode(true)
		);

		vm.expectRevert("Asset is not in a target wallet");
		vm.prank(alice);
		atr.claimAssetFrom(otherSafe, atrId, true);
	}
	// <--- Basic checks

	// ---> Process
	function test_shouldStoreAssetIsNotInSafe() external {
		vm.prank(alice);
		atr.claimAssetFrom(safe, atrId, true);

		// Atr id is not stored in safe
		bytes32 atrIdIndexValue = vm.load(address(atr), _assetsInSafeIndexesSlotFor(safe, atrId));
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
	// <--- With `burnToken` flag

	// ---> Without `burnToken` flag
	function test_shouldFail_whenRecipientIsNotPWNSafe_whenWithoutBurnFlag() external {
		vm.expectRevert("Attempting to transfer asset to non PWN Wallet address");
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
		bytes32 atrIdIndexValue = vm.load(address(atr), _assetsInSafeIndexesSlotFor(alice, atrId));
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
	// <--- Without `burnToken` flag

}

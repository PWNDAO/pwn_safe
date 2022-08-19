// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.15;

import "forge-std/Test.sol";
import "openzeppelin-contracts/contracts/interfaces/IERC20.sol";
import "openzeppelin-contracts/contracts/interfaces/IERC721.sol";
import "openzeppelin-contracts/contracts/interfaces/IERC1155.sol";
import "../src/AssetTransferRights.sol";
import "./helpers/TokenizedAssetManagerStorageHelper.sol";


// The only reason for this contract is to expose internal functions of TokenizedAssetManager
// No additional logic is applied here
contract AssetTransferRightsExposed is AssetTransferRights {

	function increaseTokenizedBalance(
		uint256 atrTokenId,
		address owner,
		MultiToken.Asset memory asset
	) external {
		_increaseTokenizedBalance(atrTokenId, owner, asset);
	}

	function decreaseTokenizedBalance(
		uint256 atrTokenId,
		address owner,
		MultiToken.Asset memory asset
	) external returns (bool) {
		return _decreaseTokenizedBalance(atrTokenId, owner, asset);
	}

	function canBeTokenized(
		address owner,
		MultiToken.Asset memory asset
	) external view returns (bool) {
		return _canBeTokenized(owner, asset);
	}

	function storeTokenizedAsset(
		uint256 atrTokenId,
		MultiToken.Asset memory asset
	) external {
		_storeTokenizedAsset(atrTokenId, asset);
	}

	function clearTokenizedAsset(uint256 atrTokenId) external {
		_clearTokenizedAsset(atrTokenId);
	}

}

abstract contract TokenizedAssetManagerTest is TokenizedAssetManagerStorageHelper {

	AssetTransferRightsExposed atr;
	address wallet = address(0xff);
	address token = address(0x070ce2);

	constructor() {
		vm.etch(token, bytes("data"));
	}

	function setUp() virtual external {
		atr = new AssetTransferRightsExposed();
		setAtr(address(atr));
	}

}


/*----------------------------------------------------------*|
|*  # HAS SUFFICIENT TOKENIZED BALANCE                      *|
|*----------------------------------------------------------*/

contract TokenizedAssetManager_HasSufficientTokenizedBalance_Test is TokenizedAssetManagerTest {

	function test_shouldReturnFalse_whenInsufficientBalanceOfFungibleAsset() external {
		MultiToken.Asset memory asset = MultiToken.Asset(MultiToken.Category.ERC20, token, 0, 101e18);
		_tokenizeAssetUnderId(wallet, 42, asset);

		vm.mockCall(
			token,
			abi.encodeWithSelector(IERC20.balanceOf.selector),
			abi.encode(uint256(100e18))
		);

		bool sufficient = atr.hasSufficientTokenizedBalance(wallet);

		assertEq(sufficient, false);
	}

	function test_shouldReturnFalse_whenMissingTokenizedNonFungibleAsset() external {
		MultiToken.Asset memory asset = MultiToken.Asset(MultiToken.Category.ERC721, token, 142, 1);
		_tokenizeAssetUnderId(wallet, 42, asset);

		vm.mockCall(
			token,
			abi.encodeWithSelector(IERC721.ownerOf.selector),
			abi.encode(address(0xa11ce))
		);

		bool sufficient = atr.hasSufficientTokenizedBalance(wallet);

		assertEq(sufficient, false);
	}

	function test_shouldReturnFalse_whenInsufficientBalanceOfSemifungibleAsset() external {
		MultiToken.Asset memory asset = MultiToken.Asset(MultiToken.Category.ERC1155, token, 142, 300);
		_tokenizeAssetUnderId(wallet, 42, asset);

		vm.mockCall(
			token,
			abi.encodeWithSelector(IERC1155.balanceOf.selector),
			abi.encode(uint256(100))
		);

		bool sufficient = atr.hasSufficientTokenizedBalance(wallet);

		assertEq(sufficient, false);
	}

	function test_shouldReturnFalse_whenOneOfTokenizedBalancesIsInsufficient() external {
		uint256[] memory atrIds = new uint256[](4);
		atrIds[0] = 42;
		atrIds[1] = 44;
		atrIds[2] = 102;
		atrIds[3] = 82;

		MultiToken.Asset[] memory assets = new MultiToken.Asset[](4);
		assets[0] = MultiToken.Asset(MultiToken.Category.ERC721, address(0x1002), 100, 1);
		assets[1] = MultiToken.Asset(MultiToken.Category.ERC721, address(0x1002), 102, 1);
		assets[2] = MultiToken.Asset(MultiToken.Category.ERC1155, address(0x1003), 42, 100);
		assets[3] = MultiToken.Asset(MultiToken.Category.ERC20, address(0x1001), 0, 100e18);

		_tokenizeAssetsUnderIds(wallet, atrIds, assets);

		vm.mockCall(
			address(0x1001),
			abi.encodeWithSelector(IERC20.balanceOf.selector),
			abi.encode(uint256(99e18)) // Insufficient balance
		);

		vm.mockCall(
			address(0x1002),
			abi.encodeWithSelector(IERC721.ownerOf.selector),
			abi.encode(wallet)
		);

		vm.mockCall(
			address(0x1003),
			abi.encodeWithSelector(IERC1155.balanceOf.selector),
			abi.encode(uint256(100))
		);

		bool sufficient = atr.hasSufficientTokenizedBalance(wallet);

		assertEq(sufficient, false);
	}

	function test_shouldReturnTrue_whenAllTokenizedBalancesAreSufficient() external {
		uint256[] memory atrIds = new uint256[](4);
		atrIds[0] = 42;
		atrIds[1] = 44;
		atrIds[2] = 102;
		atrIds[3] = 82;

		MultiToken.Asset[] memory assets = new MultiToken.Asset[](4);
		assets[0] = MultiToken.Asset(MultiToken.Category.ERC721, address(0x1002), 100, 1);
		assets[1] = MultiToken.Asset(MultiToken.Category.ERC721, address(0x1002), 102, 1);
		assets[2] = MultiToken.Asset(MultiToken.Category.ERC1155, address(0x1003), 42, 100);
		assets[3] = MultiToken.Asset(MultiToken.Category.ERC20, address(0x1001), 0, 100e18);

		_tokenizeAssetsUnderIds(wallet, atrIds, assets);

		vm.mockCall(
			address(0x1001),
			abi.encodeWithSelector(IERC20.balanceOf.selector),
			abi.encode(uint256(100e18))
		);

		vm.mockCall(
			address(0x1002),
			abi.encodeWithSelector(IERC721.ownerOf.selector),
			abi.encode(wallet)
		);

		vm.mockCall(
			address(0x1003),
			abi.encodeWithSelector(IERC1155.balanceOf.selector),
			abi.encode(uint256(100))
		);

		bool sufficient = atr.hasSufficientTokenizedBalance(wallet);

		assertEq(sufficient, true);
	}

}


/*----------------------------------------------------------*|
|*  # RECOVER INVALID TOKENIZED BALANCE                     *|
|*----------------------------------------------------------*/

contract TokenizedAssetManager_RecoverInvalidTokenizedBalance_Test is TokenizedAssetManagerTest {

	// TODO: TEST AFTER IMPLEMENTATION REDESIGN

}


/*----------------------------------------------------------*|
|*  # GET ASSET                                             *|
|*----------------------------------------------------------*/

contract TokenizedAssetManager_GetAsset_Test is TokenizedAssetManagerTest {

	function test_shouldReturnStoredAsset() external {
		MultiToken.Asset memory asset = MultiToken.Asset(MultiToken.Category.ERC721, token, 142, 1);
		_tokenizeAssetUnderId(wallet, 42, asset);

		MultiToken.Asset memory returnedAsset = atr.getAsset(42);

		assertEq(uint8(returnedAsset.category), uint8(asset.category));
		assertEq(returnedAsset.assetAddress, asset.assetAddress);
		assertEq(returnedAsset.id, asset.id);
		assertEq(returnedAsset.amount, asset.amount);
	}

}


/*----------------------------------------------------------*|
|*  # TOKENIZED ASSETS IN SAFE OF                           *|
|*----------------------------------------------------------*/

contract TokenizedAssetManager_TokenizedAssetsInSafeOf_Test is TokenizedAssetManagerTest {

	function test_shouldReturnListOfTokenizedAssetsInSafeRepresentedByATRTokenIds() external {
		uint256[] memory atrIds = new uint256[](4);
		atrIds[0] = 42;
		atrIds[1] = 44;
		atrIds[2] = 102;
		atrIds[3] = 82;

		MultiToken.Asset[] memory assets = new MultiToken.Asset[](4);
		assets[0] = MultiToken.Asset(MultiToken.Category.ERC721, address(0x1002), 100, 1);
		assets[1] = MultiToken.Asset(MultiToken.Category.ERC721, address(0x1002), 102, 1);
		assets[2] = MultiToken.Asset(MultiToken.Category.ERC1155, address(0x1003), 42, 100);
		assets[3] = MultiToken.Asset(MultiToken.Category.ERC20, address(0x1001), 0, 100e18);

		_tokenizeAssetsUnderIds(wallet, atrIds, assets);

		uint256[] memory tokenizedAssets = atr.tokenizedAssetsInSafeOf(wallet);

		assertEq(atrIds[0], tokenizedAssets[0]);
		assertEq(atrIds[1], tokenizedAssets[1]);
		assertEq(atrIds[2], tokenizedAssets[2]);
		assertEq(atrIds[3], tokenizedAssets[3]);
	}

}


/*----------------------------------------------------------*|
|*  # HAS ANY TOKENIZED ASSET IN SAFE                       *|
|*----------------------------------------------------------*/

contract TokenizedAssetManager_HasAnyTokenizedAssetInSafe_Test is TokenizedAssetManagerTest {

	function test_shouldReturnTrue_whenHasAnyTokenizedAssetInSafe() external {
		MultiToken.Asset memory asset = MultiToken.Asset(MultiToken.Category.ERC721, token, 142, 1);
		_tokenizeAssetUnderId(wallet, 42, asset);

		assertEq(atr.hasAnyTokenizedAssetInSafe(wallet), true);
	}

	function test_shouldReturnFalse_whenHasNotAnyTokenizedAssetInSafe() external {
		assertEq(atr.hasAnyTokenizedAssetInSafe(wallet), false);
	}

}


/*----------------------------------------------------------*|
|*  # NUMBER OF TOKENIZED ASSETS FROM COLLECTION            *|
|*----------------------------------------------------------*/

contract TokenizedAssetManager_NumberOfTokenizedAssetsFromCollection_Test is TokenizedAssetManagerTest {

	function test_shouldReturnNumberOfTokenizedAssetsFromCollection() external {
		uint256[] memory atrIds = new uint256[](4);
		atrIds[0] = 42;
		atrIds[1] = 44;
		atrIds[2] = 102;
		atrIds[3] = 82;

		MultiToken.Asset[] memory assets = new MultiToken.Asset[](4);
		assets[0] = MultiToken.Asset(MultiToken.Category.ERC721, address(0x1002), 100, 1);
		assets[1] = MultiToken.Asset(MultiToken.Category.ERC721, address(0x1002), 102, 1);
		assets[2] = MultiToken.Asset(MultiToken.Category.ERC1155, address(0x1003), 42, 100);
		assets[3] = MultiToken.Asset(MultiToken.Category.ERC20, address(0x1001), 0, 100e18);

		_tokenizeAssetsUnderIds(wallet, atrIds, assets);

		assertEq(
			atr.numberOfTokenizedAssetsFromCollection(wallet, address(0x1001)),
			1
		);
		assertEq(
			atr.numberOfTokenizedAssetsFromCollection(wallet, address(0x1002)),
			2
		);
		assertEq(
			atr.numberOfTokenizedAssetsFromCollection(wallet, address(0x1003)),
			1
		);
	}

}


/*----------------------------------------------------------*|
|*  # INCREASE TOKENIZED BALANCE                            *|
|*----------------------------------------------------------*/

contract TokenizedAssetManager_IncreaseTokenizedBalance_Test is TokenizedAssetManagerTest {

	uint256 private atrId = 42;

	function test_shouldStoreAssetIsInSafe() external {
		MultiToken.Asset memory asset = MultiToken.Asset(MultiToken.Category.ERC1155, token, 321, 123);

		atr.increaseTokenizedBalance(atrId, wallet, asset);

		bytes32 atrIdValue = vm.load(address(atr), _assetsInSafeFirstValueSlotFor(wallet));
		assertEq(uint256(atrIdValue), atrId);
		bytes32 atrIdIndexValue = vm.load(address(atr), _assetsInSafeIndexesSlotFor(wallet, atrId));
		assertEq(uint256(atrIdIndexValue), 1);
	}

	function test_shouldNotFail_whenAssetIsAlreadyInSafe() external {
		MultiToken.Asset memory asset = MultiToken.Asset(MultiToken.Category.ERC1155, token, 321, 123);
		_tokenizeAssetUnderId(wallet, atrId, asset);

		atr.increaseTokenizedBalance(atrId, wallet, asset);

		bytes32 atrIdValue = vm.load(address(atr), _assetsInSafeFirstValueSlotFor(wallet));
		assertEq(uint256(atrIdValue), atrId);
		bytes32 atrIdIndexValue = vm.load(address(atr), _assetsInSafeIndexesSlotFor(wallet, atrId));
		assertEq(uint256(atrIdIndexValue), 1);
	}

	function test_shouldSetAssetsTokenizedBalance_whenBalanceIsZero() external {
		MultiToken.Asset memory asset = MultiToken.Asset(MultiToken.Category.ERC1155, token, 321, 123);

		atr.increaseTokenizedBalance(atrId, wallet, asset);

		bytes32 tokenizedBalanceValue = vm.load(address(atr), _tokenizedBalanceValuesSlotFor(wallet, token, 321));
		assertEq(uint256(tokenizedBalanceValue), 123);
	}

	function test_shouldIncreaseAssetsTokenizedBalance_whenBalanceIsNonZero() external {
		MultiToken.Asset memory asset = MultiToken.Asset(MultiToken.Category.ERC1155, token, 321, 123);
		_tokenizeAssetUnderId(wallet, atrId, asset);

		atr.increaseTokenizedBalance(atrId + 1, wallet, asset);

		bytes32 tokenizedBalanceValue = vm.load(address(atr), _tokenizedBalanceValuesSlotFor(wallet, token, 321));
		assertEq(uint256(tokenizedBalanceValue), 246);
	}

}


/*----------------------------------------------------------*|
|*  # DECREASE TOKENIZED BALANCE                            *|
|*----------------------------------------------------------*/

contract TokenizedAssetManager_DecreaseTokenizedBalance_Test is TokenizedAssetManagerTest {

	uint256 private atrId = 42;

	function test_shouldReturnFalse_whenAssetIsNotInSafe() external {
		MultiToken.Asset memory asset = MultiToken.Asset(MultiToken.Category.ERC1155, token, 321, 123);

		bool success = atr.decreaseTokenizedBalance(atrId, wallet, asset);

		assertEq(success, false);
	}

	function test_shouldReturnTrue_whenAssetIsInSafe() external {
		MultiToken.Asset memory asset = MultiToken.Asset(MultiToken.Category.ERC1155, token, 321, 123);
		_tokenizeAssetUnderId(wallet, atrId, asset);

		bool success = atr.decreaseTokenizedBalance(atrId, wallet, asset);

		assertEq(success, true);
	}

	function test_shouldStoreAssetIsNotInSafe() external {
		MultiToken.Asset memory asset = MultiToken.Asset(MultiToken.Category.ERC1155, token, 321, 123);
		_tokenizeAssetUnderId(wallet, atrId, asset);

		atr.decreaseTokenizedBalance(atrId, wallet, asset);

		bytes32 atrIdValue = vm.load(address(atr), _assetsInSafeFirstValueSlotFor(wallet));
		assertEq(uint256(atrIdValue), 0);
		bytes32 atrIdIndexValue = vm.load(address(atr), _assetsInSafeIndexesSlotFor(wallet, atrId));
		assertEq(uint256(atrIdIndexValue), 0);
	}

	function test_shouldDecreaseAssetsTokenizedBalance_whenBalanceIsBiggerThenAmount() external {
		uint256[] memory atrIds = new uint256[](2);
		atrIds[0] = 42;
		atrIds[1] = 43;

		MultiToken.Asset memory asset = MultiToken.Asset(MultiToken.Category.ERC1155, token, 321, 123);
		MultiToken.Asset[] memory assets = new MultiToken.Asset[](2);
		assets[0] = asset;
		assets[1] = asset;

		_tokenizeAssetsUnderIds(wallet, atrIds, assets);

		atr.decreaseTokenizedBalance(atrId + 1, wallet, asset);

		bytes32 tokenizedBalanceValue = vm.load(address(atr), _tokenizedBalanceValuesSlotFor(wallet, token, 321));
		assertEq(uint256(tokenizedBalanceValue), 123);
		bytes32 indexValue = vm.load(address(atr), _tokenizedBalanceKeyIndexesSlotFor(wallet, token, asset.id));
		assertGt(uint256(indexValue), 0);
	}

	function test_shouldRemoveAssetIdFromSet_whenTokenizedBalanceIsEqualAmount() external {
		MultiToken.Asset memory asset = MultiToken.Asset(MultiToken.Category.ERC1155, token, 321, 123);
		_tokenizeAssetUnderId(wallet, atrId, asset);

		atr.decreaseTokenizedBalance(atrId, wallet, asset);

		bytes32 tokenizedBalanceValue = vm.load(address(atr), _tokenizedBalanceValuesSlotFor(wallet, token, 321));
		assertEq(uint256(tokenizedBalanceValue), 0);
		bytes32 indexValue = vm.load(address(atr), _tokenizedBalanceKeyIndexesSlotFor(wallet, token, asset.id));
		assertEq(uint256(indexValue), 0);
	}

}


/*----------------------------------------------------------*|
|*  # CAN BE TOKENIZED                                      *|
|*----------------------------------------------------------*/

contract TokenizedAssetManager_CanBeTokenized_Test is TokenizedAssetManagerTest {

	function test_shouldReturnFalse_whenInsufficientBalance() external {
		MultiToken.Asset memory asset = MultiToken.Asset(MultiToken.Category.ERC1155, token, 321, 123);
		_tokenizeAssetUnderId(wallet, 42, asset);

		vm.mockCall(
			token,
			abi.encodeWithSelector(IERC1155.balanceOf.selector),
			abi.encode(uint256(123))
		);

		bool canBe = atr.canBeTokenized(wallet, asset);

		assertEq(canBe, false);
	}

	function test_shouldReturnTrue_whenSufficientBalance() external {
		MultiToken.Asset memory asset = MultiToken.Asset(MultiToken.Category.ERC1155, token, 321, 123);
		_tokenizeAssetUnderId(wallet, 42, asset);

		vm.mockCall(
			token,
			abi.encodeWithSelector(IERC1155.balanceOf.selector),
			abi.encode(uint256(246))
		);

		bool canBe = atr.canBeTokenized(wallet, asset);

		assertEq(canBe, true);
	}

}


/*----------------------------------------------------------*|
|*  # STORE TOKENIZED ASSET                                 *|
|*----------------------------------------------------------*/

contract TokenizedAssetManager_StoreTokenizedAsset_Test is TokenizedAssetManagerTest {

	uint256 atrId = 42;

	function test_shouldStoreAsset() external {
		MultiToken.Asset memory asset = MultiToken.Asset(MultiToken.Category.ERC1155, token, 321, 123);

		atr.storeTokenizedAsset(atrId, asset);

		uint256 assetSlot = uint256(_assetStructSlotFor(atrId));
		bytes32 addrAndCategory = vm.load(address(atr), bytes32(uint256(assetSlot) + 0));
		bytes32 assetCategory = addrAndCategory & bytes32(uint256(0xff));
		bytes32 assetAddress = addrAndCategory >> 8;
        bytes32 assetId = vm.load(address(atr), bytes32(uint256(assetSlot) + 1));
        bytes32 assetAmount = vm.load(address(atr), bytes32(uint256(assetSlot) + 2));
        assertEq(uint256(assetCategory), uint256(MultiToken.Category.ERC1155));
        assertEq(uint256(assetAddress), uint256(uint160(token)));
        assertEq(uint256(assetId), 321);
        assertEq(uint256(assetAmount), 123);
	}

}


/*----------------------------------------------------------*|
|*  # CLEAR TOKENIZED BALANCE                               *|
|*----------------------------------------------------------*/

contract TokenizedAssetManager_ClearTokenizedAsset_Test is TokenizedAssetManagerTest {

	uint256 atrId = 42;

	function test_shouldClearAsset() external {
		MultiToken.Asset memory asset = MultiToken.Asset(MultiToken.Category.ERC1155, token, 321, 123);
		_tokenizeAssetUnderId(wallet, atrId, asset);

		atr.clearTokenizedAsset(atrId);

		uint256 assetSlot = uint256(_assetStructSlotFor(atrId));
		bytes32 addrAndCategory = vm.load(address(atr), bytes32(uint256(assetSlot) + 0));
        bytes32 assetId = vm.load(address(atr), bytes32(uint256(assetSlot) + 1));
        bytes32 assetAmount = vm.load(address(atr), bytes32(uint256(assetSlot) + 2));
        assertEq(uint256(addrAndCategory), 0);
        assertEq(uint256(assetId), 0);
        assertEq(uint256(assetAmount), 0);
	}

}

// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.15;

import "forge-std/Test.sol";
import "MultiToken/MultiToken.sol";


abstract contract TokenizedAssetManagerStorageHelper is Test {

	bytes32 internal constant ASSETS_SLOT = bytes32(uint256(4)); // `assets` mapping position
	bytes32 internal constant ASSETS_IN_SAFE_SLOT = bytes32(uint256(5)); // `tokenizedAssetsInSafe` mapping position
	bytes32 internal constant TOKENIZED_BALANCES_SLOT = bytes32(uint256(6)); // `tokenizedBalances` mapping position

	address private atr;

	function setAtr(address _atr) internal {
		atr = _atr;
	}


	function _tokenizeAssetUnderId(address owner, uint256 atrId, MultiToken.Asset memory asset) internal {
		uint256[] memory atrIds = new uint256[](1);
		atrIds[0] = atrId;

		MultiToken.Asset[] memory assets = new MultiToken.Asset[](1);
		assets[0] = asset;

		_tokenizeAssetsUnderIds(owner, atrIds, assets);
	}

	function _tokenizeAssetsUnderIds(address owner, uint256[] memory atrIds, MultiToken.Asset[] memory assets) internal {
		assert(atrIds.length == assets.length);

		for (uint256 i; i < atrIds.length; ++i) {
			uint256 atrId = atrIds[i];
			MultiToken.Asset memory asset = assets[i];

			// Store asset under atr id
			uint256 assetSlot = uint256(_assetStructSlotFor(atrId));
			uint256 addrAndCategory = (uint256(uint160(asset.assetAddress)) << 8) | uint256(asset.category);
			vm.store(atr, bytes32(assetSlot + 0), bytes32(addrAndCategory));
			vm.store(atr, bytes32(assetSlot + 1), bytes32(asset.id));
			vm.store(atr, bytes32(assetSlot + 2), bytes32(asset.amount));

			// Store atr id to owner address
			// -> Set `_values` array length
			//   Unnecessary to have in loop, but it's more readable here
			vm.store(atr, _assetsInSafeSetSlotFor(owner), bytes32(atrIds.length));
			// -> Set atr id to `_values` array
			vm.store(atr, bytes32(uint256(_assetsInSafeFirstValueSlotFor(owner)) + i), bytes32(atrId));
			// -> Set atr id index in `_values` into `_indexes` mapping (value in mapping is index + 1)
			vm.store(atr, _assetsInSafeIndexeSlotFor(owner, atrId), bytes32(i + 1));

			// Store assets balance as tokenized
			bytes32 index = vm.load(atr, _tokenizedBalanceKeyIndexesSlotFor(owner, asset.assetAddress, asset.id));
			if (index == 0) {
				// -> Set `_keys._values` array length
				uint256 tokenizedAssetsFromCollection = uint256(vm.load(atr, _tokenizedBalanceMapSlotFor(owner, asset.assetAddress)));
				vm.store(atr, _tokenizedBalanceMapSlotFor(owner, asset.assetAddress), bytes32(tokenizedAssetsFromCollection + 1));
				// -> Set asset id to `_keys._values` array
				vm.store(atr, bytes32(uint256(_tokenizedBalanceFirstKeyValueSlotFor(owner, asset.assetAddress)) + tokenizedAssetsFromCollection), bytes32(asset.id));
				// -> Set asset id index in `_keys._values` into `_keys._indexes` mapping (value in mapping is index + 1)
				vm.store(atr, _tokenizedBalanceKeyIndexesSlotFor(owner, asset.assetAddress, asset.id), bytes32(tokenizedAssetsFromCollection + 1));
				// -> Set asset balance to `_values` mapping under asset id
				vm.store(atr, _tokenizedBalanceValuesSlotFor(owner, asset.assetAddress, asset.id), bytes32(asset.amount));
			} else {
				// -> `_keys._values` array length stays the same
				// -> Asset id is present in `_keys._values` array
				// -> Asset id has its index from `_keys._values` in `_keys._indexes` mapping
				// -> Increase asset balance to `_values` mapping under asset id
				uint256 tokenizedBalance = uint256(vm.load(atr, _tokenizedBalanceValuesSlotFor(owner, asset.assetAddress, asset.id)));
				vm.store(atr, _tokenizedBalanceValuesSlotFor(owner, asset.assetAddress, asset.id), bytes32(tokenizedBalance + asset.amount));
			}

		}
	}


	// assets mapping

	function _assetStructSlotFor(uint256 atrId) internal pure returns (bytes32) {
		return keccak256(
			abi.encode(
				atrId, // ATR token id as a mapping key
				ASSETS_SLOT
			)
		);
	}

	// tokenizedAssetsInSafe mapping

	function _assetsInSafeSetSlotFor(address owner) internal pure returns (bytes32) {
		return keccak256(
			abi.encode(
				owner, // Owner address as a mapping key
				ASSETS_IN_SAFE_SLOT
			)
		);
	}

	function _assetsInSafeFirstValueSlotFor(address owner) internal pure returns (bytes32) {
		// Hash array position to get position of a first item in the array
		return keccak256(
			abi.encode(
				_assetsInSafeSetSlotFor(owner) // `_values` array position
			)
		);
	}

	function _assetsInSafeIndexeSlotFor(address owner, uint256 atrId) internal pure returns (bytes32) {
		return keccak256(
			abi.encode(
				atrId, // Atr id as a mapping key
				uint256(_assetsInSafeSetSlotFor(owner)) + 1 // `_indexes` mapping position
			)
		);
	}

	// tokenizedBalances mapping

	function _tokenizedBalanceMapSlotFor(address owner, address assetAddress) internal pure returns (bytes32) {
		return keccak256(
			abi.encode(
				assetAddress, // Asset address as a mapping key
				keccak256(
					abi.encode(
						owner, // Owner address as a mapping key
						TOKENIZED_BALANCES_SLOT
					)
				)
			)
		);
	}

	function _tokenizedBalanceFirstKeyValueSlotFor(address owner, address assetAddress) internal pure returns (bytes32) {
		// Hash array position to get position of a first item in the array
		return keccak256(
			abi.encode(
				_tokenizedBalanceMapSlotFor(owner, assetAddress) // `_keys._values` array position
			)
		);
	}

	function _tokenizedBalanceKeyIndexesSlotFor(address owner, address assetAddress, uint256 assetId) internal pure returns (bytes32) {
		return keccak256(
			abi.encode(
				assetId, // Asset id as a mapping key
				uint256(_tokenizedBalanceMapSlotFor(owner, assetAddress)) + 1 // `_keys._indexes` mapping position
			)
		);
	}

	function _tokenizedBalanceValuesSlotFor(address owner, address assetAddress, uint256 assetId) internal pure returns (bytes32) {
		return keccak256(
			abi.encode(
				assetId, // Asset id as a mapping key
				uint256(_tokenizedBalanceMapSlotFor(owner, assetAddress)) + 2 // `_values` mapping position
			)
		);
	}

}

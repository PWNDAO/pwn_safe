// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.15;

import "openzeppelin-contracts/contracts/utils/structs/EnumerableMap.sol";
import "openzeppelin-contracts/contracts/utils/structs/EnumerableSet.sol";

import "MultiToken/MultiToken.sol";


/**
 * @title Tokenized Asset Manager
 * @notice Contract responsible for managing tokenized asset balances.
 */
abstract contract TokenizedAssetManager {
	using EnumerableSet for EnumerableSet.UintSet;
	using EnumerableMap for EnumerableMap.UintToUintMap;
	using MultiToken for MultiToken.Asset;


	/*----------------------------------------------------------*|
	|*  # VARIABLES & CONSTANTS DEFINITIONS                     *|
	|*----------------------------------------------------------*/

	/**
	 * @notice Mapping of ATR token id to underlying asset
	 * @dev (ATR token id => Asset)
	 */
	mapping (uint256 => MultiToken.Asset) internal assets;

	/**
	 * @notice Mapping of safe address to set of ATR ids, that belongs to tokeniezd assets in the safe.
	 * @dev The ATR token itself doesn't have to be in the safe.
	 *      (safe => set of ATR token ids representing tokenized assets currently in owners safe)
	 */
	mapping (address => EnumerableSet.UintSet) internal tokenizedAssetsInSafe;

	/**
	 * @notice Balance of tokenized assets from asset collection in a safe
	 * @dev (safe => asset address => asset id => balance of tokenized assets currently in owners safe)
	 */
	mapping (address => mapping (address => EnumerableMap.UintToUintMap)) internal tokenizedBalances;


	/*----------------------------------------------------------*|
	|*  # CONSTRUCTOR                                           *|
	|*----------------------------------------------------------*/

	constructor() {

	}


	/*----------------------------------------------------------*|
	|*  # CHECK TOKENIZED BALANCE                               *|
	|*----------------------------------------------------------*/

	/**
	 * @dev Checks that address has sufficient balance of tokenized assets.
	 *      Fails if tokenized balance is insufficient.
	 * @param owner Address to check its tokenized balance.
	 */
	function hasSufficientTokenizedBalance(address owner) external view returns (bool) {
		uint256[] memory atrs = tokenizedAssetsInSafe[owner].values();
		for (uint256 i; i < atrs.length; ++i) {
			MultiToken.Asset memory asset = assets[atrs[i]];
			(, uint256 tokenizedBalance) = tokenizedBalances[owner][asset.assetAddress].tryGet(asset.id);
			if (asset.balanceOf(owner) < tokenizedBalance)
				return false;
		}

		return true;
	}


	/*----------------------------------------------------------*|
	|*  # CONFLICT RESOLUTION                                   *|
	|*----------------------------------------------------------*/

	/**
	 * @notice Recover PWNSafes invalid tokenized balance.
	 * @dev Invalid tokenized balance could happen only when an asset with tokenized transfer rights leaves the safe non-standard way.
	 *      This function is meant to recover PWNSafe affected by Stalking attack.
	 *      Stalking attack is type of attack where attacker transfer malicious tokenized asset to victims safe
	 *      and then transfers it away through some non-standard way, leaving safe in a state, where every call of `execTransaction` function
	 *      will fail on `Insufficient tokenized balance` error.
	 * @param atrTokenId ATR token id representing underyling asset in question.
	 */
	function recoverInvalidTokenizedBalance(uint256 atrTokenId) external {

		// TODO: IS PRONE TO REENTRANCY ATTACKS -> NEED TO REDESIGN HOW TO RECOVER INVALID TOKENIZED BALANCE

		address owner = msg.sender;

		// Check if state is really invalid
		MultiToken.Asset memory asset = assets[atrTokenId];
		(, uint256 tokenizedBalance) = tokenizedBalances[owner][asset.assetAddress].tryGet(asset.id);
		require(asset.balanceOf(owner) < tokenizedBalance, "Tokenized balance is not invalid");

		// Decrease tokenized balance
		// Decrease would fail if the atr token is not associated with an owner
		require(_decreaseTokenizedBalance(atrTokenId, owner, asset), "Asset is not in callers safe");
	}


	/*----------------------------------------------------------*|
	|*  # VIEW                                                  *|
	|*----------------------------------------------------------*/

	/**
	 * @param atrTokenId ATR token id.
	 * @return Underlying asset of an ATR token.
	 */
	function getAsset(uint256 atrTokenId) external view returns (MultiToken.Asset memory) {
		return assets[atrTokenId];
	}

	/**
	 * @param owner PWNSafe address in question.
	 * @return List of tokenized assets owned by `owner` represented by their ATR tokens.
	 */
	function tokenizedAssetsInSafeOf(address owner) external view returns (uint256[] memory) {
		return tokenizedAssetsInSafe[owner].values();
	}

	/**
	 * @param owner PWNSafe address in question.
	 * @param assetAddress Address of asset collection.
	 * @return Number of tokenized assets owned by `owner` from asset collection.
	 */
	function numberOfTokenizedAssetsFromCollection(address owner, address assetAddress) external view returns (uint256) {
		return tokenizedBalances[owner][assetAddress].length();
	}


	/*----------------------------------------------------------*|
	|*  # INTERNAL                                              *|
	|*----------------------------------------------------------*/

	function _increaseTokenizedBalance(
		uint256 atrTokenId,
		address owner,
		MultiToken.Asset memory asset // Needs to be asset stored under given atrTokenId
	) internal {
		tokenizedAssetsInSafe[owner].add(atrTokenId);
		EnumerableMap.UintToUintMap storage map = tokenizedBalances[owner][asset.assetAddress];
		(, uint256 tokenizedBalance) = map.tryGet(asset.id);
		map.set(asset.id, tokenizedBalance + asset.amount);
	}

	function _decreaseTokenizedBalance(
		uint256 atrTokenId,
		address owner,
		MultiToken.Asset memory asset // Needs to be asset stored under given atrTokenId
	) internal returns (bool) {
		if (tokenizedAssetsInSafe[owner].remove(atrTokenId) == false)
			return false;

		EnumerableMap.UintToUintMap storage map = tokenizedBalances[owner][asset.assetAddress];
		(, uint256 tokenizedBalance) = map.tryGet(asset.id);

		if (tokenizedBalance == asset.amount) {
			map.remove(asset.id);
		} else {
			map.set(asset.id, tokenizedBalance - asset.amount);
		}

		return true;
	}

	function _canBeTokenized(
		address owner,
		MultiToken.Asset memory asset
	) internal view returns (bool) {
		uint256 balance = asset.balanceOf(owner);
		(, uint256 tokenizedBalance) = tokenizedBalances[owner][asset.assetAddress].tryGet(asset.id);
		return (balance - tokenizedBalance) >= asset.amount;
	}

	function _storeTokenizedAsset(
		uint256 atrTokenId,
		MultiToken.Asset memory asset
	) internal {
		assets[atrTokenId] = asset;
	}

	function _clearTokenizedAsset(uint256 atrTokenId) internal {
		assets[atrTokenId] = MultiToken.Asset(MultiToken.Category.ERC20, address(0), 0, 0);
	}

}

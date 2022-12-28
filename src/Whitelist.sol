// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.15;

import "openzeppelin-contracts/contracts/access/Ownable.sol";


/**
 * @title Whitelist contract
 * @notice Contract responsible for managing whitelist of assets which are permited to have their transfer rights tokenized.
 *         Whitelist is temporarily solution for onboarding first users and will be dropped in the future.
 */
contract Whitelist is Ownable {

    /*----------------------------------------------------------*|
    |*  # VARIABLES & CONSTANTS DEFINITIONS                     *|
    |*----------------------------------------------------------*/

    /**
     * @notice Stored flag that incidates, whether ATR token minting is permited only to whitelisted assets.
     */
    bool public useWhitelist;

    /**
     * @notice Whitelist of asset addresses, which are permited to mint their transfer rights.
     * @dev Used only if `useWhitelist` flag is set to true.
     */
    mapping (address => bool) public isWhitelisted;


    /*----------------------------------------------------------*|
    |*  # CONSTRUCTOR                                           *|
    |*----------------------------------------------------------*/

    constructor() Ownable() {

    }


    /*----------------------------------------------------------*|
    |*  # SETTERS                                               *|
    |*----------------------------------------------------------*/

    /**
     * @notice Set if ATR token minting is restricted by the whitelist.
     * @dev Set `useWhitelist` stored flag.
     * @param _useWhitelist New `useWhitelist` flag value.
     */
    function setUseWhitelist(bool _useWhitelist) external onlyOwner {
        useWhitelist = _useWhitelist;
    }

    /**
     * @notice Set if asset address is whitelisted.
     * @dev Set `isWhitelisted` mapping value.
     * @param assetAddress Address of whitelisted asset.
     * @param _isWhitelisted New `isWhitelisted` mapping value.
     */
    function setIsWhitelisted(address assetAddress, bool _isWhitelisted) public onlyOwner {
        isWhitelisted[assetAddress] = _isWhitelisted;
    }

    /**
     * @notice Set if asset addresses from a list are whitelisted.
     * @dev Set `isWhitelisted` mapping value for every address in a list.
     * @param assetAddresses List of whitelisted asset addresses.
     * @param _isWhitelisted New `isWhitelisted` mapping value for every address in a list.
     */
    function setIsWhitelistedBatch(address[] calldata assetAddresses, bool _isWhitelisted) external onlyOwner {
        uint256 length = assetAddresses.length;
        for (uint256 i; i < length;) {
            setIsWhitelisted(assetAddresses[i], _isWhitelisted);
            unchecked { ++i; }
        }
    }

}

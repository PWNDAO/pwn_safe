// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.15;

import "@openzeppelin/interfaces/IERC721.sol";

import "@pwn-safe-test/integration/BaseIntegrationTest.sol";


abstract contract WhitelistedAssetsTest is BaseIntegrationTest {

    uint256 assetId = 1;

    // Test that ATR token can be minted with valid asset category
    // Test that tokenized asset can be transferred via ATR transfer functions
    // Test that ATR token can be burned
    function _test_whitelistedAssets(address _asset) internal {
        uint256 atrId = atr.lastTokenId() + 1; // nobody but this contract can mint ATR tokens on forked chain
        IERC721 asset = IERC721(_asset);
        address assetOwner = asset.ownerOf(assetId);

        // transfer asset to safe
        vm.prank(assetOwner);
        asset.transferFrom(assetOwner, address(safe), assetId);

        assertEq(asset.ownerOf(assetId), address(safe));

        // mint ATR token with valid asset category
        _executeTx({
            _safe: safe,
            to: address(atr),
            data: abi.encodeWithSelector(
                atr.mintAssetTransferRightsToken.selector,
                MultiToken.ERC721(_asset, assetId)
            )
        });

        assertEq(atr.ownerOf(atrId), address(safe));
        assertEq(asset.ownerOf(assetId), address(safe));

        // transfer ATR token to alice
        _executeTx({
            _safe: safe, 
            to: address(atr),
            data: abi.encodeWithSelector(
                atr.transferFrom.selector,
                address(safe), alice, atrId
            )
        });

        assertEq(atr.ownerOf(atrId), alice);
        assertEq(asset.ownerOf(assetId), address(safe));

        // transfer via ATR token with valid recipient permission
        RecipientPermissionManager.RecipientPermission memory permission = RecipientPermissionManager.RecipientPermission({
            assetCategory: MultiToken.Category.ERC721,
            assetAddress: _asset,
            assetId: assetId,
            assetAmount: 0,
            ignoreAssetIdAndAmount: false,
            recipient: address(safeOther),
            agent: alice,
            expiration: 0,
            isPersistent: false,
            nonce: keccak256("nonce")
        });

        _executeTx({
            _safe: safeOther, 
            to: address(atr),
            data: abi.encodeWithSelector(
                atr.grantRecipientPermission.selector,
                permission
            )
        });

        vm.prank(alice);
        atr.transferAssetFrom(payable(safe), atrId, false, permission, "");

        assertEq(atr.ownerOf(atrId), alice);
        assertEq(asset.ownerOf(assetId), address(safeOther));

        // transfer ATR token to safe
        vm.prank(alice);
        atr.transferFrom(alice, address(safe), atrId);

        assertEq(atr.ownerOf(atrId), address(safe));
        assertEq(asset.ownerOf(assetId), address(safeOther));

        // claim from other safe
        _executeTx({
            _safe: safe, 
            to: address(atr),
            data: abi.encodeWithSelector(
                atr.claimAssetFrom.selector,
                address(safeOther), atrId, false
            )
        });

        assertEq(atr.ownerOf(atrId), address(safe));
        assertEq(asset.ownerOf(assetId), address(safe));

        // burn ATR token
        _executeTx({
            _safe: safe, 
            to: address(atr),
            data: abi.encodeWithSelector(
                atr.burnAssetTransferRightsToken.selector,
                atrId
            )
        });
    }

}


/*----------------------------------------------------------*|
|*  # ETHEREUM                                              *|
|*----------------------------------------------------------*/

interface ICryptoPunksLike {
    function punkIndexToAddress(uint256 index) external view returns (address);
    function transferPunk(address to, uint punkIndex) external;
}

interface IWrappedPunkLike {
    function registerProxy() external;
    function proxyInfo(address user) external view returns (address);
    function mint(uint256 punkIndex) external;
}

contract MainnetWhitelistedAssetsIntegrationTest is WhitelistedAssetsTest {

    function setUp() public virtual override {
        vm.createSelectFork("mainnet");
        super.setUp();
    }

    function test_Otherdeed() external { _test_whitelistedAssets(0x34d85c9CDeB23FA97cb08333b511ac86E1C4E258); }
    function test_CloneX() external { _test_whitelistedAssets(0x49cF6f5d44E70224e2E23fDcdd2C053F30aDA28B); }
    function test_BAYC() external { _test_whitelistedAssets(0xBC4CA0EdA7647A8aB7C2061c2E118A18a936f13D); }
    function test_MAYC() external { _test_whitelistedAssets(0x60E4d786628Fea6478F785A6d7e704777c86a7c6); }
    function test_Nakamigos() external { _test_whitelistedAssets(0xd774557b647330C91Bf44cfEAB205095f7E6c367); }
    function test_Meebits() external { _test_whitelistedAssets(0x7Bd29408f11D2bFC23c34f18275bBf23bB716Bc7); }
    function test_DeGods() external { _test_whitelistedAssets(0x8821BeE2ba0dF28761AffF119D66390D594CD280); }
    function test_GenuineUndead() external { _test_whitelistedAssets(0x209e639a0EC166Ac7a1A4bA41968fa967dB30221); }
    function test_Azukis() external { _test_whitelistedAssets(0xED5AF388653567Af2F388E6224dC7C4b3241C544); }
    function test_BEANZ() external { _test_whitelistedAssets(0x306b1ea3ecdf94aB739F1910bbda052Ed4A9f949); }
    function test_Doodles() external { _test_whitelistedAssets(0x8a90CAb2b38dba80c64b7734e58Ee1dB38B8992e); }
    function test_PudgyPenguins() external { _test_whitelistedAssets(0xBd3531dA5CF5857e7CfAA92426877b022e612cf8); }
    function test_WrappedCryptoPunks() external { 
        IWrappedPunkLike wrappedPunk = IWrappedPunkLike(0xb7F7F6C52F2e2fdb1963Eab30438024864c313F6);
        ICryptoPunksLike punks = ICryptoPunksLike(0xb47e3cd837dDF8e4c57F05d70Ab865de6e193BBB);
        address punkOwner = punks.punkIndexToAddress(assetId);
        // if the punk owner is not wrapped punk contract, wrap the punk
        if (punkOwner != address(wrappedPunk)) {
            address proxy = wrappedPunk.proxyInfo(punkOwner);
            if (proxy == address(0)) {
                vm.prank(punkOwner);
                wrappedPunk.registerProxy();
                proxy = wrappedPunk.proxyInfo(punkOwner);
            }
            
            vm.prank(punkOwner);
            punks.transferPunk(proxy, assetId);

            vm.prank(punkOwner);
            wrappedPunk.mint(assetId);
        }
        _test_whitelistedAssets(address(wrappedPunk)); 
    }

}


/*----------------------------------------------------------*|
|*  # POLYGON                                               *|
|*----------------------------------------------------------*/

contract PolygonWhitelistedAssetsIntegrationTest is WhitelistedAssetsTest {

    function setUp() public virtual override {
        vm.createSelectFork("polygon");
        super.setUp();
    }

    function test_y00ts() external { _test_whitelistedAssets(0x670fd103b1a08628e9557cD66B87DeD841115190); }

}


// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.15;

import "@openzeppelin/interfaces/IERC20.sol";
import "@openzeppelin/interfaces/IERC721.sol";
import "@openzeppelin/interfaces/IERC1155.sol";

import "MultiToken/MultiToken.sol";

import "@pwn-safe-test/integration/BaseIntegrationTest.sol";


abstract contract WhitelistedAssetsIntegrationTest is BaseIntegrationTest {
    using MultiToken for MultiToken.Asset;

    // 20 helpers
    function _test_whitelistedAssets20(address assetAddress, address assetOwner) internal {
        _test_whitelistedAssets20({ assetAddress: assetAddress, assetAmount: 100e18, tax: 0, assetOwner: assetOwner });
    }

    function _test_whitelistedAssets20(address assetAddress, uint256 assetAmount, uint256 tax, address assetOwner) internal {
        IERC20 asset = IERC20(assetAddress);

        // transfer asset to safe
        vm.prank(assetOwner);
        asset.transfer(address(safe), assetAmount);

        // if tax is not 0, whitelist asset owner to keep the amount untouched
        assertTrue(asset.balanceOf(address(safe)) >= assetAmount);

        _test_whitelistedAssets({ asset: MultiToken.ERC20(assetAddress, assetAmount), tax: tax });
    }

    function _decreaseByTax(uint256 amount, uint256 tax) internal pure returns (uint256) {
        return amount * (1000 - tax) / 1000;
    }

    // 721 helpers
    function _test_whitelistedAssets721(address assetAddress) internal {
        _test_whitelistedAssets721({ assetAddress: assetAddress, assetId: 1 });
    }

    function _test_whitelistedAssets721(address assetAddress, uint256 assetId) internal {
        IERC721 asset = IERC721(assetAddress);
        address assetOwner = asset.ownerOf(assetId);

        // transfer asset to safe
        vm.prank(assetOwner);
        asset.transferFrom(assetOwner, address(safe), assetId);

        assertEq(asset.ownerOf(assetId), address(safe));

        _test_whitelistedAssets(MultiToken.ERC721(assetAddress, assetId));
    }

    // 1155 helpers
    function _test_whitelistedAssets1155(address assetAddress, address assetOwner) internal {
        _test_whitelistedAssets1155({ assetAddress: assetAddress, assetId: 1, assetAmount: 1, assetOwner: assetOwner });
    }

    function _test_whitelistedAssets1155(address assetAddress, uint256 assetId, uint256 assetAmount, address assetOwner) internal {
        IERC1155 asset = IERC1155(assetAddress);

        // transfer asset to safe
        vm.prank(assetOwner);
        asset.safeTransferFrom(assetOwner, address(safe), assetId, assetAmount, "");

        assertTrue(asset.balanceOf(address(safe), assetId) >= assetAmount);

        _test_whitelistedAssets(MultiToken.ERC1155(assetAddress, assetId, assetAmount));
    }

    // General test
    function _test_whitelistedAssets(MultiToken.Asset memory asset) internal {
        _test_whitelistedAssets(asset, 0);
    }

    // Test that ATR token can be minted with valid asset category
    // Test that tokenized asset can be transferred via ATR transfer functions
    // Test that ATR token can be burned
    function _test_whitelistedAssets(MultiToken.Asset memory asset, uint256 tax) internal {
        uint256 atrId = atr.lastTokenId() + 1; // nobody but this contract can mint ATR tokens on forked chain

        // whitelist if not already whitelisted
        if (whitelist.canBeTokenized(asset.assetAddress) == false) {
            vm.prank(whitelist.owner());
            whitelist.setIsWhitelisted(asset.assetAddress, true);
        }

        // mint ATR token with valid asset category
        _executeTx({
            _safe: safe,
            to: address(atr),
            data: abi.encodeWithSelector(atr.mintAssetTransferRightsToken.selector, asset)
        });

        assertEq(atr.ownerOf(atrId), address(safe));
        assertTrue(asset.balanceOf(address(safe)) >= _decreaseByTax(asset.getTransferAmount(), tax));

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
        assertTrue(asset.balanceOf(address(safe)) >= _decreaseByTax(asset.getTransferAmount(), tax));

        // transfer via ATR token with valid recipient permission
        RecipientPermissionManager.RecipientPermission memory permission = RecipientPermissionManager.RecipientPermission({
            assetCategory: asset.category,
            assetAddress: asset.assetAddress,
            assetId: asset.id,
            assetAmount: asset.amount,
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
        atr.transferAssetFrom(payable(safe), atrId, tax > 0, permission, "");

        assertTrue(asset.balanceOf(address(safeOther)) >= _decreaseByTax(asset.getTransferAmount(), tax));

        // mint new ATR token if tax is not 0 and transfer it to safe
        if (tax > 0) {
            asset.amount = asset.balanceOf(address(safeOther));
            _executeTx({
                _safe: safeOther,
                to: address(atr),
                data: abi.encodeWithSelector(atr.mintAssetTransferRightsToken.selector, asset)
            });
            ++atrId;

            _executeTx({
                _safe: safeOther,
                to: address(atr),
                data: abi.encodeWithSelector(
                    atr.transferFrom.selector,
                    address(safeOther), address(safe), atrId
                )
            });
        }
        // else just transfer ATR token to safe
        else {
            vm.prank(alice);
            atr.transferFrom(alice, address(safe), atrId);
        }

        assertEq(atr.ownerOf(atrId), address(safe));

        // claim from other safe
        _executeTx({
            _safe: safe,
            to: address(atr),
            data: abi.encodeWithSelector(
                atr.claimAssetFrom.selector,
                address(safeOther), atrId, tax > 0
            )
        });

        // burn ATR token if tax is 0
        if (tax == 0) {
            assertEq(atr.ownerOf(atrId), address(safe));

            _executeTx({
                _safe: safe,
                to: address(atr),
                data: abi.encodeWithSelector(
                    atr.burnAssetTransferRightsToken.selector,
                    atrId
                )
            });
        }

        assertTrue(asset.balanceOf(address(safe)) >= _decreaseByTax(asset.getTransferAmount(), tax));
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

contract MainnetWhitelistedAssetsIntegrationTest is WhitelistedAssetsIntegrationTest {

    function setUp() public virtual override {
        vm.createSelectFork("mainnet");
        super.setUp();
    }

    // 20
    function test_CULT() external { _test_whitelistedAssets20({ assetAddress: 0xf0f9D895aCa5c8678f706FB8216fa22957685A13, assetAmount: 100e18, tax: 4, assetOwner: 0x2d77B594B9BBaED03221F7c63Af8C4307432daF1 }); }

    // 721
    function test_Otherdeed() external { _test_whitelistedAssets721(0x34d85c9CDeB23FA97cb08333b511ac86E1C4E258); }
    function test_CloneX() external { _test_whitelistedAssets721(0x49cF6f5d44E70224e2E23fDcdd2C053F30aDA28B); }
    function test_BAYC() external { _test_whitelistedAssets721(0xBC4CA0EdA7647A8aB7C2061c2E118A18a936f13D); }
    function test_MAYC() external { _test_whitelistedAssets721(0x60E4d786628Fea6478F785A6d7e704777c86a7c6); }
    function test_Nakamigos() external { _test_whitelistedAssets721(0xd774557b647330C91Bf44cfEAB205095f7E6c367); }
    function test_Meebits() external { _test_whitelistedAssets721(0x7Bd29408f11D2bFC23c34f18275bBf23bB716Bc7); }
    function test_GenuineUndead() external { _test_whitelistedAssets721(0x209e639a0EC166Ac7a1A4bA41968fa967dB30221); }
    function test_Azukis() external { _test_whitelistedAssets721(0xED5AF388653567Af2F388E6224dC7C4b3241C544); }
    function test_BEANZ() external { _test_whitelistedAssets721(0x306b1ea3ecdf94aB739F1910bbda052Ed4A9f949); }
    function test_Doodles() external { _test_whitelistedAssets721(0x8a90CAb2b38dba80c64b7734e58Ee1dB38B8992e); }
    function test_PudgyPenguins() external { _test_whitelistedAssets721(0xBd3531dA5CF5857e7CfAA92426877b022e612cf8); }
    function test_WrappedCryptoPunks() external {
        uint256 punkId = 1;
        IWrappedPunkLike wrappedPunk = IWrappedPunkLike(0xb7F7F6C52F2e2fdb1963Eab30438024864c313F6);
        ICryptoPunksLike punks = ICryptoPunksLike(0xb47e3cd837dDF8e4c57F05d70Ab865de6e193BBB);
        address punkOwner = punks.punkIndexToAddress(punkId);
        // if the punk owner is not wrapped punk contract, wrap the punk
        if (punkOwner != address(wrappedPunk)) {
            address proxy = wrappedPunk.proxyInfo(punkOwner);
            if (proxy == address(0)) {
                vm.prank(punkOwner);
                wrappedPunk.registerProxy();
                proxy = wrappedPunk.proxyInfo(punkOwner);
            }

            vm.prank(punkOwner);
            punks.transferPunk(proxy, punkId);

            vm.prank(punkOwner);
            wrappedPunk.mint(punkId);
        }
        _test_whitelistedAssets721(address(wrappedPunk));
    }
    function test_CryptoPhunks() external { _test_whitelistedAssets721(0xf07468eAd8cf26c752C676E43C814FEe9c8CF402); }
    function test_WassiesByWassies() external { _test_whitelistedAssets721(0x1D20A51F088492A0f1C57f047A9e30c9aB5C07Ea); }

    // 1155
    function test_PwnBundler() external { _test_whitelistedAssets1155({ assetAddress: 0x19e3293196aee99BB3080f28B9D3b4ea7F232b8d, assetId: 18, assetAmount: 1, assetOwner: 0x20d801Dbee0505F9a77CFF40f5fed6Ff0f0ee9D6 }); }

}


/*----------------------------------------------------------*|
|*  # POLYGON                                               *|
|*----------------------------------------------------------*/

contract PolygonWhitelistedAssetsIntegrationTest is WhitelistedAssetsIntegrationTest {

    function setUp() public virtual override {
        vm.createSelectFork("polygon");
        super.setUp();
    }

    // 20

    // 721
    function test_PlaNFTs() external { _test_whitelistedAssets721(0xDBdb041842407c109F65b23eA86D99c1E0D94522); }
    function test_SyncSwapEraPioneer() external { _test_whitelistedAssets721(0x829C606D2ba4CDef61df2bBaC49718bD40024f02); }
    function test_ComethSpaceship() external { _test_whitelistedAssets721({ assetAddress: 0x85BC2E8Aaad5dBc347db49Ea45D95486279eD918, assetId: 7000686 }); }
    function test_EmberSwordLand() external { _test_whitelistedAssets721(0xE7e16f2Da731265778f87cB8D7850E31b84b7b86); }
    function test_Chumbi() external { _test_whitelistedAssets721(0x5492Ef6aEebA1A3896357359eF039a8B11621b45); }

    // 1155
    function test_PolkaPets() external { _test_whitelistedAssets1155({ assetAddress: 0xf0Bd260fcf279F3138726016B8a03c7110364E04, assetId: 1, assetAmount: 1, assetOwner: 0xC34aE1A39662415a4720d4A3e7C2Be0E202568C2 }); }
    function test_ArkhanteBoosterPremiumPack() external { _test_whitelistedAssets1155({ assetAddress: 0x66d1bbf7Ad44491468465F56bf092F74ff84d6Ef, assetId: 630, assetAmount: 1, assetOwner: 0x000000000000000000000000000000000000dEaD }); }

}

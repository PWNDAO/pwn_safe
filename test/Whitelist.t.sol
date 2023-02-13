// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.15;

import "forge-std/Test.sol";

import "@pwn-safe/Whitelist.sol";


abstract contract WhitelistTest is Test {

    bytes32 constant USE_WHITELIST_SLOT = bytes32(uint256(0)); // `useWhitelist` flag position (combined with `owner`)
    bytes32 constant IS_WHITELISTED_SLOT = bytes32(uint256(1)); // `isWhitelisted` mapping position
    bytes32 constant IS_WHITELISTED_LIB_SLOT = bytes32(uint256(2)); // `isWhitelistedLib` mapping position

    Whitelist whitelist;
    address notOwner = makeAddr("notOwner");
    address asset = makeAddr("asset");

    event AssetWhitelisted(address indexed assetAddress, bool indexed isWhitelisted);

    constructor() {

    }

    function setUp() virtual public {
        whitelist = new Whitelist();
    }

}


/*----------------------------------------------------------*|
|*  # CAN BE TOKENIZED                                      *|
|*----------------------------------------------------------*/

contract Whitelist_CanBeTokenized_Test is WhitelistTest {

    function test_shouldReturnTrue_whenNotUsingWhitelist() external {
        bool canBeTokenized = whitelist.canBeTokenized(asset);

        assertTrue(canBeTokenized);
    }

    function test_shouldReturnTrue_whenUsingWhitelist_whenWhitelisted() external {
        bytes32 assetSlot = keccak256(abi.encode(asset, IS_WHITELISTED_SLOT));
        vm.store(address(whitelist), assetSlot, bytes32(uint256(1)));
        // can leave owner address as zero
        bytes32 zeroSlotValue = bytes32(uint256(1)) << 160;
        vm.store(address(whitelist), USE_WHITELIST_SLOT, zeroSlotValue);

        bool canBeTokenized = whitelist.canBeTokenized(asset);

        assertTrue(canBeTokenized);
    }

    function test_shouldReturnFalse_whenUsingWhitelist_whenNotWhitelisted() external {
        // can leave owner address as zero
        bytes32 zeroSlotValue = bytes32(uint256(1)) << 160;
        vm.store(address(whitelist), USE_WHITELIST_SLOT, zeroSlotValue);

        bool canBeTokenized = whitelist.canBeTokenized(asset);

        assertFalse(canBeTokenized);
    }

}


/*----------------------------------------------------------*|
|*  # SET USE WHITELIST                                     *|
|*----------------------------------------------------------*/

contract Whitelist_SetUseWhitelist_Test is WhitelistTest {

    function test_shouldFail_whenCallerIsNotOwner() external {
        vm.expectRevert("Ownable: caller is not the owner");
        vm.prank(notOwner);
        whitelist.setUseWhitelist(true);
    }

    function test_shouldSetIfWhitelistIsUsed() external {
        // don't need to set useWhitelist value as it is by default 0
        bytes32 zeroSlotValue = bytes32(bytes20(address(this))) >> 96;
        vm.store(address(whitelist), USE_WHITELIST_SLOT, zeroSlotValue);

        whitelist.setUseWhitelist(true);

        // value is combined with owner address -> value is at 161th bit from right
        assertEq(
            uint256(vm.load(address(whitelist), USE_WHITELIST_SLOT) >> 160) & 1,
            1
        );
    }

}


/*----------------------------------------------------------*|
|*  # SET IS WHITELISTED                                    *|
|*----------------------------------------------------------*/

contract Whitelist_SetIsWhitelisted_Test is WhitelistTest {

    function test_shouldFail_whenCallerIsNotOwner() external {
        vm.expectRevert("Ownable: caller is not the owner");
        vm.prank(notOwner);
        whitelist.setIsWhitelisted(asset, true);
    }

    function test_shouldSetIfAddressIsWhitelisted() external {
        bytes32 whitelistAssetSlot = keccak256(abi.encode(asset, IS_WHITELISTED_SLOT));
        vm.store(address(whitelist), whitelistAssetSlot, bytes32(uint256(0)));

        whitelist.setIsWhitelisted(asset, true);

        assertEq(
            uint256(vm.load(address(whitelist), whitelistAssetSlot)),
            1
        );
    }

    function test_shouldEmit_AssetWhitelisted() external {
        vm.expectEmit(true, true, true, true);
        emit AssetWhitelisted(asset, true);

        whitelist.setIsWhitelisted(asset, true);
    }

}


/*----------------------------------------------------------*|
|*  # SET IS WHITELISTED BATCH                              *|
|*----------------------------------------------------------*/

contract Whitelist_SetIsWhitelistedBatch_Test is WhitelistTest {

    address[] assetAddresses;

    function setUp() override public {
        super.setUp();

        assetAddresses = new address[](3);
        assetAddresses[0] = address(0x01);
        assetAddresses[1] = address(0x02);
        assetAddresses[2] = address(0x03);
    }


    function test_shouldFail_whenCallerIsNotOwner() external {
        vm.expectRevert("Ownable: caller is not the owner");
        vm.prank(notOwner);
        whitelist.setIsWhitelistedBatch(assetAddresses, true);
    }

    function test_shouldSetIfAddressListIsWhitelisted() external {
        bytes32 assetSlot1 = keccak256(abi.encode(assetAddresses[0], IS_WHITELISTED_SLOT));
        vm.store(address(whitelist), assetSlot1, bytes32(uint256(0)));
        bytes32 assetSlot2 = keccak256(abi.encode(assetAddresses[1], IS_WHITELISTED_SLOT));
        vm.store(address(whitelist), assetSlot2, bytes32(uint256(0)));
        bytes32 assetSlot3 = keccak256(abi.encode(assetAddresses[2], IS_WHITELISTED_SLOT));
        vm.store(address(whitelist), assetSlot3, bytes32(uint256(0)));

        whitelist.setIsWhitelistedBatch(assetAddresses, true);

        assertEq(uint256(vm.load(address(whitelist), assetSlot1)), 1);
        assertEq(uint256(vm.load(address(whitelist), assetSlot2)), 1);
        assertEq(uint256(vm.load(address(whitelist), assetSlot3)), 1);
    }

    function test_shouldEmit_AssetWhitelisted() external {
        for (uint256 i; i < assetAddresses.length; ++i) {
            vm.expectEmit(true, true, true, true);
            emit AssetWhitelisted(assetAddresses[i], true);
        }

        whitelist.setIsWhitelistedBatch(assetAddresses, true);
    }

}


/*----------------------------------------------------------*|
|*  # SET IS WHITELISTED LIB                                *|
|*----------------------------------------------------------*/

contract Whitelist_SetIsWhitelistedLib_Test is WhitelistTest {

    function test_shouldFail_whenCallerIsNotOwner() external {
        vm.expectRevert("Ownable: caller is not the owner");
        vm.prank(notOwner);
        whitelist.setIsWhitelistedLib(asset, true);
    }

    function test_shouldSetIfAddressIsWhitelisted() external {
        bytes32 whitelistLibSlot = keccak256(abi.encode(asset, IS_WHITELISTED_LIB_SLOT));
        vm.store(address(whitelist), whitelistLibSlot, bytes32(uint256(0)));

        whitelist.setIsWhitelistedLib(asset, true);

        assertEq(
            uint256(vm.load(address(whitelist), whitelistLibSlot)),
            1
        );
    }

}

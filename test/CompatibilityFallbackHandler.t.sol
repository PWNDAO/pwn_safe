// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.15;

import "forge-std/Test.sol";

import "@pwn-safe/handler/CompatibilityFallbackHandler.sol";


// Testing only added functionality
abstract contract CompatibilityFallbackHandlerTest is Test {

    address whitelist = makeAddr("whitelist");
    address safe = makeAddr("safe");
    bytes data = abi.encode("some data");
    CompatibilityFallbackHandler handler;

    function setUp() external {
        handler = new CompatibilityFallbackHandler(whitelist);

        vm.mockCall(
            safe,
            abi.encodeWithSignature("domainSeparator()"),
            abi.encode(keccak256("domain separator"))
        );
    }

}


/*----------------------------------------------------------*|
|*  # IS VALID SIGNATURE                                    *|
|*----------------------------------------------------------*/

contract CompatibilityFallbackHandler_IsValidSignature_Test is CompatibilityFallbackHandlerTest {

    function test_shouldReturnZero_whenWhitelistNotUsed() external {
        vm.mockCall(
            whitelist,
            abi.encodeWithSignature("useWhitelist()"),
            abi.encode(false)
        );

        vm.prank(safe);
        bytes4 response = handler.isValidSignature(data, "");

        assertEq(response, bytes4(0));
    }

    function test_shouldFail_whenNotApproved_whenWhitelistUsed() external {
        vm.mockCall(
            whitelist,
            abi.encodeWithSignature("useWhitelist()"),
            abi.encode(true)
        );
        vm.mockCall(
            safe,
            abi.encodeWithSignature("signedMessages(bytes32)"),
            abi.encode(uint256(0))
        );

        vm.expectRevert("Hash not approved");
        vm.prank(safe);
        handler.isValidSignature(data, "");
    }

    function test_shouldReturnMagicValue_whenApproved_whenWhietlistUsed() external {
        vm.mockCall(
            whitelist,
            abi.encodeWithSignature("useWhitelist()"),
            abi.encode(true)
        );
        vm.mockCall(
            safe,
            abi.encodeWithSignature("signedMessages(bytes32)"),
            abi.encode(uint256(1))
        );

        vm.prank(safe);
        bytes4 response = handler.isValidSignature(data, "");

        assertEq(response, bytes4(0x20c13b0b));
    }

}

// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity 0.8.15;

import "@openzeppelin/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/token/ERC777/IERC777Recipient.sol";
import "@openzeppelin/token/ERC1155/IERC1155Receiver.sol";
import "@openzeppelin/utils/introspection/IERC165.sol";

/**
 * This file is copy of https://github.com/safe-global/safe-contracts/blob/c36bcab46578a442862d043e12a83fec41143dec/contracts/handler/DefaultCallbackHandler.sol
 * Changes:
 * - change imports to openzeppelin to don't have `DeclarationError: Identifier already declared.` with IERC165 interface
 * - remove unnecessary IERC165 as it is included in IERC1155Receiver interface
 */

/// @title Default Callback Handler - returns true for known token callbacks
/// @author Richard Meissner - <richard@gnosis.pm>
contract DefaultCallbackHandler is IERC1155Receiver, IERC777Recipient, IERC721Receiver {
    string public constant NAME = "Default Callback Handler";
    string public constant VERSION = "1.0.0";

    function onERC1155Received(
        address,
        address,
        uint256,
        uint256,
        bytes calldata
    ) external pure override returns (bytes4) {
        return 0xf23a6e61;
    }

    function onERC1155BatchReceived(
        address,
        address,
        uint256[] calldata,
        uint256[] calldata,
        bytes calldata
    ) external pure override returns (bytes4) {
        return 0xbc197c81;
    }

    function onERC721Received(
        address,
        address,
        uint256,
        bytes calldata
    ) external pure override returns (bytes4) {
        return 0x150b7a02;
    }

    function tokensReceived(
        address,
        address,
        address,
        uint256,
        bytes calldata,
        bytes calldata
    ) external pure override {
        // We implement this for completeness, doesn't really have any value
    }

    function supportsInterface(bytes4 interfaceId) external view virtual override returns (bool) {
        return
            interfaceId == type(IERC1155Receiver).interfaceId ||
            interfaceId == type(IERC721Receiver).interfaceId ||
            interfaceId == type(IERC165).interfaceId;
    }
}

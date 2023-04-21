// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

import "@openzeppelin/token/ERC20/IERC20.sol";
import "@openzeppelin/token/ERC20/ERC20.sol";
import "@openzeppelin/utils/introspection/ERC165.sol";


contract T20 is ERC165, ERC20("ERC20", "ERC20") {

    bool private _supportingERC165 = true;

    function foo() payable external {

    }

    function mint(address owner, uint256 amount) external {
        _mint(owner, amount);
    }

    function burn(address owner, uint256 amount) external {
        _burn(owner, amount);
    }


    function supportERC165(bool support) external {
        _supportingERC165 = support;
    }

    function supportsInterface(bytes4 interfaceId) public override view returns (bool) {
        return _supportingERC165 && (super.supportsInterface(interfaceId) || interfaceId == type(IERC20).interfaceId);
    }

}

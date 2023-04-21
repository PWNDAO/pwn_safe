// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;


contract DelegatecallContract {

    function perform(address target, bytes calldata data) external {
        (bool success, ) = target.delegatecall(data);
        require(success);
    }

}

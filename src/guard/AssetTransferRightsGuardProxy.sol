// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.15;

import "@openzeppelin/proxy/transparent/TransparentUpgradeableProxy.sol";


contract AssetTransferRightsGuardProxy is TransparentUpgradeableProxy {

	constructor(
        address logic,
        address admin
    ) TransparentUpgradeableProxy(logic, admin, "") {

    }

}

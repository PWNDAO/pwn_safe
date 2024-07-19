// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.15;

import "@pwn-safe-test/integration/BaseIntegrationTest.sol";


contract DeployedProtocolIntegrationTest is BaseIntegrationTest {

    bytes32 internal constant _ADMIN_SLOT = 0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103;

    function _test_deployedProtocol(string memory urlOrAlias) internal {
        vm.createSelectFork(urlOrAlias);
        super.setUp();

        // guard proxy admin is admin address
        bytes32 guardAdminValue = vm.load(address(guard), _ADMIN_SLOT);
        address guardAdmin = abi.decode(abi.encode(guardAdminValue), (address));
        assertEq(guardAdmin, admin);

        // whitelist owner is admin address
        assertEq(whitelist.owner(), admin);

        // atr owner is admin address
        assertEq(atr.owner(), admin);

        // atr is initialized
        bytes32 atrInitializedSlotValue = vm.load(address(atr), bytes32(0));
        bytes32 atrInitialized = atrInitializedSlotValue << 88 >> 248; // offset 20, size 1 (bytes)
        assertEq(uint256(atrInitialized), 1);

        // atr guard is initialized
        bytes32 guardInitializedSlotValue = vm.load(address(guard), bytes32(uint256(1)));
        bytes32 guardInitialized = guardInitializedSlotValue << 248 >> 248; // offset 0, size 1 (bytes)
        assertEq(uint256(guardInitialized), 1);
    }


    function test_deployedProtocol_ethereum() external { _test_deployedProtocol("ethereum"); }
    function test_deployedProtocol_polygon() external { _test_deployedProtocol("polygon"); }
    function test_deployedProtocol_arbitrum() external { _test_deployedProtocol("arbitrum"); }
    function test_deployedProtocol_optimism() external { _test_deployedProtocol("optimism"); }
    function test_deployedProtocol_base() external { _test_deployedProtocol("base"); }
    // Need to deploy ERC1820 registry on Cronos first
    // function test_deployedProtocol_cronos() external { _test_deployedProtocol("cronos"); }
    function test_deployedProtocol_mantle() external { _test_deployedProtocol("mantle"); }
    function test_deployedProtocol_bsc() external { _test_deployedProtocol("bsc"); }
    function test_deployedProtocol_linea() external { _test_deployedProtocol("linea"); }

    function test_deployedProtocol_sepolia() external { _test_deployedProtocol("sepolia"); }
    function test_deployedProtocol_goerli() external { _test_deployedProtocol("goerli"); }
    function test_deployedProtocol_mumbai() external { _test_deployedProtocol("mumbai"); }

}

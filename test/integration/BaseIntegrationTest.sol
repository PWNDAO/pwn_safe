// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.15;

import "forge-std/Test.sol";

import "@openzeppelin/utils/Strings.sol";

import "@safe/libraries/SignMessageLib.sol";
import "@safe/proxies/GnosisSafeProxyFactory.sol";
import "@safe/proxies/GnosisSafeProxy.sol";
import "@safe/GnosisSafe.sol";

import "@pwn-safe/factory/PWNSafeFactory.sol";
import "@pwn-safe/guard/AssetTransferRightsGuard.sol";
import "@pwn-safe/guard/AssetTransferRightsGuardProxy.sol";
import "@pwn-safe/handler/CompatibilityFallbackHandler.sol";
import "@pwn-safe/module/AssetTransferRights.sol";
import "@pwn-safe/module/RecipientPermissionManager.sol";


abstract contract BaseIntegrationTest is Test {
    using stdJson for string;
    using Strings for uint256;

    uint256[] deployedChains;
    Deployment deployment;

    // Properties need to be in alphabetical order
    struct Deployment {
        address admin;
        AssetTransferRights atr;
        AssetTransferRightsGuard atrGuard;
        AssetTransferRightsGuardProxy atrGuardProxy;
        PWNSafeFactory factory;
        CompatibilityFallbackHandler fallbackHandler;
        Whitelist whitelist;
    }

    address constant erc1820Registry = address(0x1820a4B7618BdE71Dce8cdc73aAB6C95905faD24);

    address immutable alice = makeAddr("alice");
    address immutable bob = makeAddr("bob");
    address immutable owner = makeAddr("owner");
    address immutable ownerOther = makeAddr("ownerOther");

    address admin;
    Whitelist whitelist;
    CompatibilityFallbackHandler fallbackHandler;
    AssetTransferRights atr;
    AssetTransferRightsGuard guard;
    PWNSafeFactory factory;
    GnosisSafe gnosisSafeSingleton;
    GnosisSafeProxyFactory gnosisSafeFactory;
    SignMessageLib signMessageLib;

    GnosisSafe safe;
    GnosisSafe safeOther;


    function setUp() public virtual {
        string memory root = vm.projectRoot();
        string memory path = string.concat(root, "/deployments.json");
        string memory json = vm.readFile(path);
        bytes memory rawDeployedChains = json.parseRaw(".deployedChains");
        deployedChains = abi.decode(rawDeployedChains, (uint256[]));

        if (_contains(deployedChains, block.chainid)) {
            bytes memory rawDeployment = json.parseRaw(string.concat(".chains.", block.chainid.toString()));
            deployment = abi.decode(rawDeployment, (Deployment));

            admin = deployment.admin;
            whitelist = deployment.whitelist;
            fallbackHandler = deployment.fallbackHandler;
            atr = deployment.atr;
            guard = AssetTransferRightsGuard(address(deployment.atrGuardProxy));
            factory = deployment.factory;
            gnosisSafeSingleton = GnosisSafe(payable(0x3E5c63644E683549055b9Be8653de26E0B4CD36E));
            gnosisSafeFactory = GnosisSafeProxyFactory(0xa6B71E26C5e0845f74c812102Ca7114b6a896AB2);
            signMessageLib = SignMessageLib(0xA65387F16B013cf2Af4605Ad8aA5ec25a2cbA3a2);
        } else if (block.chainid == 31337) {
            // Mock ERC1820 Registry
            vm.etch(erc1820Registry, bytes("data"));
            vm.mockCall(
                erc1820Registry,
                abi.encodeWithSignature("getInterfaceImplementer(address,bytes32)"),
                abi.encode(address(0))
            );

            _deployProtocol();
        } else {
            revert("Not deployed on selected chain yet");
        }

        address[] memory owners = new address[](1);

        owners[0] = owner;
        safe = factory.deployProxy(owners, 1);

        owners[0] = ownerOther;
        safeOther = factory.deployProxy(owners, 1);
    }

    function _contains(uint256[] storage array, uint256 value) private view returns (bool) {
        for (uint256 i; i < array.length; ++i)
            if (array[i] == value)
                return true;

        return false;
    }

    function _deployProtocol() private {
        admin = makeAddr("admin");

        // Deploy Gnosis Safe contracts
        gnosisSafeSingleton = new GnosisSafe();
        gnosisSafeFactory = new GnosisSafeProxyFactory();
        signMessageLib = new SignMessageLib();

        // Deploy whitelist
        vm.prank(admin);
        whitelist = new Whitelist();

        // Deploy fallback handler
        fallbackHandler = new CompatibilityFallbackHandler(address(whitelist));

        // Deploy ATR contract
        vm.prank(admin);
        atr = new AssetTransferRights(address(whitelist));

        // Deploy ATR guard logic
        AssetTransferRightsGuard guardLogic = new AssetTransferRightsGuard();

        // Deploye ATR Guard proxy with ATR Guard logic
        AssetTransferRightsGuardProxy guardProxy = new AssetTransferRightsGuardProxy(
            address(guardLogic), admin
        );

        // Initialized ATR Guard proxy as ATR Guard
        guard = AssetTransferRightsGuard(address(guardProxy));
        guard.initialize(address(atr), address(whitelist));

        // Deploy PWNSafe factory
        factory = new PWNSafeFactory(
            address(gnosisSafeSingleton),
            address(gnosisSafeFactory),
            address(fallbackHandler),
            address(atr),
            address(guardProxy)
        );

        // Initialize ATR contract
        atr.initialize(address(factory), address(guardProxy));
    }

    function _executeTx(
        GnosisSafe _safe,
        address to,
        bytes memory data
    ) public payable returns (bool) {
        return _executeTx(
            _safe, to, 0, data, Enum.Operation.Call, 0, 0, 0, address(0), payable(0)
        );
    }

    function _executeTx(
        GnosisSafe _safe,
        address to,
        uint256 value,
        bytes memory data,
        Enum.Operation operation,
        uint256 safeTxGas,
        uint256 baseGas,
        uint256 gasPrice,
        address gasToken,
        address payable refundReceiver
    ) public payable returns (bool) {
        address _owner;
        {
            // To prevent unnecessary duplication in passet arguments and vm.prank cheatcode
            if (_safe == safe)
                _owner = owner;
            else if (_safe == safeOther)
                _owner = ownerOther;
        }

        uint256 ownerValue;
        {
            ownerValue = uint256(uint160(_owner));
        }

        vm.prank(_owner);
        return _safe.execTransaction(
            to,
            value,
            data,
            operation,
            safeTxGas,
            baseGas,
            gasPrice,
            gasToken,
            refundReceiver,
            abi.encodePacked(ownerValue, bytes32(0), uint8(1))
        );
    }

}

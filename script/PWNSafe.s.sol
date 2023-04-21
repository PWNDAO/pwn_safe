// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.15;

import "forge-std/Script.sol";

import "@pwn-safe/factory/PWNSafeFactory.sol";
import "@pwn-safe/guard/AssetTransferRightsGuard.sol";
import "@pwn-safe/guard/AssetTransferRightsGuardProxy.sol";
import "@pwn-safe/guard/OperatorsContext.sol";
import "@pwn-safe/handler/CompatibilityFallbackHandler.sol";
import "@pwn-safe/module/AssetTransferRights.sol";
import "@pwn-safe/Whitelist.sol";


/**
 * Deployment flow:
 * - deploy PWN Safe contracts
 * - initialize ATR and ATRGuardProxy
 * - set ATR token metadata
 * - enable + setup whitelist
 */

interface IPWNDeployer {
    function deploy(bytes32 salt, bytes memory bytecode) external returns (address);
    function deployAndTransferOwnership(bytes32 salt, address owner, bytes memory bytecode) external returns (address);
    function computeAddress(bytes32 salt, bytes32 bytecodeHash) external view returns (address);
}


library PWNDeployerSalt {
    // keccak256("PWNWhitelist")
    bytes32 constant internal WHITELIST = 0x9554be9b74c87af2a15fb97821bec220557e1d545d127c8314dcf714cb818e97;
    // keccak256("CompatibilityFallbackHandler")
    bytes32 constant internal FALLBACK_HANDLER = 0x2a1258da7107e49f4fecda996c0ad8f3aa01796b02adcabe58f0133a3130325b;
    // keccak256("AssetTransferRights")
    bytes32 constant internal ATR = 0xaa568c36dc4fb2872811520d34e84fca8452f32de983a83b7f380f9df81eb41b;
    // keccak256("AssetTransferRightsGuardV1")
    bytes32 constant internal ATR_GUARD = 0xe9973b402a111da03bb82aba35627ea0769ec9d1da32fd504c765419785dbdb4;
    // keccak256("AssetTransferRightsGuard_Proxy")
    bytes32 constant internal ATR_GUARD_PROXY = 0x47cfb255a76bd9c54c23bcf7a00fa03ac03092d570fa7faef7daccff7918e4c0;
    // keccak256("PWNSafeFactory")
    bytes32 constant internal FACTORY = 0xcd9875cb34727d880ef096d52822fbb7391e68d943f4c327b443d78eaedc75b5;
}

abstract contract PWNSafeScript is Script {
    address constant internal PWN_DEPLOYER = 0x706c9F2dd328E2C01483eCF705D2D9708F4aB727;
    address constant internal GNOSIS_SAFE_SINGLETON = 0x3E5c63644E683549055b9Be8653de26E0B4CD36E;
    address constant internal GNOSIS_SAFE_FACTORY = 0xa6B71E26C5e0845f74c812102Ca7114b6a896AB2;
    address constant internal ADMIN = 0x61a77B19b7F4dB82222625D7a969698894d77473;
}


/*
Deploy PWNSafe contracts via EOA by executing commands:

source .env

forge script script/PWNSafe.s.sol:Deploy \
--sig "deploy(address)" $ADMIN \
--rpc-url $RPC_URL \
--private-key $PRIVATE_KEY \
--with-gas-price $(cast --to-wei 10 gwei) \
--verify --etherscan-api-key $ETHERSCAN_API_KEY \
--broadcast

forge verify-contract \
--chain-id X \
--constructor-args $(cast abi-encode "constructor()") \
0x0 PWN.... $ETHERSCAN_API_KEY
*/
contract Deploy is PWNSafeScript {

    function deploy(address admin) external {
        vm.startBroadcast();

        IPWNDeployer deployer = IPWNDeployer(PWN_DEPLOYER);

        // 1. Deploy Whitelist
        address whitelist = deployer.deployAndTransferOwnership({
            salt: PWNDeployerSalt.WHITELIST,
            owner: admin,
            bytecode: type(Whitelist).creationCode
        });
        console2.log("Whitelist address:", whitelist);

        // 2. Deploy Fallback handler
        address handler = deployer.deploy({
            salt: PWNDeployerSalt.FALLBACK_HANDLER,
            bytecode: abi.encodePacked(
                type(CompatibilityFallbackHandler).creationCode,
                abi.encode(whitelist)
            )
        });
        console2.log("CompatibilityFallbackHandler address:", handler);

        // 3. Deploy ATR contract
        address atr = deployer.deployAndTransferOwnership({
            salt: PWNDeployerSalt.ATR,
            owner: admin,
            bytecode: abi.encodePacked(
                type(AssetTransferRights).creationCode,
                abi.encode(whitelist)
            )
        });
        console2.log("AssetTransferRights address:", atr);

        // 4. Deploy ATR guard logic
        address guardLogic = deployer.deploy({
            salt: PWNDeployerSalt.ATR_GUARD,
            bytecode: type(AssetTransferRightsGuard).creationCode
        });
        console2.log("AssetTransferRightsGuard address:", guardLogic);

        // 5. Deploye ATR Guard proxy with ATR Guard logic
        address guardProxy = deployer.deploy({
            salt: PWNDeployerSalt.ATR_GUARD_PROXY,
            bytecode: abi.encodePacked(
                type(AssetTransferRightsGuardProxy).creationCode,
                abi.encode(guardLogic, admin)
            )
        });
        console2.log("AssetTransferRightsGuardProxy address:", guardProxy);

        // 6. Initialized ATR Guard proxy as ATR Guard
        AssetTransferRightsGuard(guardProxy).initialize(atr, whitelist);
        console2.log("ATR guard initialized");

        // 7. Deploy PWNSafe factory
        address factory = deployer.deploy({
            salt: PWNDeployerSalt.FACTORY,
            bytecode: abi.encodePacked(
                type(PWNSafeFactory).creationCode,
                abi.encode(
                    GNOSIS_SAFE_SINGLETON, GNOSIS_SAFE_FACTORY, handler, atr, guardProxy
                )
            )
        });
        console2.log("PWNSafeFactory address:", factory);

        // 8. Initialize ATR contract
        AssetTransferRights(atr).initialize(factory, guardProxy);
        console2.log("ATR module initialized");

        vm.stopBroadcast();
    }

}


//Use this functions if deploying via Gnosis Safe. Get deployment bytecode and pass it into tx builder.
contract DeployBytecode is PWNSafeScript {

    string SELECTED_FORK = "goerli";

    function _deployBytecode(bytes32 salt, bytes memory bytecode) private returns (address, bytes memory) {
        vm.createSelectFork(SELECTED_FORK);

        bytes memory deployBytecode = abi.encodeWithSelector(
            IPWNDeployer.deploy.selector, salt, bytecode
        );

        address addr = IPWNDeployer(PWN_DEPLOYER).computeAddress(salt, keccak256(bytecode));

        return (addr, deployBytecode);
    }

    function _deployAndTransferOwnershipBytecode(bytes32 salt, address owner, bytes memory bytecode) private returns (address, bytes memory) {
        vm.createSelectFork(SELECTED_FORK);

        bytes memory deployBytecode = abi.encodeWithSelector(
            IPWNDeployer.deployAndTransferOwnership.selector, salt, owner, bytecode
        );

        address addr = IPWNDeployer(PWN_DEPLOYER).computeAddress(salt, keccak256(bytecode));

        return (addr, deployBytecode);
    }


    // forge script script/PWNSafe.s.sol:DeployBytecode --sig "whitelist()"
    function whitelist() public returns (address, bytes memory) {
        bytes memory bytecode = type(Whitelist).creationCode;
        return _deployAndTransferOwnershipBytecode(PWNDeployerSalt.WHITELIST, ADMIN, bytecode);
    }

    // forge script script/PWNSafe.s.sol:DeployBytecode --sig "fallbackHandler()"
    function fallbackHandler() public returns (address, bytes memory) {
        (address _whitelist, ) = whitelist();

        bytes memory bytecode = abi.encodePacked(
            type(CompatibilityFallbackHandler).creationCode,
            abi.encode(_whitelist)
        );
        return _deployBytecode(PWNDeployerSalt.FALLBACK_HANDLER, bytecode);
    }

    // forge script script/PWNSafe.s.sol:DeployBytecode --sig "atr()"
    function atr() public returns (address, bytes memory) {
        (address _whitelist, ) = whitelist();

        bytes memory bytecode = abi.encodePacked(
            type(AssetTransferRights).creationCode,
            abi.encode(_whitelist)
        );
        return _deployAndTransferOwnershipBytecode(PWNDeployerSalt.ATR, ADMIN, bytecode);
    }

    // forge script script/PWNSafe.s.sol:DeployBytecode --sig "atrGuard()"
    function atrGuard() public returns (address, bytes memory) {
        bytes memory bytecode = type(AssetTransferRightsGuard).creationCode;
        return _deployBytecode(PWNDeployerSalt.ATR_GUARD, bytecode);
    }

    // forge script script/PWNSafe.s.sol:DeployBytecode --sig "atrGuardProxy()"
    function atrGuardProxy() public returns (address, bytes memory) {
        (address guardLogic, ) = atrGuard();

        bytes memory bytecode = abi.encodePacked(
            type(AssetTransferRightsGuardProxy).creationCode,
            abi.encode(guardLogic, ADMIN)
        );
        return _deployBytecode(PWNDeployerSalt.ATR_GUARD_PROXY, bytecode);
    }

    // Initialize guard proxy with atr + whitelist (cannot be done by ADMIN)

    // forge script script/PWNSafe.s.sol:DeployBytecode --sig "factory()"
    function factory() public returns (address, bytes memory) {
        (address handler, ) = fallbackHandler();
        (address _atr, ) = atr();
        (address guardProxy, ) = atrGuardProxy();

        bytes memory bytecode = abi.encodePacked(
            type(PWNSafeFactory).creationCode,
            abi.encode(GNOSIS_SAFE_SINGLETON, GNOSIS_SAFE_FACTORY, handler, _atr, guardProxy)
        );
        return _deployBytecode(PWNDeployerSalt.FACTORY, bytecode);
    }

    // Initialize ATR with factory + guard proxy

}


/*
Set ATR token metadata URI by executing commands:

source .env

forge script script/PWNSafe.s.sol:Metadata \
--sig "set(address,string)" $ATR $METADATA_URI \
--rpc-url $RPC_URL \
--private-key $DEPLOY_PRIVATE_KEY \
--with-gas-price $(cast --to-wei 10 gwei) \
--broadcast
*/
contract Metadata is Script {

    function set(
        address atr,
        string memory metadataUri
    ) external {
        vm.startBroadcast();

        // Script have to be called by ATR contract owner
        AssetTransferRights(atr).setMetadataUri(metadataUri);

        vm.stopBroadcast();
    }

}

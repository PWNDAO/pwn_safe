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
    // Optimism, Base, Cronos, Mantle, Sepolia
    // address constant internal PWN_DEPLOYER_OWNER = 0x1B4B37738De3bb9E6a7a4f99aFe4C145734c071d;
    // address constant internal PWN_DEPLOYER = 0x706c9F2dd328E2C01483eCF705D2D9708F4aB727;
    // address constant internal GNOSIS_SAFE_SINGLETON = 0xfb1bffC9d739B8D520DaF37dF666da4C687191EA;
    // address constant internal GNOSIS_SAFE_FACTORY = 0xC22834581EbC8527d974F8a1c97E1bEA4EF910BC;
    // address constant internal ADMIN = 0xa7106a1C2498EaeF4AC1B594a6544c841623B327;

    // Arbitrum
    address constant internal PWN_DEPLOYER_OWNER = 0x42Cad20c964067f8e8b5c3E13fd0aa3C20a964C4;
    address constant internal PWN_DEPLOYER = 0x706c9F2dd328E2C01483eCF705D2D9708F4aB727;
    address constant internal GNOSIS_SAFE_SINGLETON = 0x3E5c63644E683549055b9Be8653de26E0B4CD36E;
    address constant internal GNOSIS_SAFE_FACTORY = 0xa6B71E26C5e0845f74c812102Ca7114b6a896AB2;
    address constant internal ADMIN = 0x61a77B19b7F4dB82222625D7a969698894d77473;
}

interface GnosisSafeLike {
    function execTransaction(
        address to,
        uint256 value,
        bytes calldata data,
        uint8 operation,
        uint256 safeTxGas,
        uint256 baseGas,
        uint256 gasPrice,
        address gasToken,
        address payable refundReceiver,
        bytes memory signatures
    ) external payable returns (bool success);
}

library GnosisSafeUtils {

    function execTransaction(GnosisSafeLike safe, address to, bytes memory data) internal returns (bool) {
        uint256 ownerValue = uint256(uint160(msg.sender));
        return GnosisSafeLike(safe).execTransaction({
            to: to,
            value: 0,
            data: data,
            operation: 0,
            safeTxGas: 0,
            baseGas: 0,
            gasPrice: 0,
            gasToken: address(0),
            refundReceiver: payable(0),
            signatures: abi.encodePacked(ownerValue, bytes32(0), uint8(1))
        });
    }

}


contract Deploy is PWNSafeScript {
    using GnosisSafeUtils for GnosisSafeLike;

    function _deployAndTransferOwnership(bytes32 salt, address owner, bytes memory bytecode) internal returns (address) {
        bool success = GnosisSafeLike(PWN_DEPLOYER_OWNER).execTransaction({
            to: PWN_DEPLOYER,
            data: abi.encodeWithSelector(
                IPWNDeployer.deployAndTransferOwnership.selector, salt, owner, bytecode
            )
        });
        require(success, "Deploy failed");
        return IPWNDeployer(PWN_DEPLOYER).computeAddress(salt, keccak256(bytecode));
    }

    function _deploy(bytes32 salt, bytes memory bytecode) internal returns (address) {
        bool success = GnosisSafeLike(PWN_DEPLOYER_OWNER).execTransaction({
            to: PWN_DEPLOYER,
            data: abi.encodeWithSelector(
                IPWNDeployer.deploy.selector, salt, bytecode
            )
        });
        require(success, "Deploy failed");
        return IPWNDeployer(PWN_DEPLOYER).computeAddress(salt, keccak256(bytecode));
    }


/*
forge script script/PWNSafe.s.sol:Deploy \
--rpc-url $RPC_URL \
--private-key $PRIVATE_KEY \
--with-gas-price $(cast --to-wei 15 gwei) \
--verify --etherscan-api-key $ETHERSCAN_API_KEY \
--broadcast

forge verify-contract --watch --chain-id X \
--constructor-args $(cast abi-encode "constructor()") \
0x0 PWN.... -e $ETHERSCAN_API_KEY
*/
    function run() external {
        vm.startBroadcast();

        // 1. Deploy Whitelist
        address whitelist = _deployAndTransferOwnership({
            salt: PWNDeployerSalt.WHITELIST,
            owner: ADMIN,
            bytecode: type(Whitelist).creationCode
        });
        console2.log("Whitelist address:", whitelist);

        // 2. Deploy Fallback handler
        address handler = _deploy({
            salt: PWNDeployerSalt.FALLBACK_HANDLER,
            bytecode: abi.encodePacked(
                type(CompatibilityFallbackHandler).creationCode,
                abi.encode(whitelist)
            )
        });
        console2.log("CompatibilityFallbackHandler address:", handler);

        // 3. Deploy ATR contract
        address atr = _deployAndTransferOwnership({
            salt: PWNDeployerSalt.ATR,
            owner: ADMIN,
            bytecode: abi.encodePacked(
                type(AssetTransferRights).creationCode,
                abi.encode(whitelist)
            )
        });
        console2.log("AssetTransferRights address:", atr);

        // 4. Deploy ATR guard logic
        address guardLogic = _deploy({
            salt: PWNDeployerSalt.ATR_GUARD,
            bytecode: type(AssetTransferRightsGuard).creationCode
        });
        console2.log("AssetTransferRightsGuard address:", guardLogic);

        // 5. Deploye ATR Guard proxy with ATR Guard logic
        address guardProxy = _deploy({
            salt: PWNDeployerSalt.ATR_GUARD_PROXY,
            bytecode: abi.encodePacked(
                type(AssetTransferRightsGuardProxy).creationCode,
                abi.encode(guardLogic, ADMIN)
            )
        });
        console2.log("AssetTransferRightsGuardProxy address:", guardProxy);

        // 6. Initialized ATR Guard proxy as ATR Guard
        AssetTransferRightsGuard(guardProxy).initialize(atr, whitelist);
        console2.log("ATR guard initialized");

        // 7. Deploy PWNSafe factory
        address factory = _deploy({
            salt: PWNDeployerSalt.FACTORY,
            bytecode: abi.encodePacked(
                type(PWNSafeFactory).creationCode,
                abi.encode(GNOSIS_SAFE_SINGLETON, GNOSIS_SAFE_FACTORY, handler, atr, guardProxy)
            )
        });
        console2.log("PWNSafeFactory address:", factory);

        // 8. Initialize ATR contract
        AssetTransferRights(atr).initialize(factory, guardProxy);
        console2.log("ATR module initialized");

        vm.stopBroadcast();
    }

}


contract Setup is PWNSafeScript {
    using GnosisSafeUtils for GnosisSafeLike;

/*
forge script script/PWNSafe.s.sol:Setup \
--rpc-url $RPC_URL \
--private-key $PRIVATE_KEY \
--with-gas-price $(cast --to-wei 15 gwei) \
--broadcast
*/
    function run() external {
        vm.startBroadcast();

        // CONFIG ---------------------
        address atr = address(0);
        address whitelist = address(0);
        address sigMessageLib = address(0);
        string memory metadata = "TBD";
        // ----------------------------

        // 1. Setup ATR token metadata
        bool success = GnosisSafeLike(ADMIN).execTransaction({
            to: atr,
            data: abi.encodeWithSelector(AssetTransferRights.setMetadataUri.selector, metadata)
        });
        require(success, "Metadata set failed");
        console2.log("ATR metadata set to:", metadata);

        // 2. Enable whitelist
        GnosisSafeLike(ADMIN).execTransaction({
            to: whitelist,
            data: abi.encodeWithSelector(Whitelist.setUseWhitelist.selector, true)
        });
        require(success, "Whitelist enable failed");
        console2.log("Whitelist enabled");

        // 3. Whitelist SignMessageLib
        GnosisSafeLike(ADMIN).execTransaction({
            to: whitelist,
            data: abi.encodeWithSelector(Whitelist.setIsWhitelistedLib.selector, sigMessageLib, true)
        });
        require(success, "SignMessageLib whitelist failed");
        console2.log("SignMessageLib whitelisted");

        vm.stopBroadcast();
    }

}
